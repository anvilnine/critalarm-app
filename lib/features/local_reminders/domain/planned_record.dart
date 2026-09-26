import 'package:critalarm/features/local_reminders/domain/local_reminder_kind.dart';
import 'package:flutter/foundation.dart';

/// A reminder a plan pass handed to the scheduler. Kept so the next pass
/// can tell, once the fire time passed, that it was delivered.
@immutable
final class PlannedRecord {
  const PlannedRecord({
    required this.id,
    required this.kind,
    required this.fireAt,
    this.dedupeKey,
    this.poolIndex,
  });

  final int id;
  final LocalReminderKind kind;

  /// An instant, not wall-clock, so a time zone change cannot move it.
  final DateTime fireAt;
  final String? dedupeKey;
  final int? poolIndex;

  /// Null for anything this build cannot read, such as a kind a later build
  /// dropped.
  static PlannedRecord? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final wire = json['kind'];
    final kind = wire is String ? LocalReminderKind.fromWire(wire) : null;
    final fireAt = json['fire_at'];
    final dedupeKey = json['dedupe_key'];
    final poolIndex = json['pool'];
    if (id is! int || kind == null || fireAt is! int) return null;
    if (dedupeKey is! String? || poolIndex is! int?) return null;
    return PlannedRecord(
      id: id,
      kind: kind,
      fireAt: DateTime.fromMillisecondsSinceEpoch(fireAt),
      dedupeKey: dedupeKey,
      poolIndex: poolIndex,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.wireName,
    'fire_at': fireAt.millisecondsSinceEpoch,
    if (dedupeKey != null) 'dedupe_key': dedupeKey,
    if (poolIndex != null) 'pool': poolIndex,
  };
}
