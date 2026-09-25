import 'package:critalarm/features/reminders/domain/reminder_switches.dart';
import 'package:critalarm/features/reminders/domain/self_hosted_matrix.dart';

/// What each answer on the Reminders sheet writes.
abstract final class RemindersSheetChoice {
  /// "Turn on reminders": Reminders on, Offers only if the unticked box was
  /// ticked, never on a self-hosted server, and never for someone who already
  /// pays for Pro.
  static ReminderSwitches turnOn({
    required bool offersTicked,
    required bool isSelfHosted,
    bool isPaid = false,
  }) => ReminderSwitches(
    reminders: true,
    offers:
        offersTicked &&
        !isPaid &&
        (!isSelfHosted || SelfHostedMatrix.showsOffers),
  );

  /// "No thanks": both off.
  static const ReminderSwitches noThanks = ReminderSwitches.allOff;
}
