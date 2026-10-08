import 'package:critalarm/core/paywall/paywall_intro.dart';
import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:critalarm/core/paywall/paywall_layout_setting.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('every intro has the key it ships under', () {
    expect(
      {for (final i in PaywallIntroId.values) i.name: i.key},
      {
        'none': 'none',
        'falseAlarm': 'false_alarm',
        'snooze': 'snooze',
        'wakeUp': 'wake_up',
        'curtain': 'curtain',
        'alarmSnack': 'alarm_snack',
      },
    );
  });

  test('parse reads empty and unknown values as no intro', () {
    expect(PaywallIntroId.parse(null), PaywallIntroId.none);
    expect(PaywallIntroId.parse(''), PaywallIntroId.none);
    expect(PaywallIntroId.parse('  '), PaywallIntroId.none);
    expect(PaywallIntroId.parse('falseAlarm'), PaywallIntroId.none);
    expect(PaywallIntroId.parse('none'), PaywallIntroId.none);
    expect(PaywallIntroId.parse(' false_alarm '), PaywallIntroId.falseAlarm);
    expect(PaywallIntroId.fromKey('drumroll'), isNull);
  });

  test('the key of an intro that was taken out reads as no intro', () {
    expect(PaywallIntroId.fromKey('countdown'), isNull);
    expect(PaywallIntroId.parse('countdown'), PaywallIntroId.none);
    expect(PaywallIntroId.parse(' countdown '), PaywallIntroId.none);
  });

  test('a stored developer pick of it follows the remote value', () async {
    SharedPreferences.setMockInitialValues({'dev.paywall_intro': 'countdown'});
    final prefs = await SharedPreferences.getInstance();
    expect(
      DevPaywallIntroSwitch(prefs, DevPaywallIntroSwitch.hostedKey).value,
      isNull,
    );
  });

  group('the key the false alarm had as a layout', () {
    test('reads as the hero layout', () {
      expect(
        PaywallLayoutSetting.parse('false_alarm'),
        const PaywallLayoutSetting.pinned(PaywallLayoutId.hero),
      );
      expect(
        PaywallLayoutSetting.fromStored('false_alarm'),
        const PaywallLayoutSetting.pinned(PaywallLayoutId.hero),
      );
    });

    test('and carries the false alarm intro', () {
      expect(
        paywallIntroInLayoutValue('false_alarm'),
        PaywallIntroId.falseAlarm,
      );
      expect(
        paywallIntroInLayoutValue(' false_alarm '),
        PaywallIntroId.falseAlarm,
      );
      for (final other in [null, '', 'hero', 'auto', 'plain']) {
        expect(paywallIntroInLayoutValue(other), isNull, reason: '$other');
      }
    });

    test('the layout that was removed outright is the shipped surface', () {
      expect(PaywallLayoutSetting.parse('plain'), PaywallLayoutSetting.shipped);
      expect(PaywallLayoutSetting.fromStored('plain'), isNull);
    });
  });

  group('the developer control', () {
    test('saves an intro per product and hands back to remote', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final hosted = DevPaywallIntroSwitch(
        prefs,
        DevPaywallIntroSwitch.hostedKey,
      );
      final pro = DevPaywallIntroSwitch(prefs, DevPaywallIntroSwitch.proKey);
      expect(hosted.value, isNull);

      await hosted.setIntro(PaywallIntroId.falseAlarm);
      await pro.setIntro(PaywallIntroId.none);
      expect(prefs.getString('dev.paywall_intro'), 'false_alarm');
      expect(prefs.getString('dev.pro_paywall_intro'), 'none');
      expect(
        DevPaywallIntroSwitch(prefs, DevPaywallIntroSwitch.hostedKey).value,
        PaywallIntroId.falseAlarm,
      );
      // No intro, set by hand, is a choice. It is not "follow remote".
      expect(
        DevPaywallIntroSwitch(prefs, DevPaywallIntroSwitch.proKey).value,
        PaywallIntroId.none,
      );

      await hosted.setIntro(null);
      expect(prefs.containsKey('dev.paywall_intro'), isFalse);
      expect(hosted.value, isNull);
    });

    test('a build with the override reports the intro switches', () {
      final hostedIntro = ValueNotifier<PaywallIntroId?>(null);
      final override = DevPaywallLayoutOverride()
        ..watch(
          hosted: ValueNotifier<PaywallLayoutSetting?>(null),
          pro: ValueNotifier<PaywallLayoutSetting?>(null),
          hostedIntro: hostedIntro,
          proIntro: ValueNotifier<PaywallIntroId?>(PaywallIntroId.none),
        );
      expect(override.hostedIntro, isNull);
      expect(override.proIntro, PaywallIntroId.none);
      hostedIntro.value = PaywallIntroId.falseAlarm;
      expect(override.hostedIntro, PaywallIntroId.falseAlarm);
    });

    test('a store build has none', () {
      const override = NoPaywallLayoutOverride();
      expect(override.hostedIntro, isNull);
      expect(override.proIntro, isNull);
    });
  });
}
