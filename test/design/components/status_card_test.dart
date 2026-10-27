import 'package:critalarm/design/components/status_card.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('statusCardSurface', () {
    test('light is the dark panel with no outline', () {
      const colors = AppColors.light;
      final s = statusCardSurface(colors, Brightness.light);
      expect(s.fill, colors.panel);
      expect(s.line, isNull);
    });

    test('dark lifts the card off the canvas and outlines it', () {
      const colors = AppColors.dark;
      final s = statusCardSurface(colors, Brightness.dark);
      expect(s.fill, colors.surfaceElevated);
      expect(s.line, colors.panelLine);
    });

    test('the dark fill is clearly lighter than the canvas it sits on', () {
      const colors = AppColors.dark;
      final s = statusCardSurface(colors, Brightness.dark);
      // The panel itself was 1.06 to 1 against the canvas.
      expect(_contrast(colors.panel, colors.canvas), lessThan(1.1));
      expect(_contrast(s.fill, colors.canvas), greaterThan(1.1));
    });

    test('the outline shows on every dark canvas, severity included', () {
      const colors = AppColors.dark;
      final s = statusCardSurface(colors, Brightness.dark);
      for (final mode in SeverityMode.values) {
        final canvas = colors.withSeverity(mode).canvas;
        final edge = Color.alphaBlend(s.line!, canvas);
        expect(_contrast(edge, canvas), greaterThan(1.5), reason: '$mode');
      }
    });
  });

  group('AppStatusTone.color', () {
    test('every tone reads on the card in both themes', () {
      for (final brightness in Brightness.values) {
        final colors = brightness == Brightness.light
            ? AppColors.light
            : AppColors.dark;
        final fill = statusCardSurface(colors, brightness).fill;
        for (final tone in AppStatusTone.values) {
          expect(
            _contrast(tone.color(colors), fill),
            greaterThanOrEqualTo(4.5),
            reason: '$tone on the $brightness card',
          );
        }
      }
    });

    test('the tones are distinct', () {
      final all = AppStatusTone.values
          .map((t) => t.color(AppColors.light))
          .toSet();
      expect(all.length, AppStatusTone.values.length);
    });
  });
}
