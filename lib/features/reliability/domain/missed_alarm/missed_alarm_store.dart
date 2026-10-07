import 'package:critalarm/features/reliability/domain/missed_alarm/phone_record.dart';
import 'package:flutter/foundation.dart';

/// The server this phone saw itself connected to, and since when.
@immutable
final class ConnectedServer {
  const ConnectedServer({required this.server, required this.since});

  final String server;
  final DateTime since;
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

  /// The server this phone last saw itself connected to. Null before that.
  ConnectedServer? readConnected();
  Future<void> writeConnected(ConnectedServer connected);
}
