import 'package:critalarm/features/local_reminders/domain/local_reminder_kind.dart';
import 'package:flutter/foundation.dart';

/// One reminder a rule wants to plan. [fireAt] is wall-clock.
@immutable
final class LocalReminderCandidate {
  const LocalReminderCandidate({
    required this.kind,
    required this.id,
    required this.fireAt,
    this.args = const {},
    this.dedupeKey,
    this.poolIndex,
    this.isOverdue = false,
  });

  final LocalReminderKind kind;
  final int id;
  final DateTime fireAt;

  /// Words for the copy and data for the tap, keyed by `LocalReminderArgs`.
  final Map<String, String> args;

  /// What marks this one as done once it fires: a topic name, an incident
  /// id or a plan notice key.
  final String? dedupeKey;

  /// The fire drill line picked from the pool.
  final int? poolIndex;

  /// A fire drill 14+ days past its 30 day mark.
  final bool isOverdue;

  LocalReminderCandidate copyWith({DateTime? fireAt}) => LocalReminderCandidate(
    kind: kind,
    id: id,
    fireAt: fireAt ?? this.fireAt,
    args: args,
    dedupeKey: dedupeKey,
    poolIndex: poolIndex,
    isOverdue: isOverdue,
  );
}
