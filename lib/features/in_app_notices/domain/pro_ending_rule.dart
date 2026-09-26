import 'package:critalarm/features/local_reminders/domain/local_reminder_inputs.dart';

/// When the "Pro ends" pill shows, for a plan that was cancelled but has not
/// ended yet. Pure, so it tests without a clock or a store.
abstract final class ProEndingRule {
  /// A closed pill stays away this long.
  static const Duration pillSnooze = Duration(days: 5);

  /// Inside this window before the end, a closed pill comes back once.
  static const Duration lastDays = Duration(days: 2);

  /// Pro is still on, will not renew, and has not ended. A billing problem
  /// on a plan that still renews is not a cancel.
  static bool isCancelled(PlanStatus plan, DateTime now) {
    final endsAt = plan.expiresAt;
    return plan.isActive &&
        !plan.willRenew &&
        endsAt != null &&
        now.isBefore(endsAt);
  }

  /// Marks one billing period, so a later cancel asks again.
  static String keyFor(DateTime endsAt) =>
      '${endsAt.year}-${endsAt.month}-${endsAt.day}';

  static bool isLastDays({required DateTime now, required DateTime endsAt}) =>
      !now.isBefore(endsAt.subtract(lastDays));

  static bool shouldShowPill({
    required DateTime now,
    required DateTime endsAt,
    required bool sheetShown,
    required DateTime? pillDismissedAt,
    required bool lastDaysDismissed,
  }) {
    if (!now.isBefore(endsAt)) return false;
    if (!sheetShown) return false;
    if (isLastDays(now: now, endsAt: endsAt)) return !lastDaysDismissed;
    return pillDismissedAt == null ||
        now.difference(pillDismissedAt) >= pillSnooze;
  }
}
