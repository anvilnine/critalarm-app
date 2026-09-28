import 'package:critalarm/features/local_reminders/domain/local_reminder_kind.dart';

/// Which reminders work on a self-hosted server (spec, "Self-hosted
/// servers"). Backup needs sign-in, which answers 501 there, and there is
/// no Pro to offer.
abstract final class SelfHostedMatrix {
  static bool allows(LocalReminderKind kind) => switch (kind) {
    LocalReminderKind.fireDrill => true,
    LocalReminderKind.silentTopic => true,
    LocalReminderKind.backup => false,
    LocalReminderKind.planHeadsUp => false,
    LocalReminderKind.morningAfter => false,
    LocalReminderKind.proLater => false,
    LocalReminderKind.reviewAsk => true,
    LocalReminderKind.feedbackAsk => true,
  };

  /// The Offers switch, the sheet's Offers checkbox and the Pro sheet are
  /// all hidden on a self-hosted server.
  static const bool showsOffers = false;
}
