import 'package:critalarm/features/in_app_notices/domain/pro_ask_rules.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_candidate.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_dates.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_ids.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_inputs.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_kind.dart';

/// The Pro sheet's "Remind me later" with Offers on: the ask comes back as a
/// notification 30 days later instead of as the sheet.
abstract final class ProLaterRule {
  static const Duration after = Duration(days: 30);
  static const int fireHour = 10;

  static LocalReminderCandidate? candidate(LocalReminderInputs inputs) {
    final later = inputs.proLaterAt;
    if (later == null) return null;
    if (inputs.isPaid) return null;
    if (inputs.proDismissCount >= ProAskRules.maxDismissals) return null;

    final fireAt = LocalReminderDates.atHourOnOrAfter(
      LocalReminderDates.later(later.add(after), inputs.now),
      fireHour,
    );
    return LocalReminderCandidate(
      kind: LocalReminderKind.proLater,
      id: LocalReminderIds.proLater,
      fireAt: fireAt,
    );
  }
}
