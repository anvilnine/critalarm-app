import 'package:critalarm/core/access/feature_decision.dart';

/// Where the weekly check stands with the plan on this phone. It is
/// `FeatureAccess.decide(AppFeature.weeklyCheck)` in the four words the
/// weekly check acts on, so nothing in this feature reads a plan itself.
enum WeeklyCheckAccess {
  /// Hosted is held and confirmed. The switch is offered.
  open,

  /// Nobody is sure: a Hosted purchase is still being confirmed, or the
  /// plan could not be read. The row stays locked, as the relay would
  /// refuse the check, and nothing else is taken away on this answer.
  unsure,

  /// Hosted is not held. The row is locked and offers Hosted. The relay
  /// sends this phone no check, so a check that does not arrive is not a
  /// missed one.
  locked,

  /// The phone is on a server of the user's own, where the check does not
  /// exist (api.md §4.5). Nothing is offered and nothing is sold.
  notOffered;

  /// Whether the relay is sure to be sending this phone no check because
  /// of the plan or the server, and not because something broke.
  bool get isPlanAway => this == locked || this == notOffered;
}

WeeklyCheckAccess weeklyCheckAccessFor(FeatureDecision decision) =>
    switch (decision) {
      FeatureOpen() => WeeklyCheckAccess.open,
      FeatureConfirming() || FeatureUnread() => WeeklyCheckAccess.unsure,
      FeatureLocked() => WeeklyCheckAccess.locked,
      FeatureNotOffered() => WeeklyCheckAccess.notOffered,
    };
