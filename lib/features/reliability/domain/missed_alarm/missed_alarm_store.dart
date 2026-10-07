import 'package:critalarm/features/reliability/domain/missed_alarm/phone_record.dart';
import 'package:flutter/foundation.dart';

/// The server this phone saw itself connected to, and since when.
@immutable
final class ConnectedServer {
  const ConnectedServer({required this.server, required this.since});

  final String server;
  final DateTime since;
}

/// One stretch of time this phone held a topic.
@immutable
final class TopicHold {
  const TopicHold({required this.since, this.until});

  final DateTime since;

  /// When the topic left the phone's list. Null while it is still held.
  final DateTime? until;

  /// Whether the topic was held at [at].
  bool covers(DateTime at) =>
      !at.isBefore(since) && (until == null || at.isBefore(until!));

  @override
  bool operator ==(Object other) =>
      other is TopicHold && other.since == since && other.until == until;

  @override
  int get hashCode => Object.hash(since, until);

  @override
  String toString() => 'TopicHold($since, $until)';
}

/// What the missed alarm check keeps on the phone.
abstract interface class MissedAlarmStore {
  /// What the phone wrote down about pushes and alarms.
  PhoneRecord readRecord();
  Future<void> writeRecord(PhoneRecord record);

  /// Incident id to when its Home entry was closed. A closed one never
  /// comes back.
  Map<String, DateTime> readDismissed();
  Future<void> writeDismissed(Map<String, DateTime> dismissed);

  /// When this phone first saw setup done. Null until then.
  DateTime? readSetupDoneAt();
  Future<void> writeSetupDoneAt(DateTime at);

  /// The server this phone is connected to and since when. Null before any
  /// stamp, and an empty server while the phone has none.
  ConnectedServer? readConnected();
  Future<void> writeConnected(ConnectedServer connected);

  /// Topic name to the stretches this phone held it, oldest first. The
  /// last one has no end while the topic is still held.
  Map<String, List<TopicHold>> readTopicHolds();
  Future<void> writeTopicHolds(Map<String, List<TopicHold>> holds);

  /// Drops everything that belongs to one server: the phone's record, the
  /// closed entries and the topic stamps. The setup stamp stays, since setup
  /// is about the phone.
  Future<void> clearServerData();
}
