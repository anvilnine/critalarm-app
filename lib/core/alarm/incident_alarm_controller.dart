import 'dart:async';

import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/alarm/alarm_trigger_path.dart';
import 'package:critalarm/core/alarm/live_activity_token_registry.dart';
import 'package:critalarm/core/api/api_client.dart';
import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/models/incident.dart';
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
    AlarmTriggerPath? path,
  }) : path = path ?? AlarmTriggerPath.chosen;

  final AlarmHost host;
  final ApiClient api;
  final LiveActivityTokenRegistry? tokens;

  /// Which side schedules the alarm. Read from the spike; see
  /// `docs/specs/remote-alarm-ios-spike.md`.
  final AlarmTriggerPath path;

  /// Incidents with an alarm set or ringing right now.
  final Set<String> _alarming = <String>{};

  Set<String> get alarmingIncidentIds => Set.unmodifiable(_alarming);

  StreamSubscription<String>? _nativeAlarms;

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
  Future<void> reconcile() async {
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
        }
        continue;
      } on Object catch (_) {
        // The server is unreachable. Leave the card up: a stale card is better
        // than a missed incident.
        continue;
      }
      if (incident.isOpen || incident.isAcked) continue;
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
