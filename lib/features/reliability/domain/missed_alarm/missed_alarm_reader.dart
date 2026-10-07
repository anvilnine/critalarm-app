import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_rule.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_store.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/phone_record.dart';
import 'package:flutter/foundation.dart';

/// One alarm this phone missed.
@immutable
final class MissedAlarm {
  const MissedAlarm({
    required this.incidentId,
    required this.topic,
    required this.at,
    required this.reason,
  });

  final String incidentId;
  final String topic;

  /// When the incident ran out.
  final DateTime at;
  final MissedReason reason;

  @override
  bool operator ==(Object other) =>
      other is MissedAlarm &&
      other.incidentId == incidentId &&
      other.topic == topic &&
      other.at == at &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(incidentId, topic, at, reason);

  @override
  String toString() => 'MissedAlarm($incidentId, $topic, ${reason.name})';
}

/// How long a missed alarm is worth telling the user about.
const missedAlarmWindow = Duration(days: 7);

/// The missed alarms among [missed] that ran out no more than
/// [missedAlarmWindow] before [now] and were not closed, newest first.
///
/// A time after [now] (a clock that was set back) cannot be placed in the
/// window, so it is left out.
List<MissedAlarm> missedAlarmsToShow({
  required Iterable<MissedAlarm> missed,
  required Set<String> dismissedIds,
  required DateTime now,
}) {
  final shown = [
    for (final alarm in missed)
      if (!dismissedIds.contains(alarm.incidentId) &&
          !alarm.at.isAfter(now) &&
          now.difference(alarm.at) <= missedAlarmWindow)
        alarm,
  ]..sort((a, b) => b.at.compareTo(a.at));
  return shown;
}

/// Works out which alarms this phone missed, from what the app already
/// holds: the shared incident list, the topic list and the phone's own
/// record. It asks the server for nothing.
///
/// It only reads. It sets off no alarm, posts no notification and changes
/// nothing about how an alarm rings or is acknowledged.
class MissedAlarmReader {
  MissedAlarmReader({
    required this.store,
    required this.readIncidents,
    required this.readCriticalTopics,
    required this.capture,
    required this.isSetupDone,
    required this.readServer,
    required this.firstLaunchAt,
    required this.setupIncidentIds,
    required this.everyPushIsLogged,
    this.ringsCanBeHeld = _never,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final MissedAlarmStore store;

  /// The incidents the app already holds. Never a fetch.
  final List<Incident> Function() readIncidents;

  /// The names of the critical topics, or null when the list cannot be read.
  final Future<Set<String>?> Function() readCriticalTopics;

  /// One look at what the phone holds right now.
  final Future<PhoneCapture> Function() capture;

  /// `SetupGate.isDone` in the app.
  final Future<bool> Function() isSetupDone;

  /// The server the phone is connected to, or null with none.
  final Future<String?> Function() readServer;

  /// When this install first ran, or null when that is not known.
  final DateTime? Function() firstLaunchAt;

  /// The incidents setup rang on purpose.
  final Set<String> Function() setupIncidentIds;

  /// Whether this phone writes a row for every push that reaches it.
  final bool everyPushIsLogged;

  /// Whether a setting on this phone can hold a priority 5 ring right now.
  final bool Function() ringsCanBeHeld;

  final DateTime Function() _now;

  static bool _never() => false;

  /// Copies what the phone holds into the record, and stamps the first time
  /// setup is seen done and the first time this server is seen connected.
  ///
  /// Never throws: nothing waits for it on launch, and the next call tries
  /// again. Calls take turns, so two of them cannot write over each other.
  Future<void> record() {
    final result = _turn.then((_) => _recordOnce());
    _turn = result;
    return result;
  }

  Future<void> _turn = Future<void>.value();

  Future<void> _recordOnce() async {
    final now = _now();
    try {
      final taken = await capture();
      await store.writeRecord(store.readRecord().merged(taken, now: now));
    } on Object catch (error) {
      debugPrint('MissedAlarmReader: capture failed: $error');
    }
    // The stamps do not wait on the capture: a phone that cannot be read
    // still gets its cut-offs.
    try {
      if (store.readSetupDoneAt() == null && await isSetupDone()) {
        await store.writeSetupDoneAt(now);
      }
      final server = await readServer();
      if (server != null &&
          server.isNotEmpty &&
          store.readConnected()?.server != server) {
        await store.writeConnected(ConnectedServer(server: server, since: now));
      }
    } on Object catch (error) {
      debugPrint('MissedAlarmReader: stamp failed: $error');
    }
  }

  /// Every alarm this phone missed among the incidents the app holds, closed
  /// entries included. Callers pick what to show with [missedAlarmsToShow].
  Future<List<MissedAlarm>> read() async {
    await record();
    final critical = await readCriticalTopics();
    final server = await readServer();
    final connected = store.readConnected();
    final cutoffs = MissedAlarmCutoffs(
      firstLaunchAt: firstLaunchAt(),
      setupDoneAt: store.readSetupDoneAt(),
      // A stamp for another server says nothing about this one.
      connectedSince: connected != null && connected.server == server
          ? connected.since
          : null,
    );
    final phone = store.readRecord();
    final tests = setupIncidentIds();
    final held = ringsCanBeHeld();

    final missed = <MissedAlarm>[];
    for (final incident in readIncidents()) {
      // The cheap test first: most incidents were acknowledged.
      if (!incident.isExpired) continue;
      final at = incident.closedAt ?? incident.updatedAt;
      if (at == null) continue;
      final verdict = missedVerdictFor(
        incident: incident,
        topicIsCritical: critical?.contains(incident.topic),
        knowledge: phone.knowledgeFor(
          incident,
          everyPushIsLogged: everyPushIsLogged,
          ringsCanBeHeld: held,
        ),
        cutoffs: cutoffs,
        isSetupTest: tests.contains(incident.id),
      );
      final reason = verdict.reason;
      if (reason == null) continue;
      missed.add(
        MissedAlarm(
          incidentId: incident.id,
          topic: incident.topic,
          at: at,
          reason: reason,
        ),
      );
    }
    return missed;
  }

  /// The missed alarms to show now: inside the window and not closed.
  Future<List<MissedAlarm>> readToShow() async => missedAlarmsToShow(
    missed: await read(),
    dismissedIds: store.readDismissed().keys.toSet(),
    now: _now(),
  );

  /// How long a closed entry is remembered. Far past the window, so an
  /// entry cannot come back while its incident could still be shown.
  static const rememberDismissedFor = Duration(days: 30);

  /// Closes the Home entry for [incidentIds] for good.
  Future<void> dismiss(Iterable<String> incidentIds) async {
    final now = _now();
    final dismissed = {
      for (final entry in store.readDismissed().entries)
        if (now.difference(entry.value) <= rememberDismissedFor)
          entry.key: entry.value,
      for (final id in incidentIds) id: now,
    };
    await store.writeDismissed(dismissed);
  }
}
