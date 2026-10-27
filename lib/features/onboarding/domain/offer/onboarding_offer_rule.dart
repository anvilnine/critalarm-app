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

/// Whether a replay counts as one for the offer step, which then skips.
///
/// A replay shows the step in two cases only:
///
/// - The build uses the made-up buy model ([usesDemoStore]). Nothing in it
///   can charge anyone or unlock anything, so the replay plays the whole
///   offer.
/// - A developer switched the step on in Developer options. That is a
///   deliberate choice made for a build that may have a store, and a store
///   build has no developer value.
///
/// Every other replay skips: a real store must never be one tap from a real
/// purchase inside something that claims to be a look at the screens.
bool offerCountsAsReplay({
  required bool isReplay,
  required OnboardingOfferOrigin origin,
  bool usesDemoStore = false,
}) => isReplay && origin != OnboardingOfferOrigin.developer && !usesDemoStore;

/// Whether the offer ignores what the phone knows about the user: the
/// account and the products held. A replay on the made-up buy model does,
/// since the point of the replay is to see the paywall and the made-up
/// purchase unlocks nothing. Every other run asks the phone.
bool offerIgnoresHoldings({
  required bool isReplay,
  required bool usesDemoStore,
}) => isReplay && usesDemoStore;

/// The rule of the `offer` step, with nothing to read from.
///
/// The step skips itself when the run is a replay, when it is switched off,
/// when nothing is offered on this kind of server, when the layout is not
/// built in this version, when no account id is known, or when the user
/// already holds the product. [use] is the user's answer, null for none:
/// with the Cloud product on `auto` it picks the product, and it picks the
/// benefit the reel opens on.
///
/// [isDemoReplay] is a replay on the made-up buy model (the caller has
/// already turned [isReplay] off for it, see [offerCountsAsReplay]). The
/// account and the products held are not asked: [hasAccountId], [holdsPro]
/// and [holdsHosted] are ignored.
OfferDecision decideOnboardingOffer({
  required OnboardingOfferConfig config,
  required bool isSelfHosted,
  required Set<String> builtLayoutKeys,
  required bool hasAccountId,
  required bool holdsPro,
  required bool holdsHosted,
  required bool isReplay,
  bool isDemoReplay = false,
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
    holdsPro: holdsPro && !isDemoReplay,
    holdsHosted: holdsHosted && !isDemoReplay,
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
  if (!hasAccountId && !isDemoReplay) {
    return const OfferDecision.skip(OfferSkipReason.noAccount);
  }
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

/// What the store has said about the product the offer would sell.
enum OfferSaleAnswer {
  /// The store listed the product and it can be bought.
  onSale,

  /// Nothing to buy, or the store failed: the step will skip.
  notOnSale,

  /// The check has not been started or has not answered yet.
  unknown,
}

/// Whether an offer follows the setup test, as far as the phone can tell at
/// one moment. The "It works" screen and the offer step read the same
/// cached store answer, so they agree whenever it was ready.
enum OfferOutlook {
  /// No offer follows: the step is not to come, or the store has nothing on
  /// sale and the step will skip.
  none,

  /// The step is to come and the store said the product is on sale.
  coming,

  /// The step is to come and the store has not answered. The offer shows
  /// only if the product turns out to be buyable.
  unsure,
}

/// The [OfferOutlook] for a step that is or is not to come ([isStepAhead],
/// see [offerStepIsAhead]) and the store's [sale] answer.
OfferOutlook offerOutlookFor({
  required bool isStepAhead,
  required OfferSaleAnswer sale,
}) {
  if (!isStepAhead) return OfferOutlook.none;
  return switch (sale) {
    OfferSaleAnswer.onSale => OfferOutlook.coming,
    OfferSaleAnswer.notOnSale => OfferOutlook.none,
    OfferSaleAnswer.unknown => OfferOutlook.unsure,
  };
}

/// Whether the offer step would skip for this user right now: one of its
/// local skip reasons holds, or the store already said nothing is on sale.
/// An answer still to come is not a skip.
bool offerWouldSkip({
  required OfferDecision decision,
  required OfferSaleAnswer sale,
}) => !decision.isShown || sale == OfferSaleAnswer.notOnSale;

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
    this.readSale = _noSaleAnswer,
    this.startSale = _noSaleStart,
    this.readUsesDemoStore = _noDemoStore,
  });

  static SetupUse? _noUse({required bool isReplay}) => null;
  static String? _noTopicName() => null;
  static OfferSaleAnswer _noSaleAnswer(PaywallProduct product) =>
      OfferSaleAnswer.unknown;
  static void _noSaleStart(PaywallProduct product) {}
  static bool _noDemoStore() => false;

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

  /// What the store check already started for the product has answered,
  /// read at once and never waited for. Unknown when none was started.
  final OfferSaleAnswer Function(PaywallProduct product) readSale;

  /// Starts the store check for a product and keeps its answer for
  /// [readSale] and for the step. Safe to call more than once.
  final void Function(PaywallProduct product) startSale;

  /// Whether the buy model in this build is the made-up one, which charges
  /// nothing and unlocks nothing. Only a build that skips the store says
  /// true. A replay plays the offer when it does, and skips it when the
  /// store is real (unless a developer switched the step on).
  final bool Function() readUsesDemoStore;

  /// The switches in use right now. A source that throws counts as empty.
  ChosenOnboardingOffer chosen() => chooseOnboardingOffer(
    developerJson: _text(readDeveloperJson),
    remoteJson: _text(readRemoteJson),
  );

  static String? _nameOrNull(String? Function() read) {
    final name = _text(read)?.trim();
    return name == null || name.isEmpty ? null : name;
  }

  static bool _flag(bool Function() read) {
    try {
      return read();
    } on Object {
      return false;
    }
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
      final usesDemoStore = isReplay && _flag(readUsesDemoStore);
      final countsAsReplay = offerCountsAsReplay(
        isReplay: isReplay,
        origin: chosen.origin,
        usesDemoStore: usesDemoStore,
      );
      final isDemoReplay = offerIgnoresHoldings(
        isReplay: isReplay,
        usesDemoStore: usesDemoStore,
      );
      // Asked before anything is read, so a step that is off costs a launch
      // nothing.
      if (countsAsReplay) {
        return const OfferDecision.skip(OfferSkipReason.replay);
      }
      if (!config.enabled) {
        return const OfferDecision.skip(OfferSkipReason.notEnabled);
      }
      // A replay on the made-up store asks neither the account nor the
      // holdings: it plays the offer whatever they say.
      final accountId = isDemoReplay ? null : await readAccountId();
      return decideOnboardingOffer(
        config: config,
        isSelfHosted: isOwnServerMode(await readServerMode()),
        builtLayoutKeys: builtLayoutKeys(),
        hasAccountId: accountId != null && accountId.isNotEmpty,
        holdsPro: !isDemoReplay && holdsPro(),
        holdsHosted: !isDemoReplay && await readHoldsHosted(),
        isReplay: countsAsReplay,
        isDemoReplay: isDemoReplay,
        use: readUse(isReplay: isReplay),
        topicName: _nameOrNull(readTopicName),
      );
    } on Object {
      // What the phone knows about the account could not be read.
      return const OfferDecision.skip(OfferSkipReason.noAccount);
    }
  }

  /// Whether the offer step is still to come in this run, and not known to
  /// skip. False when it cannot be worked out. An answer from the store that
  /// is still to come counts as ahead, so nothing else asks the user to buy
  /// while the offer may show.
  Future<bool> isAhead() async => (await outlook()) != OfferOutlook.none;

  /// What follows the setup test, from local reads and the cached store
  /// answer. It never waits for the store. `none` when it cannot be worked
  /// out.
  Future<OfferOutlook> outlook() async {
    try {
      final decision = await decide(isReplay: false);
      final isStepAhead = offerStepIsAhead(
        isSetupComplete: await isSetupComplete(),
        flowSteps: readFlowSteps(),
        completedSteps: readCompletedSteps(),
        decision: decision,
      );
      final product = decision.product;
      return offerOutlookFor(
        isStepAhead: isStepAhead,
        sale: product == null ? OfferSaleAnswer.unknown : readSale(product),
      );
    } on Object {
      return OfferOutlook.none;
    }
  }

  /// Starts the store check for the product this user would be offered, so
  /// its answer is cached before the setup test ends. Does nothing when the
  /// step is not to come. It reads the store the paywall reads and no other
  /// server.
  Future<void> startSaleCheck() async {
    try {
      final decision = await decide(isReplay: false);
      final product = decision.product;
      if (product == null) return;
      final isStepAhead = offerStepIsAhead(
        isSetupComplete: await isSetupComplete(),
        flowSteps: readFlowSteps(),
        completedSteps: readCompletedSteps(),
        decision: decision,
      );
      if (isStepAhead) startSale(product);
    } on Object {
      // A check that cannot start is a check with no answer.
    }
  }

  /// Whether the offer step would show nothing to this user right now, local
  /// reasons and the cached store answer both counted. A step that skips
  /// counts as already done.
  Future<bool> hasNoOffer() async {
    final decision = await decide(isReplay: false);
    final product = decision.product;
    return offerWouldSkip(
      decision: decision,
      sale: product == null ? OfferSaleAnswer.unknown : readSale(product),
    );
  }
}
