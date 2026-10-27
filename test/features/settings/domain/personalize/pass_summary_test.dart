import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/app_icon/app_icon.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/challenges/domain/challenge_kind.dart';
import 'package:critalarm/features/settings/domain/personalize/pass_summary.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter_test/flutter_test.dart';

PersonalizeSummary _summary({
  String lookNameKey = LocaleKeys.alarm_styles_standard,
  bool lookIsStandard = true,
  String? soundName = 'Classic siren',
  ChallengeKind? challengeKind,
  bool challengesLocked = false,
  bool hasWidgets = true,
  AppIcon? appIcon = AppIcon.standard,
}) => personalizeSummaryFor(
  lookNameKey: lookNameKey,
  lookIsStandard: lookIsStandard,
  soundName: soundName,
  challengeKind: challengeKind,
  challengesLocked: challengesLocked,
  hasWidgets: hasWidgets,
  appIcon: appIcon,
);

void main() {
  test('the passes come in the order of the stack', () {
    expect(
      _summary().present.map((p) => p.pass),
      PassId.values.where((p) => p != PassId.tokens),
    );
  });

  group('look', () {
    test('says the name of the look that rings', () {
      final look = _summary(
        lookNameKey: LocaleKeys.alarm_styles_terminal,
        lookIsStandard: false,
      ).of(PassId.look);
      expect(look.value, const PassValueKey(LocaleKeys.alarm_styles_terminal));
      expect(look.isOn, isTrue);
    });

    test('the standard look is the default, not a saved choice', () {
      expect(_summary().of(PassId.look).isOn, isFalse);
    });
  });

  group('sound', () {
    test('says the name it is given, which is the stand-in while own sounds '
        'are locked', () {
      expect(
        _summary(soundName: 'Pulsing klaxon').of(PassId.sound).value,
        const PassValueText('Pulsing klaxon'),
      );
    });

    test('a sound the phone does not have reads as the default sound', () {
      for (final name in <String?>[null, '']) {
        expect(
          _summary(soundName: name).of(PassId.sound).value,
          const PassValueKey(LocaleKeys.personalize_passes_root_sound_unknown),
        );
      }
    });
  });

  group('challenge', () {
    test('Off with nothing saved', () {
      final challenge = _summary().of(PassId.challenge);
      expect(challenge.value, const PassValueKey(LocaleKeys.challenges_off));
      expect(challenge.isOn, isFalse);
    });

    test('says the saved challenge by name', () {
      final challenge = _summary(
        challengeKind: ChallengeKind.opsMath,
      ).of(PassId.challenge);
      expect(
        challenge.value,
        const PassValueKey(LocaleKeys.challenges_ops_math_name),
      );
      expect(challenge.isOn, isTrue);
    });

    test('has a name for every kind', () {
      for (final kind in ChallengeKind.values) {
        expect(challengeNameKeyOf(kind), isNotEmpty);
        expect(
          _summary(challengeKind: kind).of(PassId.challenge).value,
          PassValueKey(challengeNameKeyOf(kind)),
        );
      }
    });

    test('is Off while challenges are locked, even with a kind saved', () {
      final challenge = _summary(
        challengeKind: ChallengeKind.shake,
        challengesLocked: true,
      ).of(PassId.challenge);
      expect(challenge.value, const PassValueKey(LocaleKeys.challenges_off));
      expect(challenge.isOn, isFalse);
    });
  });

  test('widgets say Home screen, with no count', () {
    final widgets = _summary().of(PassId.widgets);
    expect(
      widgets.value,
      const PassValueKey(LocaleKeys.personalize_passes_root_widgets_value),
    );
  });

  group('app icon', () {
    test('has a name for each of the four', () {
      const keys = {
        AppIcon.standard: LocaleKeys.settings_app_icon_default,
        AppIcon.crowned: LocaleKeys.settings_app_icon_crowned,
        AppIcon.shades: LocaleKeys.settings_app_icon_shades,
        AppIcon.shadesCrown: LocaleKeys.settings_app_icon_shades_crown,
      };
      expect(keys.keys, unorderedEquals(AppIcon.values));
      for (final MapEntry(:key, :value) in keys.entries) {
        final icon = _summary(appIcon: key).of(PassId.appIcon);
        expect(icon.value, PassValueKey(value));
        expect(icon.isOn, key != AppIcon.standard);
      }
    });
  });

  group('passes this phone does not have', () {
    test('no home screen widgets (web, desktop): Widgets is left out', () {
      final summary = _summary(hasWidgets: false);
      expect(summary.of(PassId.widgets).exists, isFalse);
      expect(
        summary.present.map((p) => p.pass),
        [PassId.look, PassId.sound, PassId.challenge, PassId.appIcon],
      );
    });

    test('a platform that cannot change its icon: App icon is left out', () {
      expect(_summary(appIcon: null).of(PassId.appIcon).exists, isFalse);
    });

    test('web and desktop have three passes', () {
      final summary = _summary(hasWidgets: false, appIcon: null);
      expect(summary.present.map((p) => p.pass), [
        PassId.look,
        PassId.sound,
        PassId.challenge,
      ]);
    });

    test('Look, Sound and Challenge are on every phone', () {
      final summary = _summary(hasWidgets: false, appIcon: null);
      for (final pass in [PassId.look, PassId.sound, PassId.challenge]) {
        expect(summary.of(pass).exists, isTrue);
      }
    });
  });

  test('each pass names the plan feature it sells', () {
    final summary = _summary();
    expect(summary.of(PassId.look).feature, AppFeature.alarmScreenStyles);
    expect(summary.of(PassId.sound).feature, AppFeature.ownSounds);
    expect(summary.of(PassId.challenge).feature, AppFeature.wakeUpChallenges);
    expect(summary.of(PassId.widgets).feature, AppFeature.widgets);
    expect(summary.of(PassId.appIcon).feature, AppFeature.appIcons);
  });

  test('only Challenge, Widgets and App icon carry a plan word', () {
    final summary = _summary();
    expect(
      {for (final p in summary.passes) p.pass: p.showsTag},
      {
        PassId.look: false,
        PassId.sound: false,
        PassId.challenge: true,
        PassId.widgets: true,
        PassId.appIcon: true,
      },
    );
  });
}
