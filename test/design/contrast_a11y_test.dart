import 'package:critalarm/design/components/switches.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Delete topic text', () {
    test('passes 4.5 to 1 on the white sheet and on the dark sheet', () {
      const light = AppColors.light;
      const dark = AppColors.dark;
      expect(
        ColorContrast.contrastRatio(light.critText, light.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        ColorContrast.contrastRatio(dark.critText, dark.surface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test(
      'the plain critical red does not, which is why the text uses a step',
      () {
        const light = AppColors.light;
        expect(
          ColorContrast.contrastRatio(light.crit, light.surface),
          lessThan(4.5),
        );
      },
    );
  });

  group('Panel switch off track', () {
    double ratioOn(AppColors colors, Color card) {
      final track = Color.alphaBlend(
        colors.onPanelMuted.withValues(alpha: panelSwitchOffTrackAlpha),
        card,
      );
      return ColorContrast.contrastRatio(track, card);
    }

    test('is at least 3 to 1 against the card in both themes', () {
      const light = AppColors.light;
      const dark = AppColors.dark;
      // The card is the dark panel in the light theme and the elevated
      // surface in the dark theme.
      expect(ratioOn(light, light.panel), greaterThanOrEqualTo(3));
      expect(ratioOn(dark, dark.surfaceElevated), greaterThanOrEqualTo(3));
    });
  });
}
