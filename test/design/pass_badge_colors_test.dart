import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_styles.dart';
import 'package:critalarm/features/settings/presentation/personalize/passes/look_pass_tone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const Map<Brightness, AppColors> _themes = {
  Brightness.light: AppColors.light,
  Brightness.dark: AppColors.dark,
};

PassBadgeColors _badge(PassTone tone, AppColors colors) => passBadgeColorsFor(
  tone,
  yellow: colors.yellow,
  inkFixed: colors.inkFixed,
);

void main() {
  group('the pill a pass gets', () {
    test('yellow with the fixed ink on the blue and the dark panel', () {
      for (final colors in _themes.values) {
        for (final pass in [PassId.sound, PassId.challenge]) {
          final badge = _badge(passToneFor(pass, colors), colors);
          expect(badge.fill, colors.yellow, reason: pass.name);
          expect(badge.ink, colors.inkFixed, reason: pass.name);
          expect(badge.border, colors.inkFixed, reason: pass.name);
        }
      }
    });

    test('the tone ink on cream and white in the light theme', () {
      const colors = AppColors.light;
      for (final pass in [PassId.widgets, PassId.appIcon]) {
        final tone = passToneFor(pass, colors);
        final badge = _badge(tone, colors);
        expect(badge.fill, tone.onGround, reason: pass.name);
        expect(badge.ink, tone.ground, reason: pass.name);
      }
    });

    test('the tone ink on the standard look red', () {
      const colors = AppColors.light;
      final tone = passToneFor(PassId.look, colors);
      final badge = _badge(tone, colors);
      expect(badge.fill, tone.onGround);
      expect(badge.ink, tone.ground);
    });

    test('a ground the yellow just clears 3 to 1 on keeps the yellow', () {
      const colors = AppColors.light;
      final yellowLuminance = ColorContrast.relativeLuminance(colors.yellow);
      // A grey whose luminance puts the yellow just above 3 to 1.
      final grey = (((yellowLuminance + 0.05) / 3 - 0.05) * 0.95).clamp(
        0.0,
        1.0,
      );
      final channel = grey <= 0.0031308
          ? grey * 12.92
          : 1.055 * math.pow(grey, 1 / 2.4) - 0.055;
      final ground = Color.from(
        alpha: 1,
        red: channel,
        green: channel,
        blue: channel,
      );
      final tone = PassTone(ground: ground, onGround: colors.surface);
      expect(
        ColorContrast.contrastRatio(colors.yellow, ground),
        greaterThanOrEqualTo(3),
      );
      expect(_badge(tone, colors).fill, colors.yellow);
    });
  });

  group('every pass and every look', () {
    final tones = <String, (PassTone, AppColors)>{
      for (final MapEntry(key: brightness, value: colors)
          in _themes.entries) ...{
        for (final pass in PassId.values)
          '${pass.name}, ${brightness.name}': (
            passToneFor(pass, colors),
            colors,
          ),
        for (final style in alarmStyles)
          '${style.id.id}, ${brightness.name}': (
            lookPassToneFor(style, brightness, colors),
            colors,
          ),
      },
    };

    for (final MapEntry(key: name, value: (tone, colors)) in tones.entries) {
      test('$name: pill 3 to 1 on the ground, word 4.5 to 1 on the pill', () {
        final badge = _badge(tone, colors);
        expect(
          ColorContrast.contrastRatio(badge.fill, tone.ground),
          greaterThanOrEqualTo(kPassBadgeGroundContrast),
        );
        expect(
          ColorContrast.contrastRatio(badge.ink, badge.fill),
          greaterThanOrEqualTo(4.5),
        );
      });
    }
  });
}
