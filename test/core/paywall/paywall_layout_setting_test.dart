import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:critalarm/core/paywall/paywall_layout_setting.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('the remote value', () {
    test('empty and missing mean the shipped paywall', () {
      expect(PaywallLayoutSetting.parse(null), PaywallLayoutSetting.shipped);
      expect(PaywallLayoutSetting.parse(''), PaywallLayoutSetting.shipped);
      expect(PaywallLayoutSetting.parse('  '), PaywallLayoutSetting.shipped);
    });

    test('a value this build does not know counts as empty', () {
      for (final typo in ['heroo', 'Hero', 'AUTO', 'shipped', 'none', '0']) {
        expect(
          PaywallLayoutSetting.parse(typo),
          PaywallLayoutSetting.shipped,
          reason: typo,
        );
      }
    });

    test('auto picks by entry point', () {
      expect(PaywallLayoutSetting.parse('auto'), PaywallLayoutSetting.auto);
      expect(PaywallLayoutSetting.parse(' auto '), PaywallLayoutSetting.auto);
      expect(PaywallLayoutSetting.auto.isAuto, isTrue);
      expect(PaywallLayoutSetting.auto.isShipped, isFalse);
      expect(PaywallLayoutSetting.auto.layout, isNull);
    });

    test('every layout key pins that layout', () {
      for (final layout in PaywallLayoutId.values) {
        final setting = PaywallLayoutSetting.parse(layout.key);
        expect(setting.layout, layout);
        expect(setting.isShipped, isFalse);
        expect(setting.isAuto, isFalse);
      }
    });

    test('a build with no telemetry reads both values as empty', () {
      const gate = NoopTelemetryGate();
      expect(gate.paywallLayoutKey, '');
      expect(gate.proPaywallLayoutKey, '');
    });
  });

  group('the developer control', () {
    test('nothing saved, or a word it does not know, follows remote', () {
      expect(PaywallLayoutSetting.fromStored(null), isNull);
      expect(PaywallLayoutSetting.fromStored(''), isNull);
      expect(PaywallLayoutSetting.fromStored('gone_layout'), isNull);
    });

    test('every choice reads back as it was saved', () {
      final choices = [
        PaywallLayoutSetting.shipped,
        PaywallLayoutSetting.auto,
        for (final layout in PaywallLayoutId.values)
          PaywallLayoutSetting.pinned(layout),
      ];
      for (final choice in choices) {
        expect(PaywallLayoutSetting.fromStored(choice.storedKey), choice);
      }
    });

    test('each product keeps its own choice across launches', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final hosted = DevPaywallLayoutSwitch(
        prefs,
        DevPaywallLayoutSwitch.hostedKey,
      );
      final pro = DevPaywallLayoutSwitch(prefs, DevPaywallLayoutSwitch.proKey);
      expect(hosted.value, isNull);
      expect(pro.value, isNull);

      await hosted.setSetting(PaywallLayoutSetting.auto);
      await pro.setSetting(
        const PaywallLayoutSetting.pinned(PaywallLayoutId.sheet),
      );
      expect(prefs.getString('dev.paywall_layout'), 'auto');
      expect(prefs.getString('dev.pro_paywall_layout'), 'sheet');
      expect(
        DevPaywallLayoutSwitch(prefs, DevPaywallLayoutSwitch.hostedKey).value,
        PaywallLayoutSetting.auto,
      );

      await hosted.setSetting(PaywallLayoutSetting.shipped);
      expect(
        DevPaywallLayoutSwitch(prefs, DevPaywallLayoutSwitch.hostedKey).value,
        PaywallLayoutSetting.shipped,
      );

      await hosted.setSetting(null);
      expect(prefs.containsKey('dev.paywall_layout'), isFalse);
    });

    test('a store build has no override to set', () {
      final hosted = ValueNotifier<PaywallLayoutSetting?>(
        PaywallLayoutSetting.auto,
      );
      const override = NoPaywallLayoutOverride();
      // Handing it a switch changes nothing.
      // ignore: cascade_invocations
      override.watch(hosted: hosted, pro: hosted);
      expect(override.hosted, isNull);
      expect(override.pro, isNull);
      // This test run is not a developer build either.
      expect(buildHasPaywallLayoutSwitch, isFalse);
      expect(appPaywallLayoutOverride, isA<NoPaywallLayoutOverride>());
    });

    test('a developer build reports what the two switches hold', () {
      final override = DevPaywallLayoutOverride();
      expect(override.hosted, isNull);
      override.watch(
        hosted: ValueNotifier<PaywallLayoutSetting?>(
          PaywallLayoutSetting.shipped,
        ),
        pro: ValueNotifier<PaywallLayoutSetting?>(null),
      );
      expect(override.hosted, PaywallLayoutSetting.shipped);
      expect(override.pro, isNull);
    });
  });
}
