import 'package:critalarm/design/ambient/ambient.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/presentation/flow/onboarding_step_registry.dart';
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

  group('onboardingStepForPath', () {
    test('every step with a route resolves to its registry entry', () {
      for (final entry in OnboardingStepRegistry.entries) {
        final route = entry.route;
        if (route == null) continue;
        expect(onboardingStepForPath(route), entry.ambientStep, reason: route);
      }
    });

    test('gives every first-run screen its own step', () {
      expect(
        onboardingStepForPath('/onboarding/welcome'),
        OnboardingAmbientStep.welcome,
      );
      expect(
        onboardingStepForPath('/onboarding/how-it-rings'),
        OnboardingAmbientStep.howItRings,
      );
      expect(
        onboardingStepForPath('/onboarding'),
        OnboardingAmbientStep.notifications,
      );
      expect(
        onboardingStepForPath('/onboarding/permissions'),
        OnboardingAmbientStep.notifications,
      );
      expect(
        onboardingStepForPath('/onboarding/widgets'),
        OnboardingAmbientStep.widgets,
      );
      expect(
        onboardingStepForPath('/onboarding/connect'),
        OnboardingAmbientStep.connect,
      );
      expect(
        onboardingStepForPath('/onboarding/denied'),
        OnboardingAmbientStep.denied,
      );
      expect(
        onboardingStepForPath('/onboarding/first-topic'),
        OnboardingAmbientStep.firstTopic,
      );
      expect(
        onboardingStepForPath('/onboarding/real-ring'),
        OnboardingAmbientStep.connected,
      );
      expect(
        onboardingStepForPath('/onboarding/test'),
        OnboardingAmbientStep.legacyTest,
      );
    });

    test('screens in sequence never share a profile, so the canvas moves', () {
      for (final colors in const [AppColors.light, AppColors.dark]) {
        final catalog = OnboardingAmbientProfiles.forColors(colors);
        // Both bundled orders, by the routes the registry gives their steps.
        for (final bundled in BundledOnboardingFlows.all) {
          final flow = [
            for (final step in bundled.steps)
              OnboardingStepRegistry.entryFor(step)!.route!,
          ];
          for (var i = 0; i < flow.length - 1; i++) {
            expect(
              catalog[onboardingStepForPath(flow[i])],
              isNot(catalog[onboardingStepForPath(flow[i + 1])]),
              reason: '${bundled.id}: ${flow[i]} to ${flow[i + 1]}',
            );
          }
        }
      }
    });
  });
}
