import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/domain/paywall_lead.dart';
import 'package:critalarm/features/paywall/domain/paywall_lead_facts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PaywallLeadFacts', () {
    test('round trips through the query', () {
      const facts = PaywallLeadFacts(
        used: 2,
        limit: 2,
        topicName: 'billing-api',
      );
      expect(facts.toQuery(), {
        'used': '2',
        'limit': '2',
        'topic': 'billing-api',
      });
      final back = PaywallLeadFacts.fromQuery(facts.toQuery());
      expect(back.used, 2);
      expect(back.limit, 2);
      expect(back.topicName, 'billing-api');
    });

    test('leaves out what is null', () {
      expect(const PaywallLeadFacts(used: 1).toQuery(), {'used': '1'});
      expect(const PaywallLeadFacts().toQuery(), isEmpty);
      expect(const PaywallLeadFacts().isEmpty, isTrue);
    });

    test('drops junk counts', () {
      for (final junk in ['-3', 'abc', '', '1000', '2.5', ' 2']) {
        final facts = PaywallLeadFacts.fromQuery({'used': junk, 'limit': junk});
        expect(facts.used, isNull, reason: '"$junk"');
        expect(facts.limit, isNull, reason: '"$junk"');
      }
    });

    test('keeps the edges of the range', () {
      final facts = PaywallLeadFacts.fromQuery(const {
        'used': '0',
        'limit': '999',
      });
      expect(facts.used, 0);
      expect(facts.limit, 999);
    });

    test('drops a topic name that is empty, long or odd', () {
      final long = 'a' * 65;
      for (final junk in [
        '',
        '   ',
        long,
        'has space',
        'a/b',
        'Ünï',
        '<b>',
        'billing\u{1F514}',
      ]) {
        expect(
          PaywallLeadFacts.fromQuery({'topic': junk}).topicName,
          isNull,
          reason: '"$junk"',
        );
      }
      expect(
        PaywallLeadFacts.fromQuery({'topic': 'a' * 64}).topicName,
        'a' * 64,
      );
      expect(
        PaywallLeadFacts.fromQuery(const {'topic': ' Billing_API '}).topicName,
        'billing_api',
      );
    });

    test('the names the screen may hand over, at every length', () {
      for (final length in [3, 12, 16, 17, 40, 64]) {
        final name = 'a' * length;
        expect(
          PaywallLeadFacts(topicName: name).toQuery(),
          {'topic': name},
          reason: '$length characters',
        );
      }
    });

    test('writing never lets a bad value into the location', () {
      expect(
        const PaywallLeadFacts(
          used: -1,
          limit: 1000,
          topicName: 'has space',
        ).toQuery(),
        isEmpty,
      );
      expect(PaywallLeadFacts(topicName: 'a' * 65).toQuery(), isEmpty);
      expect(
        const PaywallLeadFacts(topicName: ' Billing ').toQuery(),
        {'topic': 'billing'},
      );
    });
  });

  group('paywallLeadFromQuery with facts', () {
    test('a topics lead carries the facts', () {
      final lead = paywallLeadFromQuery({
        'lead': 'topics',
        'used': '2',
        'limit': '2',
        'topic': 'billing-api',
      });
      expect(lead?.benefit, PaywallBenefitId.topics);
      expect(lead?.usedCount, 2);
      expect(lead?.limitCount, 2);
      expect(lead?.topicName, 'billing-api');
    });

    test('another lead ignores them', () {
      final lead = paywallLeadFromQuery({
        'lead': 'history',
        'used': '2',
        'limit': '2',
        'topic': 'billing-api',
      });
      expect(lead, const PaywallLead(benefit: PaywallBenefitId.history));
    });

    test('junk facts leave the plain lead', () {
      final lead = paywallLeadFromQuery({
        'lead': 'topics',
        'used': 'x',
        'limit': '-1',
        'topic': 'a b',
      });
      expect(lead, const PaywallLead(benefit: PaywallBenefitId.topics));
    });

    test('a count with no name, and a name with no count, both stay', () {
      expect(
        paywallLeadFromQuery({
          'lead': 'topics',
          'used': '1',
          'limit': '2',
        })?.topicName,
        isNull,
      );
      expect(
        paywallLeadFromQuery({'lead': 'topics', 'topic': 'a'})?.usedCount,
        isNull,
      );
    });
  });
}
