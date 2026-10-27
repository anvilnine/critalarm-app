import 'package:critalarm/design/ambient/ambient.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AmbientAppProfiles.historyHero', () {
    test('keeps the three slots, a disc first and the pill not drawn', () {
      for (final colors in const [AppColors.light, AppColors.dark]) {
        final profile = AmbientAppProfiles.historyHero(colors);
        expect(profile.shapes, hasLength(3));
        expect(profile.shapes[0].ring, 0);
        expect(profile.shapes[0].opacity, greaterThan(0));
        expect(profile.shapes[1].opacity, 0);
        expect(profile.canvas, colors.canvas);
      }
    });

    test('the spot moves the disc', () {
      const spot = HeroDiscSpot(
        anchor: Alignment(-0.5, -0.4),
        discScale: 0.7,
        ringScale: 0,
      );
      final profile = AmbientAppProfiles.historyHero(
        AppColors.light,
        spot: spot,
      );
      expect(profile.shapes[0].anchor, spot.anchor);
      expect(profile.shapes[0].scale, spot.discScale);
    });

    test('lerps to the History and Topics profiles and back', () {
      const colors = AppColors.light;
      final hero = AmbientAppProfiles.historyHero(colors);
      for (final other in [
        AmbientAppProfiles.history(colors),
        AmbientAppProfiles.topicsHero(colors),
        AmbientAppProfiles.settings(colors),
      ]) {
        for (final t in [0.0, 0.5, 1.0]) {
          expect(AmbientProfile.lerp(hero, other, t).shapes, hasLength(3));
          expect(AmbientProfile.lerp(other, hero, t).shapes, hasLength(3));
        }
      }
    });
  });
}
