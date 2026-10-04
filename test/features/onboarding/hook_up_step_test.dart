import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/features/onboarding/domain/connect/background_connect.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_validator.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_step_facts.dart';
import 'package:critalarm/features/onboarding/presentation/flow/connect_gate.dart';
import 'package:critalarm/features/onboarding/presentation/flow/onboarding_step_registry.dart';
import 'package:critalarm/features/onboarding/presentation/model/onboarding_ambient_profiles.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_translations.dart';
import 'support/onboarding_flow_fakes.dart';

void main() {
  group('the bundled flow', () {
    test('2026-10-a ends with hook_up, straight after real_ring', () {
      const flow = BundledOnboardingFlows.defaultFlow;
      expect(flow.id, '2026-10-a');
      expect(flow.steps, [
        'welcome',
        'how_it_rings',
        'connect',
        'permissions',
        'first_topic',
        'real_ring',
        'hook_up',
      ]);
    });

    test('passes the validator unchanged', () {
      const flow = BundledOnboardingFlows.defaultFlow;
      expect(
        validateOnboardingFlow(
          flow,
          requires: OnboardingStepRegistry.requiresById,
        ),
        flow,
      );
    });

    test('the order the app first shipped with has no hook_up', () {
      expect(
        BundledOnboardingFlows.legacy.contains(OnboardingStepId.hookUp),
        isFalse,
      );
    });
  });

  group('the hook_up step', () {
    OnboardingStepRegistry on(
      OnboardingPlatform platform, {
      bool firstMessage = false,
    }) => OnboardingStepRegistry(
      on: platform,
      facts: FakeOnboardingStepFacts(firstMessage: firstMessage),
    );

    test('has a screen on iOS and on Android', () {
      expect(on(iPhone).isAvailable(OnboardingStepId.hookUp), isTrue);
      expect(on(androidPhone).isAvailable(OnboardingStepId.hookUp), isTrue);
      expect(
        on(iPhone).routeOf(OnboardingStepId.hookUp),
        '/onboarding/hook-up',
      );
    });

    test('is not shown on the web or on a desktop', () {
      const web = OnboardingPlatform(
        platform: TargetPlatform.android,
        isWeb: true,
      );
      const mac = OnboardingPlatform(
        platform: TargetPlatform.macOS,
        isWeb: false,
      );
      expect(on(web).isAvailable(OnboardingStepId.hookUp), isFalse);
      expect(on(mac).isAvailable(OnboardingStepId.hookUp), isFalse);
    });

    test('is already true once a first message was received', () async {
      expect(await on(iPhone).isSatisfied(OnboardingStepId.hookUp), isFalse);
      expect(
        await on(
          iPhone,
          firstMessage: true,
        ).isSatisfied(OnboardingStepId.hookUp),
        isTrue,
      );
    });

    test('has its own canvas step, with a profile', () {
      expect(
        onboardingStepForPath('/onboarding/hook-up'),
        OnboardingAmbientStep.hookUp,
      );
      for (final colors in [AppColors.light, AppColors.dark]) {
        expect(
          OnboardingAmbientProfiles.forColors(
            colors,
          ).containsKey(OnboardingAmbientStep.hookUp),
          isTrue,
        );
      }
    });

    test('is never covered by the shell: Done has to stay in reach', () {
      for (final state in [
        const BackgroundConnectState(),
        const BackgroundConnectState(
          status: BackgroundConnectStatus.connecting,
        ),
        const BackgroundConnectState(status: BackgroundConnectStatus.failed),
      ]) {
        expect(
          connectGateFor(
            state: state,
            path: '/onboarding/hook-up',
            isReplay: false,
            hasConnection: false,
          ),
          ConnectGate.none,
        );
      }
    });
  });

  group('the words', () {
    setUpAll(loadTestTranslations);

    test('the analytics switch reads exactly as approved', () {
      expect(
        '${LocaleKeys.onboarding_hook_up_analytics_title.tr()} '
            '${LocaleKeys.onboarding_hook_up_analytics_line.tr()}',
        'Share anonymous setup stats. '
            'Step names and timings only, never your messages.',
      );
    });

    test('the waiting row reads exactly as approved', () {
      expect(
        LocaleKeys.onboarding_hook_up_waiting_title.tr(),
        'Waiting for your first message',
      );
    });
  });
}
