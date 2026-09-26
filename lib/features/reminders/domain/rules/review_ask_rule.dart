import 'package:critalarm/features/in_app_notices/domain/home_ask_rules.dart';
import 'package:critalarm/features/reminders/domain/reminder_args.dart';
import 'package:critalarm/features/reminders/domain/reminder_candidate.dart';
import 'package:critalarm/features/reminders/domain/reminder_dates.dart';
import 'package:critalarm/features/reminders/domain/reminder_ids.dart';
import 'package:critalarm/features/reminders/domain/reminder_inputs.dart';
import 'package:critalarm/features/reminders/domain/reminder_kind.dart';

/// Idea 21: the user acked an alarm and then left the app alone, so the
/// home popup never got its chance. Asks at 10:00 four days later, only
/// when the home popup's own rules would ask at that moment.
abstract final class ReviewAskRule {
  static const Duration afterAck = Duration(days: 4);
  static const int fireHour = 10;
  static const Duration feedbackGap = Duration(days: 7);
  static const Duration ringGap = Duration(hours: 24);

  static ReminderCandidate? candidate(ReminderInputs inputs) {
    final ack = inputs.lastAcknowledgedAt;
    if (ack == null) return null;
    final fireAt = ReminderDates.atHour(
      ReminderDates.addDays(ack, afterAck.inDays),
      fireHour,
    );
    if (!fireAt.isAfter(inputs.now)) return null;
    if (inputs.isIos && inputs.appStoreId.isEmpty) return null;

    final ask = HomeAskRules.decide(
      isSetupDone: inputs.isSetupDone,
      now: fireAt,
      firstSeenAt: inputs.installedAt,
      consentAskedAt: inputs.consentAskedAt,
      isConsentGiven: inputs.isConsentGiven,
      reviewAskedAt: inputs.reviewAskedAt,
      reviewAskCount: inputs.reviewAskCount,
      lastAcknowledgedAt: ack,
      proAskedAt: inputs.proAskedAt,
      isRinging: false,
      isWeb: inputs.isWeb,
      feedbackAskedAt: inputs.feedbackAskedAt,
    );
    if (ask != HomeAsk.review) return null;

    final failed = inputs.lastTestFailedAt;
    if (failed != null && failed.isAfter(ack)) return null;
    if (inputs.incidents.any((i) => i.isOpenOrAcked)) return null;
    if (ReminderDates.hasRingWithin(inputs.incidents, fireAt, ringGap)) {
      return null;
    }
    final feedback = inputs.feedbackAskedAt;
    if (feedback != null && fireAt.difference(feedback).abs() < feedbackGap) {
      return null;
    }

    return ReminderCandidate(
      kind: ReminderKind.reviewAsk,
      id: ReminderIds.reviewAsk,
      fireAt: fireAt,
      args: {ReminderArgs.pool: '${inputs.reviewAskCount % 2}'},
    );
  }
}
