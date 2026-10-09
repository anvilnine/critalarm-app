import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/pass_tones.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const themes = {'light': AppColors.light, 'dark': AppColors.dark};

  group('passToneFor', () {
    for (final MapEntry(key: name, value: colors) in themes.entries) {
      group(name, () {
        test('sound is white on the highlight blue', () {
          final tone = passToneFor(PassId.sound, colors);
          expect(tone.ground, colors.highlight);
          expect(tone.onGround, colors.onHighlight);
          expect(
            ColorContrast.contrastRatio(tone.onGround, tone.ground),
            closeTo(7.73, 0.01),
          );
        });

        test('challenge is the panel with its own text', () {
          final tone = passToneFor(PassId.challenge, colors);
          expect(tone.ground, colors.panel);
          expect(tone.onGround, colors.onPanel);
          expect(tone.valueOn, colors.yellow);
          expect(tone.valueMuted, colors.onPanelMuted);
        });

        test('widgets is cream with ink', () {
          final tone = passToneFor(PassId.widgets, colors);
          expect(tone.ground, colors.cream);
          expect(tone.onGround, colors.ink);
        });

        test('app icon is the surface with ink', () {
          final tone = passToneFor(PassId.appIcon, colors);
          expect(tone.ground, colors.surface);
          expect(tone.onGround, colors.ink);
        });

        test('look falls back to the standard look', () {
          final tone = passToneFor(PassId.look, colors);
          expect(tone.ground, colors.critCanvas);
          expect(tone.onGround, colors.ink);
        });

        for (final pass in PassId.values) {
          test('${pass.name} text is 4.5 to 1 or more on its ground', () {
            final tone = passToneFor(pass, colors);
            expect(
              ColorContrast.contrastRatio(tone.onGround, tone.ground),
              greaterThanOrEqualTo(4.5),
            );
          });

          test('${pass.name} muted value is 4.5 to 1 or more', () {
            final tone = passToneFor(pass, colors);
            expect(
              ColorContrast.contrastRatio(tone.valueMuted, tone.ground),
              greaterThanOrEqualTo(4.5),
            );
          });

          test('${pass.name} value while on is 4.5 to 1 or more', () {
            final tone = passToneFor(pass, colors);
            expect(
              ColorContrast.contrastRatio(tone.valueOn, tone.ground),
              greaterThanOrEqualTo(4.5),
            );
          });
        }

        test('the yellow value reads on the challenge ground', () {
          final tone = passToneFor(PassId.challenge, colors);
          expect(
            ColorContrast.contrastRatio(tone.valueOn, tone.ground),
            greaterThanOrEqualTo(11),
          );
        });
      });
    }

    test('widgets and app icon match the contrast the spec computed', () {
      expect(
        ColorContrast.contrastRatio(
          AppColors.light.ink,
          AppColors.light.cream,
        ),
        closeTo(16.36, 0.02),
      );
      expect(
        ColorContrast.contrastRatio(
          AppColors.light.ink,
          AppColors.light.surface,
        ),
        closeTo(18.25, 0.02),
      );
    });
  });

  group('PassTone', () {
    test('value colour follows the state', () {
      final tone = passToneFor(PassId.challenge, AppColors.light);
      expect(tone.valueFor(isOn: true), AppColors.light.yellow);
      expect(tone.valueFor(isOn: false), AppColors.light.onPanelMuted);
    });

    test('a tone with one text colour uses it for both values', () {
      const tone = PassTone(
        ground: Color(0xFF000000),
        onGround: Color(0xFFFFFFFF),
      );
      expect(tone.valueOn, tone.onGround);
      expect(tone.valueMuted, tone.onGround);
    });

    test('the edge is the text colour at 18%', () {
      final tone = passToneFor(PassId.sound, AppColors.light);
      expect(tone.edge.a, closeTo(0.18, 0.005));
      expect(tone.edge.withValues(alpha: 1), tone.onGround);
    });

    test('lerp ends on its ends', () {
      final a = passToneFor(PassId.sound, AppColors.light);
      final b = passToneFor(PassId.widgets, AppColors.light);
      expect(PassTone.lerp(a, b, 0), a);
      expect(PassTone.lerp(a, b, 1), b);
    });
  });
}
