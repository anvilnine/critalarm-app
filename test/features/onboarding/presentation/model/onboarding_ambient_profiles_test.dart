import 'package:critalarm/design/ambient/ambient.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/features/onboarding/presentation/model/onboarding_ambient_profiles.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OnboardingAmbientProfiles', () {
    test('maps every step to a valid 3-shape profile in both themes', () {
      for (final colors in const [AppColors.light, AppColors.dark]) {
        final catalog = OnboardingAmbientProfiles.forColors(colors);

        for (final step in OnboardingAmbientStep.values) {
          final profile = catalog[step];
          expect(profile, isNotNull);
          expect(profile!.shapes.length, 3);
          expect(profile.surfaceOpacity, inInclusiveRange(0.0, 1.0));

          for (final shape in profile.shapes) {
            expect(shape.opacity, inInclusiveRange(0.0, 1.0));
            expect(shape.scale, inInclusiveRange(0.0, 1.0));
            expect(shape.depth, inInclusiveRange(0.0, 1.0));
            expect(shape.anchor.x, inInclusiveRange(-1.0, 1.0));
            expect(shape.anchor.y, inInclusiveRange(-1.0, 1.0));
          }
        }
      }
    });

    test('step profiles interpolate deterministically', () {
      const colors = AppColors.dark;
      final catalog = OnboardingAmbientProfiles.forColors(colors);

      for (var i = 0; i < OnboardingAmbientStep.values.length - 1; i++) {
        final a = catalog[OnboardingAmbientStep.values[i]]!;
        final b = catalog[OnboardingAmbientStep.values[i + 1]]!;

        final mid = AmbientProfile.lerp(a, b, 0.5);
        expect(mid.shapes.length, 3);
        expect(mid.surfaceOpacity, inInclusiveRange(0.0, 1.0));
      }
    });
  });
}
