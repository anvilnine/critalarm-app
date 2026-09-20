import 'package:critalarm/core/paywall/paywall_variant.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PaywallVariant', () {
    // These four strings are typed into the Firebase Remote Config console
    // under `paywall_variant`, so a rename there has to land here too.
    test('keys match what Remote Config sends', () {
      expect(PaywallVariant.straight.key, equals('straight'));
      expect(PaywallVariant.compare.key, equals('compare'));
      expect(PaywallVariant.oneJob.key, equals('one_job'));
      expect(PaywallVariant.hostedTemplate.key, equals('hosted_template'));
    });

    test('fromKey reads every key back', () {
      for (final variant in PaywallVariant.values) {
        expect(PaywallVariant.fromKey(variant.key), equals(variant));
      }
    });

    // A typo in the console must not leave a device with no paywall.
    test('fromKey falls back on null, empty and nonsense', () {
      expect(PaywallVariant.fromKey(null), equals(PaywallVariant.straight));
      expect(PaywallVariant.fromKey(''), equals(PaywallVariant.straight));
      expect(
        PaywallVariant.fromKey('one-job'),
        equals(PaywallVariant.straight),
      );
      expect(PaywallVariant.fallback, equals(PaywallVariant.straight));
    });
  });

  group('NoPaywallVariantOverride', () {
    // What a store build is compiled with. It has to answer null whatever is
    // done to it, so Remote Config stays in charge.
    test('answers null and keeps no listener', () {
      const override = NoPaywallVariantOverride();

      expect(override.forcedVariant, isNull);
      expect(override.listenable, isNull);

      override.watch(ValueNotifier<PaywallVariant?>(PaywallVariant.compare));

      expect(override.forcedVariant, isNull);
      expect(override.listenable, isNull);
    });
  });

  group('DevPaywallVariantOverride', () {
    test('reports whatever the switch holds', () {
      final devSwitch = ValueNotifier<PaywallVariant?>(null);
      final override = DevPaywallVariantOverride()..watch(devSwitch);

      expect(override.forcedVariant, isNull);

      devSwitch.value = PaywallVariant.oneJob;
      expect(override.forcedVariant, equals(PaywallVariant.oneJob));

      devSwitch.value = null;
      expect(override.forcedVariant, isNull);
    });
  });
}
