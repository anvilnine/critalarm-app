import 'package:critalarm/core/paywall/paywall_headline.dart';
import 'package:critalarm/core/paywall/paywall_intro.dart';
import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/domain/paywall_lead.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PaywallBenefitId.fromKey', () {
    test('reads every key it writes', () {
      for (final id in PaywallBenefitId.values) {
        expect(PaywallBenefitId.fromKey(id.key), id);
      }
    });

    test('a missing or unknown key is null', () {
      for (final junk in [null, '', 'banana', 'Topics', ' topics']) {
        expect(PaywallBenefitId.fromKey(junk), isNull, reason: '$junk');
      }
    });
  });

  group('paywallLeadFromQuery', () {
    test('a known lead becomes a lead for that benefit', () {
      final lead = paywallLeadFromQuery({'lead': 'history'});
      expect(lead, const PaywallLead(benefit: PaywallBenefitId.history));
    });

    test('no lead and junk give null, so the paywall still opens', () {
      expect(paywallLeadFromQuery(const {}), isNull);
      expect(paywallLeadFromQuery({'lead': 'banana'}), isNull);
      expect(paywallLeadFromQuery({'lead': ''}), isNull);
    });
  });

  group('paywallLayoutLocation', () {
    test('without a lead or a headline the location is as before', () {
      expect(
        paywallLayoutLocation(PaywallLayoutId.sheet, PaywallProduct.hosted),
        '/plans/sheet?product=hosted&source=direct',
      );
    });

    test('carries the lead and the headline after the intro and thanks', () {
      expect(
        paywallLayoutLocation(
          PaywallLayoutId.wipe,
          PaywallProduct.hosted,
          intro: PaywallIntroId.falseAlarm,
          lead: PaywallBenefitId.history,
          headline: PaywallHeadlineVariant.ended,
        ),
        '/plans/wipe?product=hosted&source=direct&intro=false_alarm'
        '&lead=history&headline=ended',
      );
    });

    test('a headline of none is left out', () {
      expect(
        paywallLayoutLocation(
          PaywallLayoutId.proof,
          PaywallProduct.pro,
          lead: PaywallBenefitId.widgets,
        ),
        '/plans/proof?product=pro&source=direct&lead=widgets',
      );
    });
  });

  group('paywallRouteCutsIn', () {
    test('an intro that plays cuts in with no slide', () {
      expect(
        paywallRouteCutsIn(PaywallIntroId.falseAlarm, isBuilt: true),
        isTrue,
      );
    });

    test('no intro, or an intro this build cannot play, slides as before', () {
      expect(paywallRouteCutsIn(PaywallIntroId.none, isBuilt: true), isFalse);
      expect(
        paywallRouteCutsIn(PaywallIntroId.falseAlarm, isBuilt: false),
        isFalse,
      );
    });
  });
}
