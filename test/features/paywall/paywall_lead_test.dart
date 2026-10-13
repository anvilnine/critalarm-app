import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/domain/paywall_lead.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_scope.dart';
import 'package:flutter_test/flutter_test.dart';

List<PaywallBenefitId> _ids(PaywallOffer offer) => [
  for (final b in offer.benefits) b.id,
];

List<PaywallBenefitId> _listed(PaywallProduct product) => [
  for (final b in paywallBenefitsFor(product)) b.id,
];

const _weekly = PaywallLead(benefit: PaywallBenefitId.reliabilityChecks);
const _topics = PaywallLead(
  benefit: PaywallBenefitId.topics,
  headlineKey: 'paywall_lead.servers_headline',
  lineKey: 'paywall_lead.servers_line',
  topicName: 'payments-db',
);

void main() {
  group('PaywallOffer with a lead', () {
    test('no lead changes nothing', () {
      for (final product in PaywallProduct.values) {
        final offer = PaywallOffer.from(product: product);
        expect(_ids(offer), _listed(product));
        expect(offer.lead, isNull);
      }
    });

    test('the lead is first and the rest keep their order', () {
      final offer = PaywallOffer.from(
        product: PaywallProduct.hosted,
        lead: _weekly,
      );
      expect(_ids(offer), [
        PaywallBenefitId.reliabilityChecks,
        PaywallBenefitId.topics,
        PaywallBenefitId.pushes,
        PaywallBenefitId.history,
        PaywallBenefitId.appIcons,
      ]);
      expect(offer.lead, _weekly);
      expect(offer.isHosted, isTrue);
    });

    test('a lead in the middle moves up and nothing else moves', () {
      final offer = PaywallOffer.from(
        product: PaywallProduct.hosted,
        lead: const PaywallLead(benefit: PaywallBenefitId.history),
      );
      expect(_ids(offer), [
        PaywallBenefitId.history,
        PaywallBenefitId.topics,
        PaywallBenefitId.pushes,
        PaywallBenefitId.appIcons,
        PaywallBenefitId.reliabilityChecks,
      ]);
    });

    test('a lead on the benefit that is already first keeps the order', () {
      final offer = PaywallOffer.from(
        product: PaywallProduct.hosted,
        lead: _topics,
      );
      expect(_ids(offer), _listed(PaywallProduct.hosted));
      expect(offer.lead, _topics);
    });

    test('a lead for a benefit the product does not list is ignored', () {
      // Widgets are Pro's.
      final offer = PaywallOffer.from(
        product: PaywallProduct.hosted,
        lead: const PaywallLead(benefit: PaywallBenefitId.widgets),
      );
      expect(_ids(offer), _listed(PaywallProduct.hosted));
      expect(offer.lead, isNull);
    });

    test('a benefit that is not in this build is not listed, so a lead for '
        'it is ignored', () {
      final offer = PaywallOffer.from(
        product: PaywallProduct.pro,
        lead: const PaywallLead(benefit: PaywallBenefitId.wakeUpChallenges),
      );
      expect(_ids(offer), _listed(PaywallProduct.pro));
      expect(offer.lead, isNull);
    });

    test('Pro with a Hosted lead is ignored', () {
      for (final lead in [_topics, _weekly]) {
        final offer = PaywallOffer.from(
          product: PaywallProduct.pro,
          lead: lead,
        );
        expect(_ids(offer), _listed(PaywallProduct.pro));
        expect(offer.lead, isNull);
      }
    });

    test('Pro with its own lead lists it first', () {
      final offer = PaywallOffer.from(
        product: PaywallProduct.pro,
        lead: const PaywallLead(benefit: PaywallBenefitId.customSounds),
      );
      expect(_ids(offer), [
        PaywallBenefitId.customSounds,
        PaywallBenefitId.widgets,
        PaywallBenefitId.customAlarmScreens,
      ]);
    });

    test('the developer view that lists every benefit also puts the lead '
        'first', () {
      final offer = PaywallOffer.from(
        product: PaywallProduct.pro,
        showsUnbuilt: true,
        lead: const PaywallLead(benefit: PaywallBenefitId.customAlarmScreens),
      );
      expect(offer.benefits.first.id, PaywallBenefitId.customAlarmScreens);
      expect(offer.benefits, hasLength(4));
    });

    test('the source is carried and the lead leaves the list a copy', () {
      final listed = paywallBenefitsFor(PaywallProduct.hosted);
      final offer = PaywallOffer.from(
        product: PaywallProduct.hosted,
        source: PaywallSource.history,
        lead: _weekly,
      );
      expect(offer.source, PaywallSource.history);
      // The list the product keeps is not reordered.
      expect(listed.first.id, PaywallBenefitId.topics);
    });
  });

  group('PaywallLead', () {
    test('is equal to one with the same parts, so a rebuild with the same '
        'lead tells nobody', () {
      expect(
        _topics,
        const PaywallLead(
          benefit: PaywallBenefitId.topics,
          headlineKey: 'paywall_lead.servers_headline',
          lineKey: 'paywall_lead.servers_line',
          topicName: 'payments-db',
        ),
      );
      expect(
        _topics.hashCode,
        const PaywallLead(
          benefit: PaywallBenefitId.topics,
          headlineKey: 'paywall_lead.servers_headline',
          lineKey: 'paywall_lead.servers_line',
          topicName: 'payments-db',
        ).hashCode,
      );
      expect(
        _topics,
        isNot(const PaywallLead(benefit: PaywallBenefitId.topics)),
      );
      expect(
        const PaywallLead(benefit: PaywallBenefitId.topics, topicName: 'a'),
        isNot(
          const PaywallLead(benefit: PaywallBenefitId.topics, topicName: 'b'),
        ),
      );
    });

    test('a lead is found in a list only when its benefit is there', () {
      final hosted = paywallBenefitsFor(PaywallProduct.hosted);
      expect(paywallLeadIn(hosted, _weekly), _weekly);
      expect(paywallLeadIn(hosted, null), isNull);
      expect(
        paywallLeadIn(
          hosted,
          const PaywallLead(benefit: PaywallBenefitId.widgets),
        ),
        isNull,
      );
      expect(paywallLeadIn(const [], _weekly), isNull);
      expect(paywallBenefitsLeadFirst(const [], _weekly), isEmpty);
    });
  });
}
