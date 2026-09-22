import 'package:flutter/foundation.dart';

/// How long the phone keeps an alarm before deleting it by itself.
///
/// The phone is the archive (api.md §4.2), so nothing here is a plan cap.
/// It is the user choosing to let go of old alarms. [never] is the default
/// and the only value a free account can have.
enum HistoryRetention {
  never(null),
  oneMonth(30),
  threeMonths(90),
  oneYear(365);

  const HistoryRetention(this.days);

  /// How many days back auto-delete reaches, or null for "keep everything".
  final int? days;

  static HistoryRetention byName(String? name) => values.firstWhere(
    (value) => value.name == name,
    orElse: () => HistoryRetention.never,
  );
}

/// The two Storage rows in Settings.
@immutable
class StorageSettings {
  const StorageSettings({
    this.retention = HistoryRetention.never,
    this.keepCriticalForever = true,
  });

  final HistoryRetention retention;

  /// A P5 incident, and its messages, skip auto-delete while this is on.
  final bool keepCriticalForever;

  StorageSettings copyWith({
    HistoryRetention? retention,
    bool? keepCriticalForever,
  }) => StorageSettings(
    retention: retention ?? this.retention,
    keepCriticalForever: keepCriticalForever ?? this.keepCriticalForever,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StorageSettings &&
          retention == other.retention &&
          keepCriticalForever == other.keepCriticalForever;

  @override
  int get hashCode => Object.hash(retention, keepCriticalForever);
}
