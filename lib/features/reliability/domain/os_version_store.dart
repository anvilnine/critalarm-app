import 'package:flutter/foundation.dart';

/// The OS version the phone last saw, and when it saw it change.
@immutable
final class OsVersionRecord {
  const OsVersionRecord({this.major, this.changedAt});

  /// Null before the first run.
  final int? major;

  /// When a different version was first seen. Null if it never has been.
  final DateTime? changedAt;

  @override
  bool operator ==(Object other) =>
      other is OsVersionRecord &&
      other.major == major &&
      other.changedAt == changedAt;

  @override
  int get hashCode => Object.hash(major, changedAt);
}

abstract interface class OsVersionStore {
  OsVersionRecord read();
  Future<void> write(OsVersionRecord record);
}
