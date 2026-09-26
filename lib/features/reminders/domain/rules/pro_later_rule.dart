import 'package:critalarm/features/in_app_notices/domain/pro_ask_rules.dart';
import 'package:critalarm/features/reminders/domain/reminder_candidate.dart';
import 'package:critalarm/features/reminders/domain/reminder_dates.dart';
import 'package:critalarm/features/reminders/domain/reminder_ids.dart';
import 'package:critalarm/features/reminders/domain/reminder_inputs.dart';
import 'package:critalarm/features/reminders/domain/reminder_kind.dart';

/// The Pro sheet's "Remind me later" with Offers on: the ask comes back as a
/// notification 30 days later instead of as the sheet.
abstract final class ProLaterRule {
  static const Duration after = Duration(days: 30);
  static const int fireHour = 10;

  static ReminderCandidate? candidate(ReminderInputs inputs) {
    final later = inputs.proLaterAt;
    if (later == null) return null;
    if (inputs.isPaid) return null;
    if (inputs.proDismissCount >= ProAskRules.maxDismissals) return null;

    final fireAt = ReminderDates.atHourOnOrAfter(
      ReminderDates.later(later.add(after), inputs.now),
      fireHour,
    );
    return ReminderCandidate(
      kind: ReminderKind.proLater,
      id: ReminderIds.proLater,
      fireAt: fireAt,
    );
  }
}
