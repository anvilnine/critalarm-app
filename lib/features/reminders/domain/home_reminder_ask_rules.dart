import 'package:critalarm/features/in_app_notices/domain/home_ask_rules.dart';
import 'package:critalarm/features/reminders/domain/reminder_time_rules.dart';

/// What home may show for reminders as it opens.
enum HomeReminderAsk { none, remindersSheet, proSheet }

/// Two home-open moments the reminders feature owns, checked before
/// `HomeAskRules`:
///
/// - The Reminders sheet for an install that already tested before this
///   update (1+ critical topic and an ack on record). Once.
/// - A Pro sheet owed by a night ack, shown on the next daytime open.
///
/// Neither shows before onboarding is finished and the first Feature Guide
/// has been seen or skipped (`isSetupDone`).
abstract final class HomeReminderAskRules {
  static HomeReminderAsk decide({
    required bool isSetupDone,
    required DateTime now,
    required bool isWeb,
    required bool isRinging,
    required bool isSheetShown,
    required bool hasCriticalTopic,
    required DateTime? lastAcknowledgedAt,
    required bool isProSheetOwed,
    required bool proShouldAsk,
    List<DateTime?> otherAskedAt = const [],
  }) {
    if (!isSetupDone || isWeb || isRinging) return HomeReminderAsk.none;
    if (HomeAskRules.isWithinGap(now: now, askedAt: otherAskedAt)) {
      return HomeReminderAsk.none;
    }
    if (!isSheetShown && hasCriticalTopic && lastAcknowledgedAt != null) {
      return HomeReminderAsk.remindersSheet;
    }
    final isDaytime =
        now.hour >= ReminderTimeRules.dayStartHour &&
        now.hour < ReminderTimeRules.dayEndHour;
    if (isProSheetOwed && proShouldAsk && isDaytime) {
      return HomeReminderAsk.proSheet;
    }
    return HomeReminderAsk.none;
  }
}
