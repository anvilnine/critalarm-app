import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_step_facts.dart';
import 'package:critalarm/features/onboarding/presentation/flow/onboarding_step_registry.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/onboarding_flow_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('widgets is an optional step', () {
    test('the bundled default flow does not hold it', () {
      expect(
        BundledOnboardingFlows.defaultFlow.contains(OnboardingStepId.widgets),
        isFalse,
      );
    });

    test('no bundled flow holds it, the welcome shows the widgets', () {
      for (final flow in BundledOnboardingFlows.all) {
        expect(
          flow.contains(OnboardingStepId.widgets),
          isFalse,
          reason: flow.id,
        );
      }
    });

    test('a fresh install on the default flow never reaches it', () async {
      final h = EngineHarness();
      final routes = <String>[(await h.engine.resume()).route!];
      for (final step in BundledOnboardingFlows.defaultFlow.steps.take(5)) {
        routes.add((await h.engine.finishStep(step)).route!);
      }

      expect(routes, isNot(contains('/onboarding/widgets')));
    });

    test('a flow that ends on it completes setup when it finishes', () async {
      const flow = OnboardingFlow(
        id: 'ends-on-widgets',
        steps: [OnboardingStepId.welcome, OnboardingStepId.widgets],
      );
      final h = EngineHarness(
        repository: FakeOnboardingFlowRepository(
          pinned: flow,
          completed: {OnboardingStepId.welcome},
        ),
      );

      expect((await h.engine.resume()).route, '/onboarding/widgets');

      final next = await h.engine.finishStep(OnboardingStepId.widgets);

      expect(next.isHome, isTrue);
      expect(h.progress.completed, isTrue);
      expect(h.repository.pinned, isNull);
    });

    test('is available on iOS and Android, not on web', () {
      bool available(OnboardingPlatform on) => OnboardingStepRegistry(
        on: on,
        facts: FakeOnboardingStepFacts(),
      ).isAvailable(OnboardingStepId.widgets);

      expect(available(iPhone), isTrue);
      expect(available(androidPhone), isTrue);
      expect(available(web), isFalse);
      expect(
        available(
          const OnboardingPlatform(
            platform: TargetPlatform.macOS,
            isWeb: false,
          ),
        ),
        isFalse,
      );
    });

    test('a web phone skips it in a flow that lists it', () async {
      const listsIt = OnboardingFlow(
        id: 'lists-widgets',
        steps: [
          OnboardingStepId.welcome,
          OnboardingStepId.howItRings,
          OnboardingStepId.permissions,
          OnboardingStepId.widgets,
          OnboardingStepId.connect,
          OnboardingStepId.legacyTest,
        ],
      );
      final h = EngineHarness(
        on: web,
        repository: FakeOnboardingFlowRepository(
          pinned: listsIt,
          completed: {
            OnboardingStepId.welcome,
            OnboardingStepId.howItRings,
            OnboardingStepId.permissions,
          },
        ),
      );

      expect((await h.engine.resume()).stepId, OnboardingStepId.connect);
    });
  });
}
