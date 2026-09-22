import 'package:critalarm/features/reminders/domain/reminder_args.dart';
import 'package:critalarm/features/reminders/domain/reminder_candidate.dart';
import 'package:critalarm/features/reminders/domain/reminder_dates.dart';
import 'package:critalarm/features/reminders/domain/reminder_ids.dart';
import 'package:critalarm/features/reminders/domain/reminder_inputs.dart';
import 'package:critalarm/features/reminders/domain/reminder_kind.dart';

/// Idea 22: three weeks in, somebody who has used the app gets one ask for
/// feedback, on a Tuesday, Wednesday or Thursday at 10:00. Once per install.
abstract final class FeedbackAskRule {
  static const Duration minInstallAge = Duration(days: 21);
  static const int fireHour = 10;
  static const Duration reviewGap = Duration(days: 7);
  static const Duration ringGap = Duration(hours: 24);

  /// How far ahead to look for an allowed day before giving up.
  static const int searchDays = 60;

  static bool isAskDay(DateTime day) =>
      day.weekday >= DateTime.tuesday && day.weekday <= DateTime.thursday;

  /// [pendingReviewAt] is a review ask (idea 21) this same pass wants to
  /// plan. The feedback ask keeps 7 days from it on either side.
  static ReminderCandidate? candidate(
    ReminderInputs inputs, {
    DateTime? pendingReviewAt,
  }) {
    if (inputs.feedbackFormUrl.isEmpty) return null;
    if (inputs.feedbackAskedAt != null) return null;
    final installed = inputs.installedAt;
    if (installed == null) return null;

    final ack = inputs.lastAcknowledgedAt;
    final hasUsedIt = ack != null || inputs.lastTestAt.isNotEmpty;
    if (!hasUsedIt) return null;
    if (inputs.incidents.any((i) => i.isOpenOrAcked)) return null;
    final failed = inputs.lastTestFailedAt;
    if (failed != null && (ack == null || failed.isAfter(ack))) return null;

    var day = ReminderDates.atHour(
      ReminderDates.addDays(installed, minInstallAge.inDays),
      fireHour,
    );
    if (day.isBefore(inputs.now)) {
      day = ReminderDates.atHourOnOrAfter(inputs.now, fireHour);
    }

    for (var n = 0; n < searchDays; n++) {
      final isNearReview =
          _within(day, inputs.reviewAskedAt, reviewGap) ||
          _within(day, pendingReviewAt, reviewGap);
      if (isAskDay(day) &&
          !isNearReview &&
          !ReminderDates.hasRingWithin(inputs.incidents, day, ringGap)) {
        return ReminderCandidate(
          kind: ReminderKind.feedbackAsk,
          id: ReminderIds.feedbackAsk,
          fireAt: day,
          args: {ReminderArgs.pool: '${day.day % 2}'},
        );
      }
      day = ReminderDates.addDays(day, 1);
    }
    return null;
  }

  static bool _within(DateTime at, DateTime? other, Duration gap) =>
      other != null && at.difference(other).abs() < gap;
}
