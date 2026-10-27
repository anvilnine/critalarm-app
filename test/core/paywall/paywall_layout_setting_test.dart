import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:critalarm/core/paywall/paywall_layout_setting.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('the setting', () {
    test('auto pins nothing, so the place table decides', () {
      expect(PaywallLayoutSetting.auto.isAuto, isTrue);
      expect(PaywallLayoutSetting.auto.layout, isNull);
    });

    test('every layout pins that layout', () {
      for (final layout in PaywallLayoutId.values) {
        final setting = PaywallLayoutSetting.pinned(layout);
        expect(setting.layout, layout);
        expect(setting.isAuto, isFalse);
      }
    });
  });

  group('the developer control', () {
    test('nothing saved, or a word it does not know, is Auto', () {
      expect(PaywallLayoutSetting.fromStored(null), isNull);
      expect(PaywallLayoutSetting.fromStored(''), isNull);
      expect(PaywallLayoutSetting.fromStored('  '), isNull);
      expect(PaywallLayoutSetting.fromStored('gone_layout'), isNull);
      for (final typo in ['heroo', 'Hero', 'AUTO', 'none', '0']) {
        expect(PaywallLayoutSetting.fromStored(typo), isNull, reason: typo);
      }
    });

    test('the words an older build saved read as Auto', () async {
      // An install that picked "What ships today" or "Auto, by entry point"
      // before the old surfaces went still has the word saved.
      for (final word in ['shipped', 'auto']) {
        expect(PaywallLayoutSetting.fromStored(word), isNull, reason: word);
        SharedPreferences.setMockInitialValues({
          'dev.paywall_layout': word,
          'dev.pro_paywall_layout': word,
        });
        final prefs = await SharedPreferences.getInstance();
        expect(
          DevPaywallLayoutSwitch(prefs, DevPaywallLayoutSwitch.hostedKey).value,
          isNull,
          reason: word,
        );
        expect(
          DevPaywallLayoutSwitch(prefs, DevPaywallLayoutSwitch.proKey).value,
          isNull,
          reason: word,
        );
      }
    });

    test('every pinned layout reads back as it was saved', () {
      for (final layout in PaywallLayoutId.values) {
        final choice = PaywallLayoutSetting.pinned(layout);
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

      await hosted.setSetting(
        const PaywallLayoutSetting.pinned(PaywallLayoutId.proof),
      );
      await pro.setSetting(
        const PaywallLayoutSetting.pinned(PaywallLayoutId.sheet),
      );
      expect(prefs.getString('dev.paywall_layout'), 'proof');
      expect(prefs.getString('dev.pro_paywall_layout'), 'sheet');
      expect(
        DevPaywallLayoutSwitch(prefs, DevPaywallLayoutSwitch.hostedKey).value,
        const PaywallLayoutSetting.pinned(PaywallLayoutId.proof),
      );

      // Auto saves nothing: it is the same as no choice.
      await hosted.setSetting(PaywallLayoutSetting.auto);
      expect(hosted.value, isNull);
      expect(prefs.containsKey('dev.paywall_layout'), isFalse);

      await hosted.setSetting(
        const PaywallLayoutSetting.pinned(PaywallLayoutId.proof),
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
          const PaywallLayoutSetting.pinned(PaywallLayoutId.wipe),
        ),
        pro: ValueNotifier<PaywallLayoutSetting?>(null),
      );
      expect(
        override.hosted,
        const PaywallLayoutSetting.pinned(PaywallLayoutId.wipe),
      );
      expect(override.pro, isNull);
    });
  });
}
