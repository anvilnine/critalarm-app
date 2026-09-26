import 'package:critalarm/features/reminders/domain/reminder_args.dart';
import 'package:critalarm/features/reminders/domain/reminder_candidate.dart';
import 'package:critalarm/features/reminders/domain/reminder_dates.dart';
import 'package:critalarm/features/reminders/domain/reminder_ids.dart';
import 'package:critalarm/features/reminders/domain/reminder_inputs.dart';
import 'package:critalarm/features/reminders/domain/reminder_kind.dart';

/// Idea 7: two or more topics on a signed-out hosted phone are one lost
/// phone away from gone. Shares the 7 day snooze of the home "Back up your
/// topics" card, so the two never nag in the same week.
abstract final class BackupRule {
  static const Duration afterSecondTopic = Duration(days: 7);
  static const Duration snooze = Duration(days: 7);
  static const int fireHour = 10;
  static const int minTopics = 2;

  static ReminderCandidate? candidate(ReminderInputs inputs) {
    if (!inputs.isHosted || inputs.isSelfHosted || inputs.isSignedIn) {
      return null;
    }
    if (inputs.topics.length < minTopics) return null;

    final made = [
      for (final topic in inputs.topics)
        if (topic.createdAt != null) topic.createdAt!,
    ]..sort();
    if (made.length < minTopics) return null;

    var due = made[minTopics - 1].add(afterSecondTopic);
    final dismissed = inputs.accountNoticeDismissedAt;
    if (dismissed != null) {
      due = ReminderDates.later(due, dismissed.add(snooze));
    }

    final fireAt = ReminderDates.atHourOnOrAfter(
      ReminderDates.later(due, inputs.now),
      fireHour,
    );
    return ReminderCandidate(
      kind: ReminderKind.backup,
      id: ReminderIds.backup,
      fireAt: fireAt,
      args: {ReminderArgs.count: '${inputs.topics.length}'},
    );
  }
}
