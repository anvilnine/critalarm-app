import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/offer/onboarding_offer_config.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:flutter/foundation.dart';

/// Why the `offer` step shows nothing and moves on.
enum OfferSkipReason {
  /// The run is a replay, a look at the screens.
  replay,

  /// The step is switched off.
  notEnabled,

  /// Nothing is offered on this kind of server.
  noProduct,

  /// The layout named is not built in this version.
  unknownLayout,

  /// This phone has no account yet, so there is nobody to sell to.
  noAccount,

  /// The user already holds what would be offered.
  alreadyHeld,
}

/// What the `offer` step does: show one product in one layout, or skip.
@immutable
class OfferDecision {
  const OfferDecision.show({
    required PaywallProduct this.product,
    required String this.layoutKey,
  }) : skipReason = null;

  const OfferDecision.skip(OfferSkipReason this.skipReason)
    : product = null,
      layoutKey = null;

  final PaywallProduct? product;
  final String? layoutKey;
  final OfferSkipReason? skipReason;

  bool get isShown => skipReason == null;

  @override
  bool operator ==(Object other) =>
      other is OfferDecision &&
      product == other.product &&
      layoutKey == other.layoutKey &&
      skipReason == other.skipReason;

  @override
  int get hashCode => Object.hash(product, layoutKey, skipReason);

  @override
  String toString() => isShown
      ? 'OfferDecision.show(${product!.key}, $layoutKey)'
      : 'OfferDecision.skip(${skipReason!.name})';
}

/// Whether a replay counts as one for the offer step. A replay skips the
/// step. The one exception is a developer who switched the step on in
/// Developer options: that is the only way to look at it, and a store build
/// has no developer value.
bool offerCountsAsReplay({
  required bool isReplay,
  required OnboardingOfferOrigin origin,
}) => isReplay && origin != OnboardingOfferOrigin.developer;

/// The rule of the `offer` step, with nothing to read from.
///
/// The step skips itself when the run is a replay, when it is switched off,
/// when nothing is offered on this kind of server, when the layout is not
/// built in this version, when no account id is known, or when the user
/// already holds the product.
OfferDecision decideOnboardingOffer({
  required OnboardingOfferConfig config,
  required bool isSelfHosted,
  required Set<String> builtLayoutKeys,
  required bool hasAccountId,
  required bool holdsPro,
  required bool holdsHosted,
  required bool isReplay,
}) {
  if (isReplay) return const OfferDecision.skip(OfferSkipReason.replay);
  if (!config.enabled) {
    return const OfferDecision.skip(OfferSkipReason.notEnabled);
  }
  final product = isSelfHosted ? config.selfHostedProduct : config.cloudProduct;
  if (product == null) {
    return const OfferDecision.skip(OfferSkipReason.noProduct);
  }
  if (!builtLayoutKeys.contains(config.layoutKey)) {
    return const OfferDecision.skip(OfferSkipReason.unknownLayout);
  }
  if (!hasAccountId) return const OfferDecision.skip(OfferSkipReason.noAccount);
  final isHeld = switch (product) {
    PaywallProduct.pro => holdsPro,
    PaywallProduct.hosted => holdsHosted,
  };
  if (isHeld) return const OfferDecision.skip(OfferSkipReason.alreadyHeld);
  return OfferDecision.show(product: product, layoutKey: config.layoutKey);
}

/// Whether the offer step is still to come in this setup run: setup is not
/// complete, the flow lists the step, it is not finished, and it would show
/// something. While this holds, nothing else asks the user to buy.
bool offerStepIsAhead({
  required bool isSetupComplete,
  required List<String> flowSteps,
  required Set<String> completedSteps,
  required OfferDecision decision,
}) =>
    !isSetupComplete &&
    flowSteps.contains(OnboardingStepId.offer) &&
    !completedSteps.contains(OnboardingStepId.offer) &&
    decision.isShown;

/// Reads what [decideOnboardingOffer] needs from the phone and answers.
///
/// Everything it is given is a local read. A read that fails ends in a
/// skip, never in an error: the offer is the one step setup can always do
/// without.
class OnboardingOfferGate {
  const OnboardingOfferGate({
    required this.readDeveloperJson,
    required this.readRemoteJson,
    required this.readServerMode,
    required this.builtLayoutKeys,
    required this.readAccountId,
    required this.holdsPro,
    required this.readHoldsHosted,
    required this.isSetupComplete,
    required this.readFlowSteps,
    required this.readCompletedSteps,
  });

  /// The value a developer set, or null. Always null in a store build.
  final String? Function() readDeveloperJson;

  /// The remote value already on the phone. Never waits for the network.
  final String? Function() readRemoteJson;

  final Future<ServerMode?> Function() readServerMode;

  /// The keys of the layouts this build can draw.
  final Set<String> Function() builtLayoutKeys;

  final Future<String?> Function() readAccountId;

  /// Whether this install holds the Pro pack.
  final bool Function() holdsPro;

  /// Whether this account is on the Hosted plan.
  final Future<bool> Function() readHoldsHosted;

  final Future<bool> Function() isSetupComplete;

  /// The steps of the flow the user is in.
  final List<String> Function() readFlowSteps;
  final Set<String> Function() readCompletedSteps;

  /// The switches in use right now. A source that throws counts as empty.
  ChosenOnboardingOffer chosen() => chooseOnboardingOffer(
    developerJson: _text(readDeveloperJson),
    remoteJson: _text(readRemoteJson),
  );

  static String? _text(String? Function() read) {
    try {
      return read();
    } on Object {
      return null;
    }
  }

  /// What the step does for this user right now.
  Future<OfferDecision> decide({required bool isReplay}) async {
    try {
      final chosen = this.chosen();
      final config = chosen.config;
      final countsAsReplay = offerCountsAsReplay(
        isReplay: isReplay,
        origin: chosen.origin,
      );
      // Asked before anything is read, so a step that is off costs a launch
      // nothing.
      if (countsAsReplay) {
        return const OfferDecision.skip(OfferSkipReason.replay);
      }
      if (!config.enabled) {
        return const OfferDecision.skip(OfferSkipReason.notEnabled);
      }
      final accountId = await readAccountId();
      return decideOnboardingOffer(
        config: config,
        isSelfHosted: await readServerMode() == ServerMode.selfhosted,
        builtLayoutKeys: builtLayoutKeys(),
        hasAccountId: accountId != null && accountId.isNotEmpty,
        holdsPro: holdsPro(),
        holdsHosted: await readHoldsHosted(),
        isReplay: countsAsReplay,
      );
    } on Object {
      // What the phone knows about the account could not be read.
      return const OfferDecision.skip(OfferSkipReason.noAccount);
    }
  }

  /// Whether the offer step is still to come in this run. False when it
  /// cannot be worked out.
  Future<bool> isAhead() async {
    try {
      return offerStepIsAhead(
        isSetupComplete: await isSetupComplete(),
        flowSteps: readFlowSteps(),
        completedSteps: readCompletedSteps(),
        decision: await decide(isReplay: false),
      );
    } on Object {
      return false;
    }
  }
}
