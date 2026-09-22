import 'package:critalarm/features/reminders/domain/reminder_args.dart';
import 'package:critalarm/features/reminders/domain/reminder_candidate.dart';
import 'package:critalarm/features/reminders/domain/reminder_dates.dart';
import 'package:critalarm/features/reminders/domain/reminder_ids.dart';
import 'package:critalarm/features/reminders/domain/reminder_inputs.dart';
import 'package:critalarm/features/reminders/domain/reminder_kind.dart';
import 'package:easy_localization/easy_localization.dart';

/// The three account notices of idea 8.
enum PlanNotice {
  /// (a) the store could not take the payment.
  billing(ReminderIds.planFirst),

  /// (b) a yearly plan renews in 3 days.
  renew(ReminderIds.planFirst + 1),

  /// (c) a cancelled plan ends in 2 days.
  ends(ReminderIds.planFirst + 2);

  const PlanNotice(this.id);

  final int id;
}

/// Idea 8: honest notices about money. Hosted mode with Pro active only.
/// Skips the weekly budget, and each notice fires once per billing period.
abstract final class PlanHeadsUpRule {
  static const Duration renewLead = Duration(days: 3);
  static const Duration endLead = Duration(days: 2);
  static const int fireHour = 10;

  /// Marks one notice for one billing period as sent.
  static String keyFor(PlanNotice notice, DateTime at) =>
      '${notice.name}:${at.year}-${at.month}-${at.day}';

  static List<ReminderCandidate> candidates(ReminderInputs inputs) {
    final plan = inputs.plan;
    if (!inputs.isHosted || plan == null || !plan.isActive) return const [];
    final url = plan.managementUrl ?? '';
    final out = <ReminderCandidate>[];

    final issue = plan.billingIssueAt;
    if (issue != null) {
      final key = keyFor(PlanNotice.billing, issue);
      if (!inputs.planNoticesSent.contains(key)) {
        out.add(
          _notice(
            PlanNotice.billing,
            ReminderDates.atHourOnOrAfter(inputs.now, fireHour),
            key,
            {ReminderArgs.url: url},
          ),
        );
      }
    }

    final expires = plan.expiresAt;
    final price = plan.priceString;
    if (expires != null && plan.willRenew && plan.isYearly && price != null) {
      final key = keyFor(PlanNotice.renew, expires);
      final fireAt = ReminderDates.atHour(
        ReminderDates.addDays(expires, -renewLead.inDays),
        fireHour,
      );
      if (fireAt.isAfter(inputs.now) && !inputs.planNoticesSent.contains(key)) {
        out.add(
          _notice(PlanNotice.renew, fireAt, key, {
            ReminderArgs.date: DateFormat('d MMM').format(expires),
            ReminderArgs.price: price,
            ReminderArgs.url: url,
          }),
        );
      }
    }

    if (expires != null && !plan.willRenew) {
      final key = keyFor(PlanNotice.ends, expires);
      final fireAt = ReminderDates.atHour(
        ReminderDates.addDays(expires, -endLead.inDays),
        fireHour,
      );
      if (fireAt.isAfter(inputs.now) && !inputs.planNoticesSent.contains(key)) {
        out.add(
          _notice(PlanNotice.ends, fireAt, key, {
            ReminderArgs.weekday: DateFormat('EEEE').format(expires),
            ReminderArgs.url: url,
          }),
        );
      }
    }
    return out;
  }

  static ReminderCandidate _notice(
    PlanNotice notice,
    DateTime fireAt,
    String key,
    Map<String, String> args,
  ) => ReminderCandidate(
    kind: ReminderKind.planHeadsUp,
    id: notice.id,
    fireAt: fireAt,
    args: {ReminderArgs.notice: notice.name, ...args},
    dedupeKey: key,
  );
}
