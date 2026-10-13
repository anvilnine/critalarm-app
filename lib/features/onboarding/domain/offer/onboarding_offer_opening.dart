import 'package:critalarm/features/onboarding/domain/offer/onboarding_offer_config.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/setup_use.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/setup_use_profile.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/domain/paywall_lead.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
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

/// What the offer sequence opens with: one product and the lead its first
/// scene takes, or the reason there is nothing to open.
@immutable
class OfferOpening {
  const OfferOpening.show({required PaywallProduct this.product, this.lead})
    : skipReason = null;

  const OfferOpening.skip(OfferSkipReason this.skipReason)
    : product = null,
      lead = null;

  final PaywallProduct? product;

  /// The benefit the reel opens on and its words. Null for the product's
  /// own order.
  final PaywallLead? lead;

  final OfferSkipReason? skipReason;

  bool get isShown => skipReason == null;

  @override
  bool operator ==(Object other) =>
      other is OfferOpening &&
      product == other.product &&
      lead == other.lead &&
      skipReason == other.skipReason;

  @override
  int get hashCode => Object.hash(product, lead, skipReason);

  @override
  String toString() => isShown
      ? 'OfferOpening.show(${product!.key}, '
            '${lead == null ? 'no lead' : lead!.benefit.key})'
      : 'OfferOpening.skip(${skipReason!.name})';
}

/// The product the offer sells to this phone, or null for nothing.
///
/// An own server is only ever sold the Pro pack, or nothing:
/// `self_hosted_product` decides. Hosted is Cloud's plan. On Cloud a forced
/// `pro` or `hosted` wins for every answer, and `auto` follows the answer:
/// the Pro pack for the home answer, Hosted for the rest.
PaywallProduct? offerProductFor({
  required OnboardingOfferConfig config,
  required SetupUse? use,
  required bool isSelfHosted,
}) {
  if (isSelfHosted) return config.selfHostedProduct;
  return switch (config.cloudProduct) {
    OfferCloudChoice.none => null,
    OfferCloudChoice.pro => PaywallProduct.pro,
    OfferCloudChoice.hosted => PaywallProduct.hosted,
    OfferCloudChoice.auto =>
      (use ?? SetupUse.other) == SetupUse.home
          ? PaywallProduct.pro
          : PaywallProduct.hosted,
  };
}

/// The lead of the reel's first scene for [product], by the answer.
///
/// - Hosted: `servers` opens on the critical topics and names
///   [topicName] when it is known. `homelab` and `jobs` open on the
///   weekly delivery check, each with its own line. `home` and `other`
///   have no lead: the reel keeps the order the paywall uses.
/// - Pro: widgets, with the home headline. An answer of `other` on Cloud
///   keeps the paywall's own order. On an own server every answer opens on
///   widgets, since the Pro pack is all it can be sold.
///
/// The lead never names a benefit the product does not list.
PaywallLead? offerLeadFor({
  required PaywallProduct product,
  required SetupUse? use,
  required bool isSelfHosted,
  String? topicName,
}) {
  final answer = use ?? SetupUse.other;
  final lead = SetupUseProfile.of(answer).offerLead;
  switch (product) {
    case PaywallProduct.hosted:
      return switch (lead) {
        OfferLead.topics => PaywallLead(
          benefit: PaywallBenefitId.topics,
          headlineKey: LocaleKeys.paywall_lead_servers_headline,
          lineKey: LocaleKeys.paywall_lead_servers_line,
          topicName: topicName,
        ),
        OfferLead.weeklyCheck => PaywallLead(
          benefit: PaywallBenefitId.reliabilityChecks,
          headlineKey: LocaleKeys.paywall_lead_reaches_headline,
          lineKey: answer == SetupUse.jobs
              ? LocaleKeys.paywall_lead_jobs_line
              : LocaleKeys.weekly_check_what_line,
        ),
        OfferLead.widgets || OfferLead.today => null,
      };
    case PaywallProduct.pro:
      if (answer == SetupUse.other && !isSelfHosted) return null;
      return const PaywallLead(
        benefit: PaywallBenefitId.widgets,
        headlineKey: LocaleKeys.paywall_lead_home_headline,
        lineKey: LocaleKeys.paywall_kit_benefits_widgets_line,
      );
  }
}

/// What the offer sequence opens with for this phone, with nothing to read
/// from: the product the switches and the answer choose and the lead that
/// goes with it, or why there is none.
///
/// A user who holds the chosen product skips. A Cloud user who holds the
/// Pro pack and would be shown it skips; they are not shown Hosted in its
/// place, so a run offers one product.
OfferOpening offerOpening({
  required OnboardingOfferConfig config,
  required SetupUse? use,
  required bool isSelfHosted,
  required bool holdsPro,
  required bool holdsHosted,
  String? topicName,
}) {
  final product = offerProductFor(
    config: config,
    use: use,
    isSelfHosted: isSelfHosted,
  );
  if (product == null) {
    return const OfferOpening.skip(OfferSkipReason.noProduct);
  }
  final isHeld = switch (product) {
    PaywallProduct.pro => holdsPro,
    PaywallProduct.hosted => holdsHosted,
  };
  if (isHeld) return const OfferOpening.skip(OfferSkipReason.alreadyHeld);
  return OfferOpening.show(
    product: product,
    lead: offerLeadFor(
      product: product,
      use: use,
      isSelfHosted: isSelfHosted,
      topicName: topicName,
    ),
  );
}
