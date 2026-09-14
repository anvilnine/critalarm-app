import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:flutter/foundation.dart';

/// One past alarm, ready to draw: which topic rang, when, for how long, and
/// how it ended.
@immutable
class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.topic,
    required this.startedAt,
    required this.state,
    required this.ringDuration,
  });

  final String id;
  final String topic;
  final DateTime startedAt;
  final IncidentState state;

  /// How long it rang before it stopped. Null when it never rang.
  final Duration? ringDuration;

  /// The day this alarm belongs to, with the time stripped off.
  DateTime get day => DateTime(startedAt.year, startedAt.month, startedAt.day);

  FaceState get faceState => switch (state) {
    IncidentState.open => FaceState.alarmed,
    IncidentState.acked => FaceState.acked,
    IncidentState.closed => FaceState.calm,
    IncidentState.expired => FaceState.calm,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HistoryEntry &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          topic == other.topic &&
          startedAt == other.startedAt &&
          state == other.state &&
          ringDuration == other.ringDuration;

  @override
  int get hashCode => Object.hash(id, topic, startedAt, state, ringDuration);
}

/// One day of alarms in the list.
@immutable
class HistoryDay {
  const HistoryDay({required this.day, required this.entries});

  final DateTime day;
  final List<HistoryEntry> entries;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HistoryDay &&
          runtimeType == other.runtimeType &&
          day == other.day &&
          listEquals(entries, other.entries);

  @override
  int get hashCode => Object.hash(day, Object.hashAll(entries));
}
