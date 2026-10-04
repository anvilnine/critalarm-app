import 'package:critalarm/features/onboarding/data/repositories/shared_prefs_developer_onboarding_overrides.dart';
import 'package:critalarm/features/onboarding/domain/flow/developer_onboarding.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_source.dart';
import 'package:critalarm/features/onboarding/presentation/flow/onboarding_step_registry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final requires = OnboardingStepRegistry.requiresById;

  Future<SharedPreferences> prefsWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  OnboardingFlowSource sourceOn(
    SharedPreferences prefs, {
    bool enabled = true,
  }) => DeveloperOnboardingFlowSource(
    overrides: developerOnboardingOverridesFor(prefs, enabled: enabled),
    requires: requires,
  );

  group('DeveloperOnboardingFlowSource', () {
    test('no choice returns nothing', () async {
      final source = sourceOn(await prefsWith({}));

      expect(source.current(), isNull);
    });

    test('a bundled choice returns that flow', () async {
      final prefs = await prefsWith({});
      final overrides = developerOnboardingOverridesFor(prefs, enabled: true);
      final source = DeveloperOnboardingFlowSource(
        overrides: overrides,
        requires: requires,
      );

      await overrides.chooseFlow(const DeveloperFlowChoice.bundled('legacy-1'));

      expect(source.current(), BundledOnboardingFlows.legacy);
    });

    test('a bundled id this version does not have returns nothing', () async {
      final source = sourceOn(
        await prefsWith({
          SharedPrefsDeveloperOnboardingOverrides.flowKey: 'old-9',
        }),
      );

      expect(source.current(), isNull);
    });

    test('a custom list returns the validated list', () async {
      final source = sourceOn(
        await prefsWith({
          SharedPrefsDeveloperOnboardingOverrides.flowKey:
              'custom:welcome, made_up, connect',
        }),
      );

      final flow = source.current();

      expect(flow?.id, 'custom');
      expect(flow?.steps, ['welcome', 'connect']);
    });

    test('a rejected custom list returns nothing', () async {
      final source = sourceOn(
        await prefsWith({
          SharedPrefsDeveloperOnboardingOverrides.flowKey:
              'custom:connect, welcome',
        }),
      );

      expect(source.current(), isNull);
    });

    test('choosing none clears the saved choice', () async {
      final prefs = await prefsWith({
        SharedPrefsDeveloperOnboardingOverrides.flowKey: 'legacy-1',
      });
      final overrides = developerOnboardingOverridesFor(prefs, enabled: true);

      await overrides.chooseFlow(null);

      expect(overrides.flowChoice, isNull);
      expect(
        prefs.containsKey(SharedPrefsDeveloperOnboardingOverrides.flowKey),
        isFalse,
      );
    });

    test(
      'the store implementation returns nothing with a flow saved',
      () async {
        final prefs = await prefsWith({
          SharedPrefsDeveloperOnboardingOverrides.flowKey: 'legacy-1',
        });
        final overrides = developerOnboardingOverridesFor(
          prefs,
          enabled: false,
        );

        expect(overrides, isA<NoDeveloperOnboardingOverrides>());
        expect(overrides.isActive, isFalse);
        expect(sourceOn(prefs, enabled: false).current(), isNull);
      },
    );

    test('the store implementation saves nothing when asked to', () async {
      final prefs = await prefsWith({});
      final overrides = developerOnboardingOverridesFor(prefs, enabled: false);

      await overrides.chooseFlow(const DeveloperFlowChoice.bundled('legacy-1'));
      await overrides.forceUnsatisfied('connect', forced: true);

      expect(prefs.getKeys(), isEmpty);
    });

    test('the compile-time guard is off without the developer flags', () async {
      // Tests run without SKIP_PAYWALL or PAYWALL_LAB, like a store build.
      final prefs = await prefsWith({
        SharedPrefsDeveloperOnboardingOverrides.flowKey: 'legacy-1',
      });

      expect(buildHasOnboardingDeveloperTools, isFalse);
      expect(
        developerOnboardingOverridesFor(prefs),
        isA<NoDeveloperOnboardingOverrides>(),
      );
    });
  });
}
