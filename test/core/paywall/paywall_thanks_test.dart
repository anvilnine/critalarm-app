import 'package:critalarm/core/paywall/paywall_layout_setting.dart';
import 'package:critalarm/core/paywall/paywall_thanks.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('every thanks has the key it ships under', () {
    expect(
      {for (final t in PaywallThanksId.values) t.name: t.key},
      {'none': 'none', 'confetti': 'confetti', 'unlock': 'unlock'},
    );
  });

  test('fromKey reads a key and nothing else', () {
    for (final thanks in PaywallThanksId.values) {
      expect(PaywallThanksId.fromKey(thanks.key), thanks);
    }
    expect(PaywallThanksId.fromKey(null), isNull);
    expect(PaywallThanksId.fromKey(''), isNull);
    expect(PaywallThanksId.fromKey('fireworks'), isNull);
    expect(PaywallThanksId.fromKey(' confetti '), isNull);
  });

  test('parse reads empty and unknown values as no thanks', () {
    expect(PaywallThanksId.parse(null), PaywallThanksId.none);
    expect(PaywallThanksId.parse(''), PaywallThanksId.none);
    expect(PaywallThanksId.parse('  '), PaywallThanksId.none);
    expect(PaywallThanksId.parse('Confetti'), PaywallThanksId.none);
    expect(PaywallThanksId.parse('fireworks'), PaywallThanksId.none);
    expect(PaywallThanksId.parse('none'), PaywallThanksId.none);
    expect(PaywallThanksId.parse(' confetti '), PaywallThanksId.confetti);
    expect(PaywallThanksId.parse('unlock'), PaywallThanksId.unlock);
  });

  group('the developer control', () {
    test('saves a thanks per product and hands back to remote', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final hosted = DevPaywallThanksSwitch(
        prefs,
        DevPaywallThanksSwitch.hostedKey,
      );
      final pro = DevPaywallThanksSwitch(prefs, DevPaywallThanksSwitch.proKey);
      expect(hosted.value, isNull);
      expect(pro.value, isNull);

      await hosted.setThanks(PaywallThanksId.confetti);
      await pro.setThanks(PaywallThanksId.none);
      expect(prefs.getString('dev.paywall_thanks'), 'confetti');
      expect(prefs.getString('dev.pro_paywall_thanks'), 'none');
      expect(
        DevPaywallThanksSwitch(prefs, DevPaywallThanksSwitch.hostedKey).value,
        PaywallThanksId.confetti,
      );
      // No thanks, set by hand, is a choice. It is not "follow remote".
      expect(
        DevPaywallThanksSwitch(prefs, DevPaywallThanksSwitch.proKey).value,
        PaywallThanksId.none,
      );

      await hosted.setThanks(null);
      await pro.setThanks(null);
      expect(prefs.containsKey('dev.paywall_thanks'), isFalse);
      expect(prefs.containsKey('dev.pro_paywall_thanks'), isFalse);
      expect(hosted.value, isNull);
      expect(pro.value, isNull);
    });

    test('a saved word this build does not know follows remote', () async {
      SharedPreferences.setMockInitialValues({
        'dev.paywall_thanks': 'fireworks',
      });
      final prefs = await SharedPreferences.getInstance();
      expect(
        DevPaywallThanksSwitch(prefs, DevPaywallThanksSwitch.hostedKey).value,
        isNull,
      );
    });

    test('a build with the override reports the thanks switches', () {
      final hostedThanks = ValueNotifier<PaywallThanksId?>(null);
      final override = DevPaywallLayoutOverride()
        ..watch(
          hosted: ValueNotifier<PaywallLayoutSetting?>(null),
          pro: ValueNotifier<PaywallLayoutSetting?>(null),
          hostedThanks: hostedThanks,
          proThanks: ValueNotifier<PaywallThanksId?>(PaywallThanksId.none),
        );
      expect(override.hostedThanks, isNull);
      expect(override.proThanks, PaywallThanksId.none);
      hostedThanks.value = PaywallThanksId.unlock;
      expect(override.hostedThanks, PaywallThanksId.unlock);
    });

    test('a store build has none', () {
      const override = NoPaywallLayoutOverride();
      expect(override.hostedThanks, isNull);
      expect(override.proThanks, isNull);
    });
  });
}
