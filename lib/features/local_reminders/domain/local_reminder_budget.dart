import 'package:critalarm/features/local_reminders/domain/local_reminder_candidate.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_dates.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_kind.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_time_rules.dart';
import 'package:critalarm/features/local_reminders/domain/rules/feedback_ask_rule.dart';

/// At most one of ideas 1, 10, 2, 7, 21 and 22 per 7 days.
abstract final class LocalReminderBudget {
  static const Duration window = Duration(days: 7);

  /// The one budgeted reminder to plan, or null.
  ///
  /// Any candidate whose kind does not share the weekly budget is ignored,
  /// so idea 8 or the Pro remind-later notice can never win this slot.
  ///
  /// A candidate due before the slot opens again ([spentAt] plus a week) is
  /// moved to the first allowed moment after that, or dropped when it only
  /// makes sense on its own morning (idea 10). Then an overdue drill wins
  /// outright. Otherwise the best priority wins among the candidates due
  /// within a week of the earliest one, so a low priority reminder due soon
  /// is not held back for weeks by a higher one due later.
  static LocalReminderCandidate? pick(
    List<LocalReminderCandidate> candidates, {
    required DateTime? spentAt,
    required LocalReminderTimeRules rules,
  }) {
    final opensAt = spentAt?.add(window);
    final ready = <LocalReminderCandidate>[];
    for (final candidate in candidates) {
      if (!candidate.kind.usesBudget) continue;
      if (opensAt == null || !candidate.fireAt.isBefore(opensAt)) {
        ready.add(candidate);
        continue;
      }
      if (candidate.kind == LocalReminderKind.morningAfter) continue;
      if (candidate.kind == LocalReminderKind.feedbackAsk) {
        final moved = snapFeedbackAsk(opensAt, rules);
        if (moved != null) ready.add(candidate.copyWith(fireAt: moved));
        continue;
      }
      final isDrill = candidate.kind == LocalReminderKind.fireDrill;
      final start = isDrill
          ? LocalReminderDates.weekdayAtHourOnOrAfter(
              opensAt,
              DateTime.saturday,
              LocalReminderTimeRules.defaultHour,
            )
          : LocalReminderDates.atHourOnOrAfter(
              opensAt,
              LocalReminderTimeRules.defaultHour,
            );
      final moved = rules.nextAllowed(start, stepDays: isDrill ? 7 : 1);
      if (moved != null) ready.add(candidate.copyWith(fireAt: moved));
    }
    if (ready.isEmpty) return null;

    final overdue = ready.where(
      (c) => c.kind == LocalReminderKind.fireDrill && c.isOverdue,
    );
    if (overdue.isNotEmpty) return overdue.first;

    final earliest = ready
        .map((c) => c.fireAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final contenders =
        ready.where((c) => c.fireAt.isBefore(earliest.add(window))).toList()
          ..sort((a, b) {
            final byPriority = a.kind.priority.compareTo(b.kind.priority);
            return byPriority != 0 ? byPriority : a.fireAt.compareTo(b.fireAt);
          });
    return contenders.first;
  }

  /// Re-snaps a feedback ask (idea 22) to the next Tuesday, Wednesday or
  /// Thursday at [LocalReminderTimeRules.defaultHour] on or after [from], the
  /// only slot the idea ever fires at. A generic move (the budget's opened
  /// slot or the planner's own time rules) does not know about that day
  /// restriction, so it must be re-applied here. Null when nothing turns up
  /// within [FeedbackAskRule.searchDays].
  static DateTime? snapFeedbackAsk(
    DateTime from,
    LocalReminderTimeRules rules,
  ) {
    var day = LocalReminderDates.atHourOnOrAfter(
      from,
      LocalReminderTimeRules.defaultHour,
    );
    for (var i = 0; i < FeedbackAskRule.searchDays; i++) {
      if (FeedbackAskRule.isAskDay(day) && rules.allows(day)) return day;
      day = LocalReminderDates.addDays(day, 1);
    }
    return null;
  }
}
