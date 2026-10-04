import 'package:critalarm/design/components/highlight_card.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG contrast of [a] on [b], with a see-through [b] laid on [under] first.
double _contrast(Color a, Color b, {required Color under}) {
  final ground = Color.alphaBlend(b, under);
  final la = a.computeLuminance();
  final lb = ground.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('highlightToneColors', () {
    test('crit is the critical canvas and its stroke, light', () {
      const colors = AppColors.light;
      final c = highlightToneColors(AppHighlightTone.crit, colors);
      expect(c.fill, colors.critCanvas);
      expect(c.stroke, colors.critStroke);
      expect(c.fill, const Color(0xFFF5473A));
      expect(c.stroke, const Color(0xFF1A140F));
    });

    test('crit is the critical canvas and its stroke, dark', () {
      const colors = AppColors.dark;
      final c = highlightToneColors(AppHighlightTone.crit, colors);
      expect(c.fill, colors.critCanvas);
      expect(c.stroke, colors.critStroke);
      expect(c.fill, const Color(0xFF3A100D));
      expect(c.stroke, const Color(0xFFE0483A));
    });

    test('calm is the cobalt tint and cobalt, light', () {
      const colors = AppColors.light;
      final c = highlightToneColors(AppHighlightTone.calm, colors);
      expect(c.fill, colors.cobaltTint);
      expect(c.stroke, colors.cobalt);
      expect(c.fill, const Color(0xFFDCE0FF));
      expect(c.stroke, const Color(0xFF2A3BD8));
    });

    test('calm is the cobalt tint and cobalt, dark', () {
      const colors = AppColors.dark;
      final c = highlightToneColors(AppHighlightTone.calm, colors);
      expect(c.fill, colors.cobaltTint);
      expect(c.stroke, colors.cobalt);
      expect(c.fill, const Color(0x297C8AFF));
      expect(c.stroke, const Color(0xFF7C8AFF));
    });

    test('every tone is covered and no two tones share a fill', () {
      for (final colors in [AppColors.light, AppColors.dark]) {
        final fills = {
          for (final tone in AppHighlightTone.values)
            highlightToneColors(tone, colors).fill,
        };
        expect(fills, hasLength(AppHighlightTone.values.length));
      }
    });

    test('canvas text reads on every tone, on the canvas and on a card', () {
      for (final colors in [AppColors.light, AppColors.dark]) {
        for (final tone in AppHighlightTone.values) {
          final c = highlightToneColors(tone, colors);
          for (final under in [colors.canvas, colors.surface]) {
            expect(
              _contrast(colors.onCanvas, c.fill, under: under),
              greaterThanOrEqualTo(4.5),
              reason: '$tone on $under',
            );
          }
        }
      }
    });

    test('muted text reads on calm, and on crit in the dark palette', () {
      for (final colors in [AppColors.light, AppColors.dark]) {
        final calm = highlightToneColors(AppHighlightTone.calm, colors);
        for (final under in [colors.canvas, colors.surface]) {
          expect(
            _contrast(colors.onCanvasMuted, calm.fill, under: under),
            greaterThanOrEqualTo(4.5),
          );
        }
      }
      const dark = AppColors.dark;
      final crit = highlightToneColors(AppHighlightTone.crit, dark);
      expect(
        _contrast(dark.onCanvasMuted, crit.fill, under: dark.canvas),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('the stroke stands out from its own fill', () {
      for (final colors in [AppColors.light, AppColors.dark]) {
        for (final tone in AppHighlightTone.values) {
          final c = highlightToneColors(tone, colors);
          expect(
            _contrast(c.stroke, c.fill, under: colors.canvas),
            greaterThanOrEqualTo(3),
            reason: '$tone',
          );
        }
      }
    });
  });
}
