import 'package:critalarm/core/paywall/paywall_layout.dart';
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

    test('hero and plain are both registered under their own ids', () {
      expect(paywallLayoutIsBuilt(PaywallLayoutId.hero), isTrue);
      expect(paywallLayoutIsBuilt(PaywallLayoutId.plain), isTrue);
      expect(
        paywallLayoutDrawnFor(PaywallLayoutId.plain),
        PaywallLayoutId.plain,
      );
    });
  });
}
