import 'package:critalarm/design/ambient/ambient.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AmbientAppProfiles.createTopic', () {
    test('with no step it returns the step 1 arrangement it always did', () {
      for (final colors in const [AppColors.light, AppColors.dark]) {
        final profile = AmbientAppProfiles.createTopic(colors);
        final isDark = colors == AppColors.dark;

        expect(profile.canvas, colors.canvas);
        expect(profile.surfaceOpacity, 0.82);
        expect(profile.shapes.length, 3);

        expect(profile.shapes[0].color, const Color(0xFFFFB21F));
        expect(profile.shapes[0].opacity, closeTo(isDark ? 0.30 : 0.60, 1e-9));
        expect(profile.shapes[0].anchor, const Alignment(0.80, -0.70));
        expect(profile.shapes[0].scale, 0.46);
        expect(profile.shapes[0].turns, 0.05);
        expect(profile.shapes[0].depth, 0.25);

        expect(profile.shapes[1].color, const Color(0xFFFFE08A));
        expect(profile.shapes[1].opacity, closeTo(isDark ? 0.25 : 0.50, 1e-9));
        expect(profile.shapes[1].anchor, const Alignment(-0.75, 0.20));
        expect(profile.shapes[1].scale, 0.38);
        expect(profile.shapes[1].turns, -0.10);
        expect(profile.shapes[1].depth, 0.55);

        expect(profile.shapes[2].color, const Color(0xFFFFB21F));
        expect(profile.shapes[2].opacity, closeTo(isDark ? 0.25 : 0.50, 1e-9));
        expect(profile.shapes[2].anchor, const Alignment(0.10, 0.85));
        expect(profile.shapes[2].scale, 0.28);
        expect(profile.shapes[2].turns, 0.16);
        expect(profile.shapes[2].depth, 0.85);
      }
    });

    test('step 2 moves and resizes the same three shapes', () {
      for (final colors in const [AppColors.light, AppColors.dark]) {
        final one = AmbientAppProfiles.createTopic(colors);
        final two = AmbientAppProfiles.createTopic(colors, step: 2);

        expect(two, isNot(one));
        expect(two.canvas, one.canvas);
        expect(two.surfaceOpacity, one.surfaceOpacity);
        expect(two.shapes.length, one.shapes.length);

        for (var index = 0; index < two.shapes.length; index++) {
          final before = one.shapes[index];
          final after = two.shapes[index];

          // Colours and opacities stay put. Only the arrangement moves.
          expect(after.color, before.color);
          expect(after.opacity, before.opacity);
          expect(after.depth, before.depth);

          expect(after.anchor, isNot(before.anchor));
          expect(after.scale, isNot(before.scale));

          expect(after.anchor.x, inInclusiveRange(-1.0, 1.0));
          expect(after.anchor.y, inInclusiveRange(-1.0, 1.0));
          expect(after.scale, inInclusiveRange(0.0, 1.0));
        }
      }
    });
  });
}
