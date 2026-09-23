import 'dart:async';

import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/alarm/alarm_trigger_path.dart';
import 'package:critalarm/core/alarm/live_activity_token_registry.dart';
import 'package:critalarm/core/alarm/quiet_hours_store.dart';
import 'package:critalarm/core/api/api_client.dart';
import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/net/launch_retry.dart';
import 'package:critalarm/core/net/launch_call_log.dart';
import 'package:critalarm/core/push/incident_push.dart';
import 'package:flutter/foundation.dart';

/// Decides when an incident rings and when its card comes down.
///
/// The lock-screen half of this lives in Swift, because Stop can be tapped
/// with no Flutter engine running. This is the in-app half and the policy the
/// tests exercise. Keep [mayStartActivity] in step with
/// `IncidentActivityCoordinator.mayStartActivity` in
/// `ios/Shared/Alarm/IncidentActivityCoordinator.swift`.
final class IncidentAlarmController {
  IncidentAlarmController({
    required this.host,
    required this.api,
    this.tokens,
    this.quietHours,
    this.applyIncident,
    AlarmTriggerPath? path,
    DateTime Function()? now,
    this.wait = defaultLaunchWait,
    this.callLog,
  }) : path = path ?? AlarmTriggerPath.chosen,
       _now = now ?? DateTime.now;

  final AlarmHost host;
  final ApiClient api;
  final LiveActivityTokenRegistry? tokens;
  final Future<void> Function(Duration) wait;
  final LaunchCallLog? callLog;

  /// The quiet hours window, or null where nothing has one to offer, which is
  /// every test that does not care about it.
  final QuietHoursStore? quietHours;

  /// Hands a fetched incident to the shared list, so a state change this phone
  /// missed while it was off still reaches the store. Null in tests that only
  /// care about the card.
  final void Function(Incident incident)? applyIncident;

  final DateTime Function() _now;

  /// Which side schedules the alarm. Read from the spike; see
  /// `docs/specs/remote-alarm-ios-spike.md`.
  final AlarmTriggerPath path;

  /// Incidents with an alarm set or ringing right now.
  final Set<String> _alarming = <String>{};

  Set<String> get alarmingIncidentIds => Set.unmodifiable(_alarming);

  StreamSubscription<String>? _nativeAlarms;

  bool _launchCallsPending = false;

  /// True when the last reconcile failed even after `retryOnLaunch` gave up.
  /// Read on resume so a healthy app does not reconcile on every foreground.
  bool get launchCallsPending => _launchCallsPending;

  /// Listens for alarms the native side scheduled on its own, which is every
  /// alarm on the background-push path. Without this the in-app rule that
  /// blocks a second card would not know an alarm is up.
  Future<void> start() async {
    await _nativeAlarms?.cancel();
    _nativeAlarms = host.alarmsScheduled.listen(_alarming.add);
  }

  Future<void> stop() async {
    await _nativeAlarms?.cancel();
    _nativeAlarms = null;
  }

  /// AlarmKit puts up its own Live Activity while it rings. A second card for
  /// the same incident would be a duplicate on the lock screen, so ours waits
  /// until the alarm is gone. That is on Stop, which is when the acknowledge
  /// surface is what the user needs.
  bool mayStartActivity({
    required String incidentId,
    Set<String> showingIncidentIds = const {},
  }) =>
      !_alarming.contains(incidentId) &&
      !showingIncidentIds.contains(incidentId);

  /// A push arrived. Rings for an open incident, and rings again on every
  /// repeat so the alarm comes back after the system auto-mutes it.
  ///
  /// Does nothing when the extension owns scheduling: on that path the alarm
  /// is already set before Dart hears about the push at all.
  Future<bool> onPush(IncidentPush push, {String topic = ''}) async {
    final incidentId = push.incidentId;
    if (incidentId == null) return false;
    if (!_ringingKinds.contains(push.kind)) return false;

    // Quiet hours holds the ring and nothing else: the incident still opens,
    // the card still shows and the list still updates, because the only thing
    // this stands in front of is the schedule call. The incident is not put on
    // the ringing list either, since nothing is ringing and our card is then
    // the acknowledge surface.
    //
    // This is not the gate that holds a ring on a phone today. On the chosen
    // path the alarm is scheduled in `AppDelegate`
    // (`didReceiveRemoteNotification`), and the live check is the one there.
    // Nothing in `lib/` calls this method yet; it covers the in-app path for
    // whenever that is wired up. All three checks read the same window and
    // apply the same rule, so wiring one up changes nothing about the answer.
    final window = quietHours?.read();
    if (window != null &&
        window.holdsRing(now: _now(), priority: push.priority)) {
      _log('alarm_skipped reason=quiet_hours id=$incidentId');
      return false;
    }

    if (path == AlarmTriggerPath.notificationServiceExtension) {
      _log('alarm_skipped reason=extension_owns_scheduling id=$incidentId');
      _alarming.add(incidentId);
      return false;
    }

    final scheduled = await host.scheduleAlarm(
      incidentId: incidentId,
      topic: topic,
      server: push.server.toString(),
      title: push.title ?? 'Crit Alarm',
    );
    if (scheduled) _alarming.add(incidentId);
    return scheduled;
  }

  static const Set<IncidentPushKind> _ringingKinds = {
    IncidentPushKind.open,
    IncidentPushKind.repeat,
    IncidentPushKind.reopen,
  };

  /// The incident is done. Stops anything still set to ring and takes the card
  /// down.
  Future<void> onIncidentFinished(
    String incidentId, {
    IncidentState state = IncidentState.closed,
  }) async {
    _alarming.remove(incidentId);
    // The incident is over, so no card replaces the one being taken down.
    await host.cancelAlarm(incidentId, handOverToStatusCard: false);
    await host.endActivity(incidentId, state: _activityState(state));
    await tokens?.forget(incidentId);
    _log('alarm_cancelled id=$incidentId state=${state.name}');
  }

  /// Stop was tapped, so the alarm is over but the incident is not. The card
  /// takes over as the acknowledge surface; Swift starts it, this just stops
  /// treating the incident as ringing.
  void onAlarmStopped(String incidentId) => _alarming.remove(incidentId);

  /// How many cards one launch checks.
  ///
  /// Each one is a separate `GET /v1/incidents/{id}`, awaited in turn, on the
  /// path that runs before the first frame. Twenty of them is a couple of
  /// seconds on a bad connection; the list used to be unbounded, and a device
  /// holding hundreds of ids spent a minute and a half of radio time on every
  /// cold start. Whatever is left over is checked on the next launch, and the
  /// ones handled here drop off the list for good.
  static const int reconcileLimit = 20;

  /// On launch, the server is the truth. Any card still up for an incident the
  /// server has finished with comes down, and any alarm still set for one
  /// stops.
  ///
  /// Retried as one whole run on a network error or a 5xx (`retryOnLaunch`),
  /// so a dead server costs six tries total, not six per card. Never throws:
  /// a run that still fails after every retry leaves the cards up and sets
  /// [launchCallsPending] so resume tries again.
  Future<void> reconcile() async {
    try {
      await retryOnLaunch(
        'incident_reconcile',
        _reconcileOnce,
        wait: wait,
        log: _log,
        callLog: callLog,
      );
      _launchCallsPending = false;
    } on Object catch (_) {
      // The server is unreachable, or every retry used up. Leave the cards up:
      // a stale card is better than a missed incident.
      _launchCallsPending = true;
    }
  }

  /// Resume calls this. Runs [reconcile] again, but only when the last run
  /// ended in failure.
  Future<void> retryIfPending() async {
    if (!_launchCallsPending) return;
    await reconcile();
  }

  Future<void> _reconcileOnce() async {
    final showing = await host.showingIncidentIds();
    for (final incidentId in showing.take(reconcileLimit)) {
      final Incident incident;
      try {
        incident = await api.getIncident(incidentId);
      } on ApiException catch (error) {
        // 404 and 410 are answers, not failures. The incident is gone from the
        // server, which relays do after a retention window, so the card comes
        // down and the id leaves the list. Left as an error it came back every
        // launch and cost a server call every time.
        if (error.statusCode == 404 || error.statusCode == 410) {
          await onIncidentFinished(incidentId, state: IncidentState.expired);
          continue;
        }
        // Any other status is a launch hiccup or a real failure; let
        // retryOnLaunch decide from the status code.
        rethrow;
      }
      if (incident.isOpen || incident.isAcked) continue;
      applyIncident?.call(incident);
      await onIncidentFinished(incidentId, state: incident.incidentState);
    }
  }

  static String _activityState(IncidentState state) => switch (state) {
    IncidentState.open => 'open',
    IncidentState.acked => 'acked',
    IncidentState.closed => 'closed',
    IncidentState.expired => 'expired',
  };

  void _log(String message) => debugPrint('CritAlarmAlarm: $message');
}
