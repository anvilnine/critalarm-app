import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_validator.dart';
import 'package:critalarm/features/onboarding/presentation/flow/onboarding_step_registry.dart';
import 'package:critalarm/features/onboarding/presentation/model/onboarding_ambient_profiles.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/onboarding_flow_fakes.dart';

void main() {
  final requires = OnboardingStepRegistry.requiresById;

  group('the flow 2026-10-c', () {
    test('passes the validator with the registry requirements', () {
      expect(
        validateOnboardingFlow(
          BundledOnboardingFlows.october2026C,
          requires: requires,
        ),
        BundledOnboardingFlows.october2026C,
      );
    });

    test('is the default and lists the use step after the permissions', () {
      expect(BundledOnboardingFlows.defaultFlow.id, '2026-10-c');
      final steps = BundledOnboardingFlows.defaultFlow.steps;
      expect(steps.indexOf('use'), steps.indexOf('permissions') + 1);
      expect(steps.indexOf('first_topic'), steps.indexOf('use') + 1);
    });

    test('2026-10-b stays valid, listed, and has no use step', () {
      expect(
        BundledOnboardingFlows.all,
        contains(
          BundledOnboardingFlows.october2026B,
        ),
      );
      expect(
        validateOnboardingFlow(
          BundledOnboardingFlows.october2026B,
          requires: requires,
        ),
        BundledOnboardingFlows.october2026B,
      );
      expect(BundledOnboardingFlows.october2026B.contains('use'), isFalse);
      expect(BundledOnboardingFlows.october2026B.id, '2026-10-b');
    });

    test('older flows are not changed', () {
      expect(BundledOnboardingFlows.october2026A.contains('use'), isFalse);
      expect(BundledOnboardingFlows.legacy.contains('use'), isFalse);
    });
  });

  group('a phone pinned to 2026-10-b', () {
    test('keeps the flow as saved, and never opens the use step', () async {
      final h = EngineHarness(
        repository: FakeOnboardingFlowRepository(
          pinned: BundledOnboardingFlows.october2026B,
          completed: {'welcome', 'connect'},
        ),
      );

      final first = await h.engine.resume();
      expect(first.stepId, 'permissions');
      final next = await h.engine.finishStep('permissions');

      expect(next.stepId, 'first_topic');
      expect(h.repository.pinned, BundledOnboardingFlows.october2026B);
      expect(h.engine.runningFlow().id, '2026-10-b');
      expect(h.events.map((e) => e.stepId), isNot(contains('use')));
    });
  });

  group('the order on a fresh run of the default flow', () {
    test('the first open step after permissions is use', () async {
      final h = EngineHarness();
      await h.engine.resume();
      h.facts.connected = true;
      await h.engine.finishStep('welcome');
      await h.engine.finishStep('connect');

      final next = await h.engine.finishStep('permissions');

      expect(next.stepId, 'use');
      expect(next.route, '/onboarding/use');
    });

    test('after use comes the first topic', () async {
      final h = EngineHarness(
        repository: FakeOnboardingFlowRepository(
          pinned: BundledOnboardingFlows.defaultFlow,
          completed: {'welcome', 'connect', 'permissions'},
        ),
      );

      final next = await h.engine.finishStep('use');

      expect(next.stepId, 'first_topic');
    });

    test(
      'a replay opens the use step even for a user who owns a topic',
      () async {
        final h = EngineHarness();
        h.facts.ownsTopic = true;

        final next = await h.engine.finishStep('permissions', isReplay: true);

        expect(next.stepId, 'use');
        expect(h.repository.writes, 0);
      },
    );
  });

  group('the use step in the registry', () {
    final entry = OnboardingStepRegistry.entryFor('use')!;

    test('has its route and no requirements', () {
      expect(entry.route, '/onboarding/use');
      expect(entry.routeName, 'onboardingUse');
      expect(entry.requires, isEmpty);
      expect(entry.screen, isNotNull);
      expect(entry.hasTopBar, isTrue);
    });

    test('is known to the validator, so the funnel accepts its id', () {
      expect(requires.containsKey('use'), isTrue);
      expect(requires['use'], isEmpty);
    });

    test('has its own canvas step', () {
      expect(entry.ambientStep, OnboardingAmbientStep.use);
      expect(
        onboardingStepForPath('/onboarding/use'),
        OnboardingAmbientStep.use,
      );
    });

    test('counts as done for a user who already owns a topic', () async {
      expect(await entry.isSatisfied(FakeOnboardingStepFacts()), isFalse);
      expect(
        await entry.isSatisfied(FakeOnboardingStepFacts(ownsTopic: true)),
        isTrue,
      );
    });
  });
}
