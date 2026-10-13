import 'package:critalarm/features/onboarding/domain/offer/onboarding_offer_config.dart';
import 'package:critalarm/features/onboarding/domain/offer/onboarding_offer_opening.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/setup_use.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/domain/paywall_lead.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter_test/flutter_test.dart';

const _topic = 'payments-db';

OnboardingOfferConfig _config(
  OfferCloudChoice cloud, {
  PaywallProduct? selfHosted = PaywallProduct.pro,
}) => OnboardingOfferConfig(
  enabled: true,
  cloudProduct: cloud,
  selfHostedProduct: selfHosted,
  layoutKey: 'reel',
);

OfferOpening _open(
  OfferCloudChoice cloud,
  SetupUse? use, {
  bool isSelfHosted = false,
  bool holdsPro = false,
  bool holdsHosted = false,
  PaywallProduct? selfHosted = PaywallProduct.pro,
  String? topicName = _topic,
}) => offerOpening(
  config: _config(cloud, selfHosted: selfHosted),
  use: use,
  isSelfHosted: isSelfHosted,
  holdsPro: holdsPro,
  holdsHosted: holdsHosted,
  topicName: topicName,
);

/// The leads the sequence can open on.
const _topics = PaywallLead(
  benefit: PaywallBenefitId.topics,
  headlineKey: LocaleKeys.paywall_lead_servers_headline,
  lineKey: LocaleKeys.paywall_lead_servers_line,
  topicName: _topic,
);
const _homelab = PaywallLead(
  benefit: PaywallBenefitId.reliabilityChecks,
  headlineKey: LocaleKeys.paywall_lead_reaches_headline,
  lineKey: LocaleKeys.weekly_check_what_line,
);
const _jobs = PaywallLead(
  benefit: PaywallBenefitId.reliabilityChecks,
  headlineKey: LocaleKeys.paywall_lead_reaches_headline,
  lineKey: LocaleKeys.paywall_lead_jobs_line,
);
const _widgets = PaywallLead(
  benefit: PaywallBenefitId.widgets,
  headlineKey: LocaleKeys.paywall_lead_home_headline,
  lineKey: LocaleKeys.paywall_kit_benefits_widgets_line,
);

/// One row of the table: what a phone is offered, ignoring what it holds.
typedef _Row = (
  OfferCloudChoice cloud,
  bool isSelfHosted,
  SetupUse use,
  PaywallProduct product,
  PaywallLead? lead,
);

final List<_Row> _table = [
  // Cloud, on auto: the answer picks.
  (
    OfferCloudChoice.auto,
    false,
    SetupUse.servers,
    PaywallProduct.hosted,
    _topics,
  ),
  (
    OfferCloudChoice.auto,
    false,
    SetupUse.homelab,
    PaywallProduct.hosted,
    _homelab,
  ),
  (OfferCloudChoice.auto, false, SetupUse.jobs, PaywallProduct.hosted, _jobs),
  (OfferCloudChoice.auto, false, SetupUse.home, PaywallProduct.pro, _widgets),
  (OfferCloudChoice.auto, false, SetupUse.other, PaywallProduct.hosted, null),
  // Cloud, forced to the Pro pack: it wins for every answer.
  (
    OfferCloudChoice.pro,
    false,
    SetupUse.servers,
    PaywallProduct.pro,
    _widgets,
  ),
  (
    OfferCloudChoice.pro,
    false,
    SetupUse.homelab,
    PaywallProduct.pro,
    _widgets,
  ),
  (OfferCloudChoice.pro, false, SetupUse.jobs, PaywallProduct.pro, _widgets),
  (OfferCloudChoice.pro, false, SetupUse.home, PaywallProduct.pro, _widgets),
  (OfferCloudChoice.pro, false, SetupUse.other, PaywallProduct.pro, null),
  // Cloud, forced to Hosted: it wins, and the lead is Hosted's.
  (
    OfferCloudChoice.hosted,
    false,
    SetupUse.servers,
    PaywallProduct.hosted,
    _topics,
  ),
  (
    OfferCloudChoice.hosted,
    false,
    SetupUse.homelab,
    PaywallProduct.hosted,
    _homelab,
  ),
  (
    OfferCloudChoice.hosted,
    false,
    SetupUse.jobs,
    PaywallProduct.hosted,
    _jobs,
  ),
  (
    OfferCloudChoice.hosted,
    false,
    SetupUse.home,
    PaywallProduct.hosted,
    null,
  ),
  (
    OfferCloudChoice.hosted,
    false,
    SetupUse.other,
    PaywallProduct.hosted,
    null,
  ),
  // An own server: the Pro pack for every answer, whatever Cloud is set to.
  for (final cloud in [
    OfferCloudChoice.auto,
    OfferCloudChoice.pro,
    OfferCloudChoice.hosted,
    OfferCloudChoice.none,
  ])
    for (final use in SetupUse.values)
      (cloud, true, use, PaywallProduct.pro, _widgets),
];

void main() {
  group('what the offer opens with', () {
    for (final (cloud, isSelfHosted, use, product, lead) in _table) {
      final where = isSelfHosted ? 'own server' : 'Cloud';
      test('$where, ${cloud.key}, ${use.wire}: ${product.key}', () {
        final opening = _open(cloud, use, isSelfHosted: isSelfHosted);
        expect(opening.isShown, isTrue);
        expect(opening.product, product);
        expect(opening.lead, lead);
      });
    }

    test('no answer reads as Something else', () {
      for (final cloud in OfferCloudChoice.values) {
        for (final isSelfHosted in [false, true]) {
          expect(
            _open(cloud, null, isSelfHosted: isSelfHosted),
            _open(cloud, SetupUse.other, isSelfHosted: isSelfHosted),
            reason: '${cloud.key} $isSelfHosted',
          );
        }
      }
    });

    test('Something else gives the order the paywall uses, on Cloud', () {
      expect(_open(OfferCloudChoice.auto, SetupUse.other).lead, isNull);
      expect(_open(OfferCloudChoice.pro, SetupUse.other).lead, isNull);
      expect(_open(OfferCloudChoice.hosted, SetupUse.other).lead, isNull);
    });

    test('an own server is never offered Hosted', () {
      for (final cloud in OfferCloudChoice.values) {
        for (final use in [...SetupUse.values, null]) {
          final opening = _open(cloud, use, isSelfHosted: true);
          expect(opening.product, isNot(PaywallProduct.hosted));
        }
      }
    });

    test('a lead never names a benefit the product does not list', () {
      for (final (_, _, _, product, lead) in _table) {
        if (lead == null) continue;
        final belongs = switch (product) {
          PaywallProduct.hosted =>
            lead.benefit == PaywallBenefitId.topics ||
                lead.benefit == PaywallBenefitId.reliabilityChecks,
          PaywallProduct.pro => lead.benefit == PaywallBenefitId.widgets,
        };
        expect(belongs, isTrue, reason: '${product.key} ${lead.benefit.key}');
      }
    });

    test('the topic name goes into the topics lead only', () {
      expect(
        _open(OfferCloudChoice.auto, SetupUse.servers).lead?.topicName,
        _topic,
      );
      expect(
        _open(
          OfferCloudChoice.auto,
          SetupUse.servers,
          topicName: null,
        ).lead?.topicName,
        isNull,
      );
      for (final use in [SetupUse.homelab, SetupUse.jobs, SetupUse.home]) {
        expect(
          _open(OfferCloudChoice.auto, use).lead?.topicName,
          isNull,
          reason: use.wire,
        );
      }
    });
  });

  group('nothing is offered', () {
    test('the Cloud product set to none skips on Cloud only', () {
      for (final use in SetupUse.values) {
        expect(
          _open(OfferCloudChoice.none, use).skipReason,
          OfferSkipReason.noProduct,
        );
        expect(
          _open(OfferCloudChoice.none, use, isSelfHosted: true).isShown,
          isTrue,
        );
      }
    });

    test('the own server product set to none skips on a server only', () {
      for (final cloud in OfferCloudChoice.values) {
        for (final use in SetupUse.values) {
          expect(
            _open(
              cloud,
              use,
              isSelfHosted: true,
              selfHosted: null,
            ).skipReason,
            OfferSkipReason.noProduct,
          );
        }
      }
      expect(
        _open(
          OfferCloudChoice.auto,
          SetupUse.servers,
          selfHosted: null,
        ).isShown,
        isTrue,
      );
    });
  });

  group('what the phone already holds', () {
    for (final (cloud, isSelfHosted, use, product, _) in _table) {
      final where = isSelfHosted ? 'own server' : 'Cloud';
      test('$where, ${cloud.key}, ${use.wire}', () {
        final holdsChosen = _open(
          cloud,
          use,
          isSelfHosted: isSelfHosted,
          holdsPro: product == PaywallProduct.pro,
          holdsHosted: product == PaywallProduct.hosted,
        );
        expect(holdsChosen.skipReason, OfferSkipReason.alreadyHeld);

        // Holding the other product skips nothing, and Hosted is never put
        // in the place of a held Pro pack.
        final holdsOther = _open(
          cloud,
          use,
          isSelfHosted: isSelfHosted,
          holdsPro: product == PaywallProduct.hosted,
          holdsHosted: product == PaywallProduct.pro,
        );
        expect(holdsOther.isShown, isTrue);
        expect(holdsOther.product, product);

        // Both held: nothing to sell.
        final holdsBoth = _open(
          cloud,
          use,
          isSelfHosted: isSelfHosted,
          holdsPro: true,
          holdsHosted: true,
        );
        expect(holdsBoth.skipReason, OfferSkipReason.alreadyHeld);

        // Nothing held: the row.
        expect(
          _open(cloud, use, isSelfHosted: isSelfHosted).product,
          product,
        );
      });
    }
  });
}
