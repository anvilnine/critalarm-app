import 'package:critalarm/core/paywall/paywall_layout_setting.dart';
import 'package:critalarm/core/paywall/paywall_outro.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('every outro has the key it ships under', () {
    expect(
      {for (final o in PaywallOutroId.values) o.name: o.key},
      {
        'none': 'none',
        'breakLiftRing': 'break_lift_ring',
        'cloudClimb': 'cloud_climb',
      },
    );
  });

  test('fromKey reads a key and nothing else', () {
    for (final outro in PaywallOutroId.values) {
      expect(PaywallOutroId.fromKey(outro.key), outro);
    }
    expect(PaywallOutroId.fromKey(null), isNull);
    expect(PaywallOutroId.fromKey(''), isNull);
    expect(PaywallOutroId.fromKey('fireworks'), isNull);
    expect(PaywallOutroId.fromKey(' cloud_climb '), isNull);
  });

  test('parse reads empty and unknown values as no outro', () {
    expect(PaywallOutroId.parse(null), PaywallOutroId.none);
    expect(PaywallOutroId.parse(''), PaywallOutroId.none);
    expect(PaywallOutroId.parse('  '), PaywallOutroId.none);
    expect(PaywallOutroId.parse('Cloud_Climb'), PaywallOutroId.none);
    expect(PaywallOutroId.parse('fireworks'), PaywallOutroId.none);
    expect(PaywallOutroId.parse('none'), PaywallOutroId.none);
    expect(
      PaywallOutroId.parse(' cloud_climb '),
      PaywallOutroId.cloudClimb,
    );
    expect(
      PaywallOutroId.parse('break_lift_ring'),
      PaywallOutroId.breakLiftRing,
    );
  });

  group('the developer control', () {
    test('saves an outro per product and hands back to remote', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final hosted = DevPaywallOutroSwitch(
        prefs,
        DevPaywallOutroSwitch.hostedKey,
      );
      final pro = DevPaywallOutroSwitch(prefs, DevPaywallOutroSwitch.proKey);
      expect(hosted.value, isNull);
      expect(pro.value, isNull);

      await hosted.setOutro(PaywallOutroId.cloudClimb);
      await pro.setOutro(PaywallOutroId.none);
      expect(prefs.getString('dev.paywall_outro'), 'cloud_climb');
      expect(prefs.getString('dev.pro_paywall_outro'), 'none');
      expect(
        DevPaywallOutroSwitch(prefs, DevPaywallOutroSwitch.hostedKey).value,
        PaywallOutroId.cloudClimb,
      );
      // No outro, set by hand, is a choice. It is not "follow remote".
      expect(
        DevPaywallOutroSwitch(prefs, DevPaywallOutroSwitch.proKey).value,
        PaywallOutroId.none,
      );

      await hosted.setOutro(null);
      await pro.setOutro(null);
      expect(prefs.containsKey('dev.paywall_outro'), isFalse);
      expect(prefs.containsKey('dev.pro_paywall_outro'), isFalse);
      expect(hosted.value, isNull);
      expect(pro.value, isNull);
    });

    test('a saved word this build does not know follows remote', () async {
      SharedPreferences.setMockInitialValues({
        'dev.paywall_outro': 'fireworks',
      });
      final prefs = await SharedPreferences.getInstance();
      expect(
        DevPaywallOutroSwitch(prefs, DevPaywallOutroSwitch.hostedKey).value,
        isNull,
      );
    });

    test('a build with the override reports the outro switches', () {
      final hostedOutro = ValueNotifier<PaywallOutroId?>(null);
      final override = DevPaywallLayoutOverride()
        ..watch(
          hosted: ValueNotifier<PaywallLayoutSetting?>(null),
          pro: ValueNotifier<PaywallLayoutSetting?>(null),
          hostedOutro: hostedOutro,
          proOutro: ValueNotifier<PaywallOutroId?>(PaywallOutroId.none),
        );
      expect(override.hostedOutro, isNull);
      expect(override.proOutro, PaywallOutroId.none);
      hostedOutro.value = PaywallOutroId.breakLiftRing;
      expect(override.hostedOutro, PaywallOutroId.breakLiftRing);
    });

    test('a build that reports no outro switch has none', () {
      final override = DevPaywallLayoutOverride()
        ..watch(
          hosted: ValueNotifier<PaywallLayoutSetting?>(null),
          pro: ValueNotifier<PaywallLayoutSetting?>(null),
        );
      expect(override.hostedOutro, isNull);
      expect(override.proOutro, isNull);
    });

    test('a store build has none', () {
      const override = NoPaywallLayoutOverride();
      expect(override.hostedOutro, isNull);
      expect(override.proOutro, isNull);
    });
  });
}
