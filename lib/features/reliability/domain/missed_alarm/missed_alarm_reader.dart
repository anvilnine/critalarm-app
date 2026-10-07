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
/// holds: the shared incident list and the phone's own record. It asks the
/// server for nothing.
///
/// It only reads. It sets off no alarm, posts no notification and changes
/// nothing about how an alarm rings or is acknowledged.
///
/// An incident counts only when it opened after four moments this phone
/// stamped itself: setup finished, this server connected, this topic first
/// held, and the install first ran. Each is stamped where it happens
/// ([setupCompleted], [connectionSaved], [topicsSeen]). An install that
/// has no stamp yet gets one the first time this runs, so the stretch
/// before it is left unclassified. A false "missed" and a false "fine" are
/// both worse than saying nothing.
class MissedAlarmReader {
  MissedAlarmReader({
    required this.store,
    required this.readIncidents,
    required this.readTopicNames,
    required this.capture,
    required this.isSetupDone,
    required this.readServer,
    required this.firstLaunchAt,
    required this.setupIncidentIds,
    required this.everyPushIsLogged,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final MissedAlarmStore store;

  /// The incidents the app already holds. Never a fetch.
  final List<Incident> Function() readIncidents;

  /// The names of the topics this phone holds, or null when the list cannot
  /// be read.
  final Future<Set<String>?> Function() readTopicNames;

  /// One look at what the phone holds right now.
  final Future<PhoneCapture> Function() capture;

  /// Whether setup was finished on this phone.
  final Future<bool> Function() isSetupDone;

  /// The server the phone is connected to, or null with none.
  final Future<String?> Function() readServer;

  /// When this install first ran, or null when that is not known.
  final DateTime? Function() firstLaunchAt;

  /// The incidents setup rang on purpose.
  final Set<String> Function() setupIncidentIds;

  /// Whether this phone writes a row for every push that reaches it.
  final bool everyPushIsLogged;

  final DateTime Function() _now;

  /// Every write goes through here, one at a time. The capture reloads the
  /// preferences from disk, and a write still in the air at that moment
  /// would be read back as it was before.
  Future<void> _turn = Future<void>.value();

  Future<void> _queued(Future<void> Function() action) {
    final result = _turn.then((_) async {
      try {
        await action();
      } on Object catch (error) {
        debugPrint('MissedAlarmReader: write failed: $error');
      }
    });
    _turn = result;
    return result;
  }

  /// Setup was finished just now. Call it where setup completes. Stamped
  /// once.
  Future<void> setupCompleted() => _queued(() async {
    if (store.readSetupDoneAt() == null) {
      await store.writeSetupDoneAt(_now());
    }
  });

  /// A connection to [server] was saved just now. Call it where a
  /// connection is saved. The same server again changes nothing. Another
  /// server drops what belonged to the old one.
  Future<void> connectionSaved(String server) =>
      _queued(() => _connectedTo(server.trim(), _now()));

  /// The saved connection was removed just now.
  Future<void> connectionCleared() => _queued(() => _connectedTo('', _now()));

  /// The phone holds exactly [names] right now. Call it when the topic list
  /// loads or changes. A new name starts a stretch, and a name that is gone
  /// ends its stretch. The ended stretch is kept, so a miss inside it stays
  /// a miss after the topic is deleted, and a topic held again later starts
  /// a new one.
  Future<void> topicsSeen(Iterable<String> names) =>
      _queued(() => _topicsHeld(names.toSet(), _now()));

  Future<void> _connectedTo(String server, DateTime now) async {
    final held = store.readConnected()?.server;
    if (held == server) return;
    // Leaving a server: its record, its closed entries and its topic stamps
    // say nothing about the next one.
    if (held != null && held.isNotEmpty) await store.clearServerData();
    await store.writeConnected(ConnectedServer(server: server, since: now));
  }

  /// How long an ended stretch is kept: as long as the phone's record.
  static const Duration keepEndedHoldsFor = PhoneRecord.keepFor;

  Future<void> _topicsHeld(Set<String> names, DateTime now) async {
    final held = store.readTopicHolds();
    final next = <String, List<TopicHold>>{};
    var changed = false;
    for (final name in {...held.keys, ...names}) {
      final holds = [
        for (final hold in held[name] ?? const <TopicHold>[])
          // An ended stretch older than anything still shown is dropped.
          if (hold.until == null ||
              now.difference(hold.until!) <= keepEndedHoldsFor)
            hold,
      ];
      if (holds.length != (held[name]?.length ?? 0)) changed = true;
      final open = holds.isNotEmpty && holds.last.until == null;
      if (names.contains(name) && !open) {
        holds.add(TopicHold(since: now));
        changed = true;
      } else if (!names.contains(name) && open) {
        holds[holds.length - 1] = TopicHold(
          since: holds.last.since,
          until: now,
        );
        changed = true;
      }
      if (holds.isNotEmpty) next[name] = holds;
    }
    if (changed) await store.writeTopicHolds(next);
  }

  /// Copies what the phone holds into the record. For an install that has
  /// no stamp yet (one set up before this existed), it also writes the
  /// stamps, as of now.
  ///
  /// Never throws: nothing waits for it on launch, and the next call tries
  /// again.
  Future<void> record() => _queued(_recordOnce);

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
      await _connectedTo((await readServer() ?? '').trim(), now);
      final names = await readTopicNames();
      if (names != null) await _topicsHeld(names, now);
    } on Object catch (error) {
      debugPrint('MissedAlarmReader: stamp failed: $error');
    }
  }

  /// Every alarm this phone missed among the incidents the app holds, closed
  /// entries included. Callers pick what to show with [missedAlarmsToShow].
  Future<List<MissedAlarm>> read() async {
    await record();
    final server = (await readServer() ?? '').trim();
    final connected = store.readConnected();
    final setupDoneAt = store.readSetupDoneAt();
    // A stamp for another server says nothing about this one.
    final connectedSince =
        connected != null && server.isNotEmpty && connected.server == server
        ? connected.since
        : null;
    final holds = store.readTopicHolds();
    final firstLaunch = firstLaunchAt();
    final phone = store.readRecord();
    final tests = setupIncidentIds();

    final missed = <MissedAlarm>[];
    for (final incident in readIncidents()) {
      // The cheap test first: most incidents were acknowledged.
      if (!incident.isExpired) continue;
      final at = incident.closedAt ?? incident.updatedAt;
      if (at == null) continue;
      final verdict = missedVerdictFor(
        incident: incident,
        knowledge: phone.knowledgeFor(
          incident,
          everyPushIsLogged: everyPushIsLogged,
        ),
        cutoffs: MissedAlarmCutoffs(
          firstLaunchAt: firstLaunch,
          setupDoneAt: setupDoneAt,
          connectedSince: connectedSince,
          topicHeldSince: _heldSinceFor(incident, holds),
        ),
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

  /// The start of the stretch this phone held the incident's topic in when
  /// it opened, or null when it did not hold it then.
  static DateTime? _heldSinceFor(
    Incident incident,
    Map<String, List<TopicHold>> holds,
  ) {
    final openedAt = incident.openedAt;
    if (openedAt == null) return null;
    for (final hold in holds[incident.topic] ?? const <TopicHold>[]) {
      if (hold.covers(openedAt)) return hold.since;
    }
    return null;
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
  Future<void> dismiss(Iterable<String> incidentIds) => _queued(() async {
    final now = _now();
    await store.writeDismissed({
      for (final entry in store.readDismissed().entries)
        if (now.difference(entry.value) <= rememberDismissedFor)
          entry.key: entry.value,
      for (final id in incidentIds) id: now,
    });
  });
}
