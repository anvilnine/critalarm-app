import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/presentation/layouts/sheet/sheet_lead_benefit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final hosted = paywallBenefitsFor(PaywallProduct.hosted);
  final pro = paywallBenefitsFor(PaywallProduct.pro);

  group('sheetLeadBenefit', () {
    test('a topic limit leads with topics', () {
      expect(
        sheetLeadBenefit(PaywallSource.createTopicCard, hosted)?.id,
        PaywallBenefitId.topics,
      );
    });

    test('history leads with history, from either entry point', () {
      for (final source in [
        PaywallSource.history,
        PaywallSource.historyOlder,
      ]) {
        expect(
          sheetLeadBenefit(source, hosted)?.id,
          PaywallBenefitId.history,
          reason: source.wire,
        );
      }
    });

    test('a widget leads with widgets, from either entry point', () {
      for (final source in [
        PaywallSource.widgetLocked,
        PaywallSource.homeWidgets,
      ]) {
        expect(
          sheetLeadBenefit(source, hosted)?.id,
          PaywallBenefitId.widgets,
          reason: source.wire,
        );
      }
    });

    test('a place that names no benefit leads with the first one', () {
      for (final source in [
        PaywallSource.direct,
        PaywallSource.settingsPlan,
        PaywallSource.askSheet,
        PaywallSource.reminderProLater,
      ]) {
        expect(
          sheetLeadBenefit(source, hosted)?.id,
          hosted.first.id,
          reason: source.wire,
        );
      }
    });

    test('a benefit the product does not list falls back to the first', () {
      // Pro has no topics benefit, so a topic limit cannot lead it.
      expect(
        sheetLeadBenefit(PaywallSource.createTopicCard, pro)?.id,
        pro.first.id,
      );
    });

    test('every source gives a lead for both products', () {
      for (final source in PaywallSource.values) {
        expect(sheetLeadBenefit(source, hosted), isNotNull);
        expect(sheetLeadBenefit(source, pro), isNotNull);
      }
    });

    test('no benefits, no lead', () {
      expect(sheetLeadBenefit(PaywallSource.direct, const []), isNull);
    });
  });

  group('sheetOtherBenefits', () {
    test('is every benefit but the lead, in the same order', () {
      final lead = sheetLeadBenefit(PaywallSource.history, hosted);
      final others = sheetOtherBenefits(lead, hosted);

      expect(others.length, hosted.length - 1);
      expect(others.map((b) => b.id), isNot(contains(lead!.id)));
      expect(
        others.map((b) => b.id).toList(),
        [
          for (final b in hosted)
            if (b.id != lead.id) b.id,
        ],
      );
    });

    test('one benefit leaves nothing under the lead', () {
      final one = [hosted.first];
      expect(sheetOtherBenefits(one.first, one), isEmpty);
    });
  });
}
