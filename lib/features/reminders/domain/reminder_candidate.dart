import 'package:critalarm/features/reminders/domain/reminder_kind.dart';
import 'package:flutter/foundation.dart';

/// One reminder a rule wants to plan. [fireAt] is wall-clock.
@immutable
final class ReminderCandidate {
  const ReminderCandidate({
    required this.kind,
    required this.id,
    required this.fireAt,
    this.args = const {},
    this.dedupeKey,
    this.poolIndex,
    this.isOverdue = false,
  });

  final ReminderKind kind;
  final int id;
  final DateTime fireAt;

  /// Words for the copy and data for the tap, keyed by `ReminderArgs`.
  final Map<String, String> args;

  /// What marks this one as done once it fires: a topic name, an incident
  /// id or a plan notice key.
  final String? dedupeKey;

  /// The fire drill line picked from the pool.
  final int? poolIndex;

  /// A fire drill 14+ days past its 30 day mark.
  final bool isOverdue;

  ReminderCandidate copyWith({DateTime? fireAt}) => ReminderCandidate(
    kind: kind,
    id: id,
    fireAt: fireAt ?? this.fireAt,
    args: args,
    dedupeKey: dedupeKey,
    poolIndex: poolIndex,
    isOverdue: isOverdue,
  );
}
