import 'package:critalarm/core/paywall/paywall_intro.dart';
import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('which layout an id draws', () {
    test('an id with a layout of its own draws that layout', () {
      for (final layout in paywallLayoutBuilders.keys) {
        expect(paywallLayoutDrawnFor(layout), layout);
      }
    });

    test('an id with no layout of its own draws hero', () {
      expect(paywallFallbackLayout, PaywallLayoutId.hero);
      for (final layout in PaywallLayoutId.values) {
        if (paywallLayoutIsBuilt(layout)) continue;
        expect(paywallLayoutDrawnFor(layout), PaywallLayoutId.hero);
      }
    });

    test('hero is registered under its own id', () {
      expect(paywallLayoutIsBuilt(PaywallLayoutId.hero), isTrue);
    });

    test('the layouts that were taken out have no id left', () {
      expect(PaywallLayoutId.fromKey('plain'), isNull);
      expect(PaywallLayoutId.fromKey('false_alarm'), isNull);
    });
  });

  group('the location of a layout', () {
    test('names the intro only when there is one', () {
      expect(
        paywallLayoutLocation(PaywallLayoutId.hero, PaywallProduct.hosted),
        '/plans/hero?product=hosted&source=direct',
      );
      expect(
        paywallLayoutLocation(
          PaywallLayoutId.doors,
          PaywallProduct.pro,
          intro: PaywallIntroId.falseAlarm,
        ),
        '/plans/doors?product=pro&source=direct&intro=false_alarm',
      );
    });
  });
}
