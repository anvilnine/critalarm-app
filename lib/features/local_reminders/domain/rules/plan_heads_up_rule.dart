import 'package:critalarm/features/local_reminders/domain/local_reminder_args.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_candidate.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_dates.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_ids.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_inputs.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_kind.dart';
import 'package:easy_localization/easy_localization.dart';

/// The three plan heads-ups of idea 8.
enum PlanHeadsUpKind {
  /// (a) the store could not take the payment.
  billing(LocalReminderIds.planFirst),

  /// (b) a yearly plan renews in 3 days.
  renew(LocalReminderIds.planFirst + 1),

  /// (c) a cancelled plan ends in 2 days.
  ends(LocalReminderIds.planFirst + 2);

  const PlanHeadsUpKind(this.id);

  final int id;
}

/// Idea 8: honest heads-ups about money. Hosted mode with Pro active only.
/// Skips the weekly budget, and each heads-up fires once per billing period.
abstract final class PlanHeadsUpRule {
  static const Duration renewLead = Duration(days: 3);
  static const Duration endLead = Duration(days: 2);
  static const int fireHour = 10;

  /// Marks one heads-up for one billing period as sent.
  static String keyFor(PlanHeadsUpKind kind, DateTime at) =>
      '${kind.name}:${at.year}-${at.month}-${at.day}';

  static List<LocalReminderCandidate> candidates(LocalReminderInputs inputs) {
    final plan = inputs.plan;
    if (!inputs.isHosted || plan == null || !plan.isActive) return const [];
    final url = plan.managementUrl ?? '';
    final out = <LocalReminderCandidate>[];

    final issue = plan.billingIssueAt;
    if (issue != null) {
      final key = keyFor(PlanHeadsUpKind.billing, issue);
      if (!inputs.planHeadsUpsSent.contains(key)) {
        out.add(
          _headsUp(
            PlanHeadsUpKind.billing,
            LocalReminderDates.atHourOnOrAfter(inputs.now, fireHour),
            key,
            {LocalReminderArgs.url: url},
          ),
        );
      }
    }

    final expires = plan.expiresAt;
    final price = plan.priceString;
    if (expires != null && plan.willRenew && plan.isYearly && price != null) {
      final key = keyFor(PlanHeadsUpKind.renew, expires);
      final fireAt = LocalReminderDates.atHour(
        LocalReminderDates.addDays(expires, -renewLead.inDays),
        fireHour,
      );
      if (fireAt.isAfter(inputs.now) &&
          !inputs.planHeadsUpsSent.contains(key)) {
        out.add(
          _headsUp(PlanHeadsUpKind.renew, fireAt, key, {
            LocalReminderArgs.date: DateFormat('d MMM').format(expires),
            LocalReminderArgs.price: price,
            LocalReminderArgs.url: url,
          }),
        );
      }
    }

    if (expires != null && !plan.willRenew) {
      final key = keyFor(PlanHeadsUpKind.ends, expires);
      final fireAt = LocalReminderDates.atHour(
        LocalReminderDates.addDays(expires, -endLead.inDays),
        fireHour,
      );
      if (fireAt.isAfter(inputs.now) &&
          !inputs.planHeadsUpsSent.contains(key)) {
        out.add(
          _headsUp(PlanHeadsUpKind.ends, fireAt, key, {
            LocalReminderArgs.weekday: DateFormat('EEEE').format(expires),
            LocalReminderArgs.url: url,
          }),
        );
      }
    }
    return out;
  }

  static LocalReminderCandidate _headsUp(
    PlanHeadsUpKind kind,
    DateTime fireAt,
    String key,
    Map<String, String> args,
  ) => LocalReminderCandidate(
    kind: LocalReminderKind.planHeadsUp,
    id: kind.id,
    fireAt: fireAt,
    args: {LocalReminderArgs.headsUp: kind.name, ...args},
    dedupeKey: key,
  );
}
