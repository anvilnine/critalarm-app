import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_rule.dart';
import 'package:flutter/foundation.dart';

/// One push the phone wrote down that names no incident: a `push_received`
/// or a `push_dropped` row from the native push handlers.
@immutable
final class PushLogRow {
  const PushLogRow({
    required this.name,
    required this.atMs,
    this.kind,
    this.reason,
  });

  final String name;
  final int atMs;

  /// `open`, `repeat`, `reopen`, `p4`, `p5`, `ack`, `close` or `expire` on a
  /// `push_received` row. Null when the row did not say.
  final String? kind;

  /// Why a `push_dropped` row was dropped. Null when the row did not say.
  final String? reason;

  /// Whether this row could be the push that should have rung an incident.
  ///
  /// A received push of a kind that rings could. So could one the phone
  /// threw away before reading which incident it was for. A push that only
  /// reports a state, a forward, and a repeat dropped because the incident
  /// was already acknowledged here could not.
  bool get couldBeARing {
    if (name == receivedName) {
      return kind == null || _ringingKinds.contains(kind);
    }
    if (name == droppedName) {
      return reason == null || _blindDrops.contains(reason);
    }
    return false;
  }

  static const receivedName = 'push_received';
  static const droppedName = 'push_dropped';
  static const firedName = 'alarm_fired';

  static const _ringingKinds = {'open', 'repeat', 'reopen'};
  static const _blindDrops = {'unparseable', 'other_server'};

  Map<String, Object?> toJson() => {
    'name': name,
    'at_ms': atMs,
    'kind': ?kind,
    'reason': ?reason,
  };

  static PushLogRow? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final name = raw['name'];
    final atMs = raw['at_ms'];
    if (name is! String || atMs is! num) return null;
    final kind = raw['kind'];
    final reason = raw['reason'];
    return PushLogRow(
      name: name,
      atMs: atMs.toInt(),
      kind: kind is String ? kind : null,
      reason: reason is String ? reason : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PushLogRow &&
      other.name == name &&
      other.atMs == atMs &&
      other.kind == kind &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(name, atMs, kind, reason);
}

/// One look at what the phone holds right now.
@immutable
final class PhoneCapture {
  const PhoneCapture({
    this.eventRows = const [],
    this.lostBeforeMs,
    this.arrivedIds = const {},
    this.startedIds = const {},
    this.acknowledgedHereIds = const {},
  });

  /// The rows the native push handlers wrote, as they wrote them: maps with
  /// `name` and `at_ms`. Rows of any other shape are skipped.
  final List<Object?> eventRows;

  /// Set when one of the native lists was full, so older rows may have been
  /// pushed out of it: the time of the oldest row it still held.
  final int? lostBeforeMs;

  /// Incidents a push arrived for or an alarm was set for, from anywhere
  /// other than an `alarm_fired` row. Not proof that anything sounded.
  final Set<String> arrivedIds;

  /// Incidents whose alarm the phone saw sounding, or silenced by hand.
  final Set<String> startedIds;

  /// Incidents acknowledged on this phone.
  final Set<String> acknowledgedHereIds;
}

/// What the phone wrote down about pushes and alarms, kept past the launch
/// that empties the native list.
///
/// It is a copy of what the phone already records. Nothing here is asked of
/// the server, and no message content is in it.
@immutable
final class PhoneRecord {
  const PhoneRecord({
    this.arrivedAtMs = const {},
    this.startedAtMs = const {},
    this.acknowledgedHereAtMs = const {},
    this.rows = const [],
    this.completeSinceMs,
    this.lastCaptureMs,
  });

  /// Reads [raw] back. Anything of the wrong shape is left out, so a damaged
  /// record reads as a record that knows less.
  factory PhoneRecord.fromJson(Object? raw) {
    if (raw is! Map) return const PhoneRecord();
    Map<String, int> times(Object? value) => {
      if (value is Map)
        for (final entry in value.entries)
          if (entry.key is String && entry.value is num)
            entry.key as String: (entry.value as num).toInt(),
    };
    final rows = raw['rows'];
    final completeSince = raw['complete_since_ms'];
    final lastCapture = raw['last_capture_ms'];
    return PhoneRecord(
      // `rang` is what an earlier build called a push that arrived.
      arrivedAtMs: {...times(raw['rang']), ...times(raw['arrived'])},
      startedAtMs: times(raw['started']),
      acknowledgedHereAtMs: times(raw['acked_here']),
      rows: [
        if (rows is List)
          ...rows.map(PushLogRow.fromJson).whereType<PushLogRow>(),
      ],
      completeSinceMs: completeSince is num ? completeSince.toInt() : null,
      lastCaptureMs: lastCapture is num ? lastCapture.toInt() : null,
    );
  }

  /// Incident id to when the phone first recorded a push for it, or an
  /// alarm set for it. An `alarm_fired` row is here too: the phone writes
  /// it when it posts the alarm, before anything is known to sound.
  final Map<String, int> arrivedAtMs;

  /// Incident id to when the phone first saw its alarm sounding.
  final Map<String, int> startedAtMs;

  /// Incident id to when an acknowledgement on this phone was first seen.
  final Map<String, int> acknowledgedHereAtMs;

  /// The pushes that name no incident, oldest first.
  final List<PushLogRow> rows;

  /// [rows] holds every push from this moment on. Null before the first
  /// capture.
  final int? completeSinceMs;

  /// When the phone was last looked at.
  final int? lastCaptureMs;

  /// How long anything is kept. One day longer than the window a missed
  /// alarm is shown for.
  static const keepFor = Duration(days: 8);

  /// The most rows kept.
  static const maxRows = 400;

  /// This record with [capture] added and everything older than [keepFor]
  /// dropped. Pure: the same inputs give the same record.
  PhoneRecord merged(PhoneCapture capture, {required DateTime now}) {
    final nowMs = now.toUtc().millisecondsSinceEpoch;
    final cutoff = nowMs - keepFor.inMilliseconds;

    final arrived = Map<String, int>.of(arrivedAtMs);
    final started = Map<String, int>.of(startedAtMs);
    final acked = Map<String, int>.of(acknowledgedHereAtMs);
    final kept = <PushLogRow>{...rows};

    for (final raw in capture.eventRows) {
      if (raw is! Map) continue;
      final name = raw['name'];
      final atMs = raw['at_ms'];
      if (name is! String || atMs is! num) continue;
      if (name == PushLogRow.firedName) {
        final id = raw['incident_id'];
        if (id is String && id.isNotEmpty) {
          arrived.update(
            id,
            (held) => held < atMs ? held : atMs.toInt(),
            ifAbsent: atMs.toInt,
          );
        }
        continue;
      }
      if (name != PushLogRow.receivedName && name != PushLogRow.droppedName) {
        continue;
      }
      final row = PushLogRow.fromJson(raw);
      if (row != null) kept.add(row);
    }
    for (final id in capture.arrivedIds) {
      if (id.isNotEmpty) arrived.putIfAbsent(id, () => nowMs);
    }
    for (final id in capture.startedIds) {
      if (id.isNotEmpty) started.putIfAbsent(id, () => nowMs);
    }
    for (final id in capture.acknowledgedHereIds) {
      if (id.isNotEmpty) acked.putIfAbsent(id, () => nowMs);
    }

    // The record starts being complete at the first capture, and starts over
    // from the oldest row still held whenever a native list was full.
    var completeSince = completeSinceMs ?? nowMs;
    final lostBefore = capture.lostBeforeMs;
    if (lostBefore != null && lostBefore > completeSince) {
      completeSince = lostBefore;
    }

    var sorted = kept.where((row) => row.atMs >= cutoff).toList()
      ..sort((a, b) => a.atMs.compareTo(b.atMs));
    // A phone that is paged all day does not get to grow this without end.
    // Dropping old rows moves the start of the complete stretch with them.
    if (sorted.length > maxRows) {
      sorted = sorted.sublist(sorted.length - maxRows);
      if (sorted.first.atMs > completeSince) completeSince = sorted.first.atMs;
    }
    return PhoneRecord(
      arrivedAtMs: {
        for (final entry in arrived.entries)
          if (entry.value >= cutoff) entry.key: entry.value,
      },
      startedAtMs: {
        for (final entry in started.entries)
          if (entry.value >= cutoff) entry.key: entry.value,
      },
      acknowledgedHereAtMs: {
        for (final entry in acked.entries)
          if (entry.value >= cutoff) entry.key: entry.value,
      },
      rows: List.unmodifiable(sorted),
      completeSinceMs: completeSince,
      lastCaptureMs: nowMs,
    );
  }

  /// How far the phone's clock and the server's may disagree before a row is
  /// counted outside an incident's time.
  static const clockSlack = Duration(minutes: 2);

  /// What this record says about [incident].
  ///
  /// [everyPushIsLogged] is whether this phone writes a row for every push
  /// that reaches it. Only then can a stretch with no row mean no push.
  ///
  /// Nothing here reads a setting as it is today. Whether a ring was held
  /// (quiet hours) is decided on the native side when the push lands and is
  /// written nowhere, so this never says a ring was held, and it says "it
  /// rang" only when the phone saw the alarm sounding.
  PhoneKnowledge knowledgeFor(
    Incident incident, {
    required bool everyPushIsLogged,
  }) {
    final started = startedAtMs.containsKey(incident.id);
    final arrived = started || arrivedAtMs.containsKey(incident.id);
    return PhoneKnowledge(
      acknowledgedHere: acknowledgedHereAtMs.containsKey(incident.id),
      rang: started,
      pushReached: arrived,
      silenceMeansNoPush:
          !arrived && everyPushIsLogged && _wasSilentFor(incident),
    );
  }

  /// True when the record covers the whole time [incident] rang and holds no
  /// push in it that could have been the incident's.
  bool _wasSilentFor(Incident incident) {
    final openedAt = incident.openedAt;
    final endedAt = incident.closedAt ?? incident.updatedAt;
    final completeSince = completeSinceMs;
    final lastCapture = lastCaptureMs;
    if (openedAt == null || endedAt == null) return false;
    if (completeSince == null || lastCapture == null) return false;
    final slack = clockSlack.inMilliseconds;
    final from = openedAt.toUtc().millisecondsSinceEpoch - slack;
    final to = endedAt.toUtc().millisecondsSinceEpoch + slack;
    // The record has to start before the incident and be read after it.
    if (completeSince > from || lastCapture < to) return false;
    return !rows.any(
      (row) => row.atMs >= from && row.atMs <= to && row.couldBeARing,
    );
  }

  Map<String, Object?> toJson() => {
    'arrived': arrivedAtMs,
    'started': startedAtMs,
    'acked_here': acknowledgedHereAtMs,
    'rows': [for (final row in rows) row.toJson()],
    'complete_since_ms': ?completeSinceMs,
    'last_capture_ms': ?lastCaptureMs,
  };
}
