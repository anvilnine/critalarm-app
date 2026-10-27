import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:flutter/foundation.dart';

/// What a tap on a locked surface means.
///
/// A tag never makes a tap open a paywall. The surface says what the tap
/// is, and [lockTapFor] says what happens.
enum LockTapKind {
  /// Go to the page or sheet this surface leads to.
  open,

  /// Tap an option to see it working.
  tryIt,

  /// The person acts to use or keep it: "Use this look", pick as default,
  /// turn on, set.
  keep,

  /// A button that says "See Pro" or "See Hosted".
  seePlan,
}

/// What a surface does for one tap. See [lockTapFor].
@immutable
sealed class LockTapAnswer {
  const LockTapAnswer();
}

/// Go to the page or sheet the surface leads to.
final class OpenPage extends LockTapAnswer {
  const OpenPage();

  @override
  bool operator ==(Object other) => other is OpenPage;

  @override
  int get hashCode => (OpenPage).hashCode;

  @override
  String toString() => 'LockTapAnswer.openPage';
}

/// Show the option working, saving nothing.
final class TryIt extends LockTapAnswer {
  const TryIt();

  @override
  bool operator ==(Object other) => other is TryIt;

  @override
  int get hashCode => (TryIt).hashCode;

  @override
  String toString() => 'LockTapAnswer.tryIt';
}

/// Open the paywall that sells [offer].
final class OpenPaywall extends LockTapAnswer {
  const OpenPaywall(this.offer);

  /// `FeatureLocked.offer`, so a caller never names a product.
  final Holding offer;

  @override
  bool operator ==(Object other) =>
      other is OpenPaywall && other.offer == offer;

  @override
  int get hashCode => Object.hash(OpenPaywall, offer);

  @override
  String toString() => 'LockTapAnswer.openPaywall(${offer.name})';
}

/// Nothing is locked: do what the tap is for.
final class DoIt extends LockTapAnswer {
  const DoIt();

  @override
  bool operator ==(Object other) => other is DoIt;

  @override
  int get hashCode => (DoIt).hashCode;

  @override
  String toString() => 'LockTapAnswer.doIt';
}

/// The plan has not been read yet. The caller awaits
/// `FeatureAccess.ready` and asks again.
final class WaitForPlan extends LockTapAnswer {
  const WaitForPlan();

  @override
  bool operator ==(Object other) => other is WaitForPlan;

  @override
  int get hashCode => (WaitForPlan).hashCode;

  @override
  String toString() => 'LockTapAnswer.waitForPlan';
}

/// The tap does nothing here.
final class Nothing extends LockTapAnswer {
  const Nothing();

  @override
  bool operator ==(Object other) => other is Nothing;

  @override
  int get hashCode => (Nothing).hashCode;

  @override
  String toString() => 'LockTapAnswer.nothing';
}

/// What a tap on a locked surface does. Every locked surface asks here.
///
/// [decision] is `FeatureAccess.decide` for the feature, [isPlanRead] is
/// `FeatureAccess.isPlanRead`, [hasTry] says whether a try exists for the
/// option, and [tap] is what the surface's tap is for.
///
/// The first row that matches wins:
///
/// 1. [LockTapKind.open]: [OpenPage], whatever the decision.
/// 2. Not offered: [Nothing]. Never a paywall, never a try.
/// 3. The plan is not read: [WaitForPlan]. Nothing is sold, tried or saved
///    on a guess.
/// 4. Open, confirming or unread, with [LockTapKind.tryIt] or
///    [LockTapKind.keep]: [DoIt].
/// 5. The same decisions with [LockTapKind.seePlan]: [Nothing]. There is
///    nothing to sell.
/// 6. Locked, [LockTapKind.tryIt] and [hasTry]: [TryIt].
/// 7. Locked, [LockTapKind.tryIt] and no try: [OpenPaywall]. With no try,
///    the tap is the person reaching for the thing.
/// 8. Locked, [LockTapKind.keep] or [LockTapKind.seePlan]: [OpenPaywall].
LockTapAnswer lockTapFor({
  required FeatureDecision decision,
  required bool isPlanRead,
  required bool hasTry,
  required LockTapKind tap,
}) {
  if (tap == LockTapKind.open) return const OpenPage();
  if (decision is FeatureNotOffered) return const Nothing();
  if (!isPlanRead) return const WaitForPlan();
  if (decision is! FeatureLocked) {
    return tap == LockTapKind.seePlan ? const Nothing() : const DoIt();
  }
  return switch (tap) {
    LockTapKind.tryIt when hasTry => const TryIt(),
    LockTapKind.tryIt ||
    LockTapKind.keep ||
    LockTapKind.seePlan => OpenPaywall(decision.offer),
    LockTapKind.open => const OpenPage(),
  };
}
