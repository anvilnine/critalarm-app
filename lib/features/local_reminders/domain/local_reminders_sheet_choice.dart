import 'package:critalarm/features/local_reminders/domain/local_reminder_switches.dart';
import 'package:critalarm/features/local_reminders/domain/self_hosted_matrix.dart';

/// What each answer on the Reminders sheet writes.
abstract final class LocalRemindersSheetChoice {
  /// "Turn on reminders": Reminders on, Offers only if the unticked box was
  /// ticked, never on a self-hosted server, and never for someone who already
  /// pays for Pro.
  static LocalReminderSwitches turnOn({
    required bool offersTicked,
    required bool isSelfHosted,
    bool isPaid = false,
  }) => LocalReminderSwitches(
    reminders: true,
    offers:
        offersTicked &&
        !isPaid &&
        (!isSelfHosted || SelfHostedMatrix.showsOffers),
  );

  /// "No thanks": both off.
  static const LocalReminderSwitches noThanks = LocalReminderSwitches.allOff;
}
