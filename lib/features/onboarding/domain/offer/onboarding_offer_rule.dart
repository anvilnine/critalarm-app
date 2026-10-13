import 'package:critalarm/core/access/own_server.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/offer/onboarding_offer_config.dart';
import 'package:critalarm/features/onboarding/domain/offer/onboarding_offer_opening.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/setup_use.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/domain/paywall_lead.dart';
import 'package:flutter/foundation.dart';

export 'package:critalarm/features/onboarding/domain/offer/onboarding_offer_opening.dart'
    show OfferSkipReason;

/// What the `offer` step does: show one product in one layout, or skip.
@immutable
class OfferDecision {
  const OfferDecision.show({
    required PaywallProduct this.product,
    required String this.layoutKey,
    this.lead,
  }) : skipReason = null;

  const OfferDecision.skip(OfferSkipReason this.skipReason)
    : product = null,
      layoutKey = null,
      lead = null;

  final PaywallProduct? product;
  final String? layoutKey;

  /// The benefit the reel opens on, by the user's answer. Null for the
  /// product's own order.
  final PaywallLead? lead;
  final OfferSkipReason? skipReason;

  bool get isShown => skipReason == null;

  @override
  bool operator ==(Object other) =>
      other is OfferDecision &&
      product == other.product &&
      layoutKey == other.layoutKey &&
      lead == other.lead &&
      skipReason == other.skipReason;

  @override
  int get hashCode => Object.hash(product, layoutKey, lead, skipReason);

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
/// already holds the product. [use] is the user's answer, null for none:
/// with the Cloud product on `auto` it picks the product, and it picks the
/// benefit the reel opens on.
OfferDecision decideOnboardingOffer({
  required OnboardingOfferConfig config,
  required bool isSelfHosted,
  required Set<String> builtLayoutKeys,
  required bool hasAccountId,
  required bool holdsPro,
  required bool holdsHosted,
  required bool isReplay,
  SetupUse? use,
  String? topicName,
}) {
  if (isReplay) return const OfferDecision.skip(OfferSkipReason.replay);
  if (!config.enabled) {
    return const OfferDecision.skip(OfferSkipReason.notEnabled);
  }
  final opening = offerOpening(
    config: config,
    use: use,
    isSelfHosted: isSelfHosted,
    holdsPro: holdsPro,
    holdsHosted: holdsHosted,
    topicName: topicName,
  );
  // The reasons are told in this order: what is offered, whether the
  // layout is built, whether there is an account, whether it is held.
  if (opening.skipReason == OfferSkipReason.noProduct) {
    return OfferDecision.skip(opening.skipReason!);
  }
  if (!builtLayoutKeys.contains(config.layoutKey)) {
    return const OfferDecision.skip(OfferSkipReason.unknownLayout);
  }
  if (!hasAccountId) return const OfferDecision.skip(OfferSkipReason.noAccount);
  if (!opening.isShown) return OfferDecision.skip(opening.skipReason!);
  return OfferDecision.show(
    product: opening.product!,
    layoutKey: config.layoutKey,
    lead: opening.lead,
  );
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
    this.readUse = _noUse,
    this.readTopicName = _noTopicName,
    this.markFalseAlarmShown = _noMark,
  });

  static SetupUse? _noUse({required bool isReplay}) => null;
  static String? _noTopicName() => null;
  static Future<void> _noMark() async {}

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

  /// The user's answer on the `use` step, or null for none. A replay reads
  /// the replay's own pick.
  final SetupUse? Function({required bool isReplay}) readUse;

  /// The name of the topic setup made, or null when it is not known.
  final String? Function() readTopicName;

  /// Writes down that the false alarm was shown on this install, so the
  /// Settings plan row does not play it again.
  final Future<void> Function() markFalseAlarmShown;

  /// The switches in use right now. A source that throws counts as empty.
  ChosenOnboardingOffer chosen() => chooseOnboardingOffer(
    developerJson: _text(readDeveloperJson),
    remoteJson: _text(readRemoteJson),
  );

  static String? _nameOrNull(String? Function() read) {
    final name = _text(read)?.trim();
    return name == null || name.isEmpty ? null : name;
  }

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
        isSelfHosted: isOwnServerMode(await readServerMode()),
        builtLayoutKeys: builtLayoutKeys(),
        hasAccountId: accountId != null && accountId.isNotEmpty,
        holdsPro: holdsPro(),
        holdsHosted: await readHoldsHosted(),
        isReplay: countsAsReplay,
        use: readUse(isReplay: isReplay),
        topicName: _nameOrNull(readTopicName),
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
