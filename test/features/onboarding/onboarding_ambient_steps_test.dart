import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/presentation/flow/onboarding_step_registry.dart';
import 'package:critalarm/features/onboarding/presentation/model/onboarding_ambient_profiles.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/onboarding_flow_fakes.dart';

void main() {
  final withRoute = [
    for (final entry in OnboardingStepRegistry.entries)
      if (entry.route != null) entry,
  ];

  group('the canvas behind each setup step', () {
    test('every canvas step has a profile in light and in dark', () {
      for (final colors in [AppColors.light, AppColors.dark]) {
        final profiles = OnboardingAmbientProfiles.forColors(colors);
        for (final step in OnboardingAmbientStep.values) {
          expect(profiles.containsKey(step), isTrue, reason: '$step');
        }
      }
    });

    test('every step has its own canvas step', () {
      final seen = <OnboardingAmbientStep, String>{};
      for (final entry in withRoute) {
        expect(
          seen.containsKey(entry.ambientStep),
          isFalse,
          reason:
              '${entry.id} shares ${entry.ambientStep} with '
              '${seen[entry.ambientStep]}',
        );
        seen[entry.ambientStep] = entry.id;
      }
    });

    test('no two canvas steps draw the same shapes', () {
      final profiles = OnboardingAmbientProfiles.forColors(AppColors.light);
      const steps = OnboardingAmbientStep.values;
      for (var a = 0; a < steps.length; a++) {
        for (var b = a + 1; b < steps.length; b++) {
          expect(
            profiles[steps[a]]!.shapes,
            isNot(profiles[steps[b]]!.shapes),
            reason: '${steps[a]} and ${steps[b]}',
          );
        }
      }
    });

    test(
      'two steps next to each other in a flow never share a canvas step',
      () {
        for (final flow in BundledOnboardingFlows.all) {
          for (var i = 1; i < flow.steps.length; i++) {
            final before = OnboardingStepRegistry.entryFor(flow.steps[i - 1]);
            final after = OnboardingStepRegistry.entryFor(flow.steps[i]);
            expect(
              before!.ambientStep,
              isNot(after!.ambientStep),
              reason: '${flow.id}: ${before.id} then ${after.id}',
            );
          }
        }
      },
    );

    test('every shape moves between the steps next to each other', () {
      final profiles = OnboardingAmbientProfiles.forColors(AppColors.light);
      for (final flow in BundledOnboardingFlows.all) {
        for (var i = 1; i < flow.steps.length; i++) {
          final from =
              profiles[OnboardingStepRegistry.entryFor(
                flow.steps[i - 1],
              )!.ambientStep]!;
          final to =
              profiles[OnboardingStepRegistry.entryFor(
                flow.steps[i],
              )!.ambientStep]!;
          var moved = 0;
          for (var s = 0; s < from.shapes.length; s++) {
            if (from.shapes[s].anchor != to.shapes[s].anchor) moved++;
          }
          expect(
            moved,
            greaterThanOrEqualTo(2),
            reason: '${flow.id}: ${flow.steps[i - 1]} to ${flow.steps[i]}',
          );
        }
      }
    });
  });

  group('the welcome holds the curl and the widgets', () {
    test('no bundled flow lists the screens the welcome now shows', () {
      for (final flow in BundledOnboardingFlows.all) {
        expect(flow.contains(OnboardingStepId.howItRings), isFalse);
        expect(flow.contains(OnboardingStepId.widgets), isFalse);
      }
    });

    test('the first run is the welcome, then the setup, with no repeat', () {
      expect(BundledOnboardingFlows.defaultFlow.steps, [
        OnboardingStepId.welcome,
        OnboardingStepId.connect,
        OnboardingStepId.permissions,
        OnboardingStepId.firstTopic,
        OnboardingStepId.realRing,
        OnboardingStepId.offer,
        OnboardingStepId.hookUp,
      ]);
      expect(
        BundledOnboardingFlows.defaultFlow.steps.toSet().length,
        BundledOnboardingFlows.defaultFlow.steps.length,
      );
    });

    test('the steps stay known, so a pinned or remote flow still reads', () {
      expect(
        OnboardingStepRegistry.entryFor(OnboardingStepId.howItRings),
        isNotNull,
      );
      expect(
        OnboardingStepRegistry.entryFor(OnboardingStepId.widgets),
        isNotNull,
      );
    });
  });

  test('the platform helper is the one the other tests use', () {
    expect(iPhone.platform, TargetPlatform.iOS);
  });
}
