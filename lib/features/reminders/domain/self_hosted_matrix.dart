import 'package:critalarm/features/reminders/domain/reminder_kind.dart';

/// Which reminders work on a self-hosted server (spec, "Self-hosted
/// servers"). Backup needs sign-in, which answers 501 there, and there is
/// no Pro to offer.
abstract final class SelfHostedMatrix {
  static bool allows(ReminderKind kind) => switch (kind) {
    ReminderKind.fireDrill => true,
    ReminderKind.silentTopic => true,
    ReminderKind.backup => false,
    ReminderKind.planHeadsUp => false,
    ReminderKind.morningAfter => false,
    ReminderKind.proLater => false,
    ReminderKind.reviewAsk => true,
    ReminderKind.feedbackAsk => true,
  };

  /// The Offers switch, the sheet's Offers checkbox and the Pro sheet are
  /// all hidden on a self-hosted server.
  static const bool showsOffers = false;
}
