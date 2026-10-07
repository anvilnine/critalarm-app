import 'package:critalarm/features/onboarding/domain/flow/onboarding_back_rule.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_engine.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/onboarding_flow_fakes.dart';

void main() {
  final flow = BundledOnboardingFlows.defaultFlow.steps;

  String? backFrom(
    String step, {
    List<String>? steps,
    bool hasFirstTopic = false,
    Set<String> notOnThisPhone = const {},
  }) => onboardingBackStepFor(
    currentStep: step,
    flowSteps: steps ?? flow,
    hasFirstTopic: hasFirstTopic,
    isAvailable: (id) => !notOnThisPhone.contains(id),
  );

  group('the Back rule on the default flow', () {
    test('the welcome has nothing to go back to', () {
      expect(backFrom('welcome'), isNull);
    });

    test('how it rings goes back to the welcome', () {
      expect(backFrom('how_it_rings'), 'welcome');
    });

    test('connect goes back to how it rings', () {
      expect(backFrom('connect'), 'how_it_rings');
    });

    test('the permissions go back to connect', () {
      expect(backFrom('permissions'), 'connect');
    });

    test('the first topic goes back to the permissions', () {
      expect(backFrom('first_topic'), 'permissions');
    });

    test('the real ring and hook up never go back', () {
      expect(backFrom('real_ring'), isNull);
      expect(backFrom('hook_up'), isNull);
    });

    test('once the first topic exists nothing goes back', () {
      for (final step in flow) {
        expect(backFrom(step, hasFirstTopic: true), isNull, reason: step);
      }
    });
  });

  group('the Back rule on other flows', () {
    test('a step that is not on this phone is passed over', () {
      // The web has no permissions step.
      expect(
        backFrom('first_topic', notOnThisPhone: {'permissions'}),
        'connect',
      );
    });

    test('a step outside the tracker is never landed on', () {
      const steps = ['welcome', 'connect', 'offer', 'first_topic'];
      expect(backFrom('first_topic', steps: steps), 'connect');
      expect(backFrom('offer', steps: steps), isNull);
    });

    test('follows the order of the flow, whatever it is', () {
      final steps = BundledOnboardingFlows.legacy.steps;
      expect(backFrom('permissions', steps: steps), 'how_it_rings');
      // widgets sits between them and is outside the tracker.
      expect(backFrom('connect', steps: steps), 'permissions');
      expect(backFrom('widgets', steps: steps), isNull);
      expect(backFrom('legacy_test', steps: steps), isNull);
    });

    test('a step the flow does not list has no Back', () {
      expect(backFrom('connect', steps: ['welcome', 'how_it_rings']), isNull);
    });

    test('with nothing earlier on this phone there is no Back', () {
      expect(
        backFrom('connect', notOnThisPhone: {'welcome', 'how_it_rings'}),
        isNull,
      );
    });
  });

  group('going back in a run', () {
    test('opens the earlier step, which keeps what it had', () async {
      final h = EngineHarness(
        facts: FakeOnboardingStepFacts(connected: true),
        repository: FakeOnboardingFlowRepository(
          pinned: BundledOnboardingFlows.defaultFlow,
          completed: {'welcome', 'how_it_rings', 'connect', 'permissions'},
        ),
      );

      final back = await h.engine.goBack('first_topic');

      expect(back?.stepId, 'permissions');
      expect(back?.route, '/onboarding');
      // The step gone back to keeps what it had.
      expect(h.repository.completed, {
        'welcome',
        'how_it_rings',
        'connect',
        'permissions',
      });
      expect(h.events.last.kind, OnboardingStepEventKind.entered);
      expect(h.events.last.stepId, 'permissions');
    });

    test('going forward again opens the step that was left', () async {
      final h = EngineHarness(
        repository: FakeOnboardingFlowRepository(
          pinned: BundledOnboardingFlows.defaultFlow,
          completed: {'welcome', 'how_it_rings'},
        ),
      );

      // From connect back to how it rings, then back to the welcome.
      expect((await h.engine.goBack('connect'))?.stepId, 'how_it_rings');
      expect((await h.engine.goBack('how_it_rings'))?.stepId, 'welcome');
      expect(h.repository.completed, {'welcome'});

      // Forward retraces the same two steps.
      expect((await h.engine.finishStep('welcome')).stepId, 'how_it_rings');
      expect((await h.engine.finishStep('how_it_rings')).stepId, 'connect');
    });

    test('a pinned 2026-10-a run goes back by the same rule', () async {
      final h = EngineHarness(
        repository: FakeOnboardingFlowRepository(
          pinned: BundledOnboardingFlows.october2026A,
          completed: {'welcome', 'how_it_rings'},
        ),
      );

      expect(await h.engine.backStepFrom('connect'), 'how_it_rings');
      expect(h.repository.pinned, BundledOnboardingFlows.october2026A);
    });

    test('there is no Back once the first topic is owned', () async {
      final h = EngineHarness(
        facts: FakeOnboardingStepFacts(connected: true, ownsTopic: true),
        repository: FakeOnboardingFlowRepository(
          pinned: BundledOnboardingFlows.defaultFlow,
          completed: {'welcome', 'how_it_rings', 'connect'},
        ),
      );

      expect(await h.engine.backStepFrom('permissions'), isNull);
      expect(await h.engine.goBack('permissions'), isNull);
      expect(h.repository.writes, 0);
    });

    test('there is no Back once the first topic step is finished', () async {
      final h = EngineHarness(
        repository: FakeOnboardingFlowRepository(
          pinned: BundledOnboardingFlows.defaultFlow,
          completed: {'welcome', 'how_it_rings', 'connect', 'first_topic'},
        ),
      );

      expect(await h.engine.backStepFrom('permissions'), isNull);
    });

    test('a setup screen opened after setup has no Back', () async {
      final h = EngineHarness();
      h.progress.completed = true;

      expect(await h.engine.backStepFrom('connect'), isNull);
      expect(await h.engine.goBack('connect'), isNull);
    });

    test('on the web the first topic goes back to connect', () async {
      final h = EngineHarness(
        on: web,
        repository: FakeOnboardingFlowRepository(
          pinned: BundledOnboardingFlows.defaultFlow,
          completed: {'welcome', 'how_it_rings', 'connect'},
        ),
      );

      expect(await h.engine.backStepFrom('first_topic'), 'connect');
    });
  });

  group('going back on a replay', () {
    test('writes nothing', () async {
      final h = EngineHarness(
        // A user replaying from Settings owns topics. A replay makes none,
        // so that does not take Back away.
        facts: FakeOnboardingStepFacts(connected: true, ownsTopic: true),
      );
      h.progress.completed = true;

      final back = await h.engine.goBack('first_topic', isReplay: true);

      expect(back?.stepId, 'permissions');
      expect(h.repository.writes, 0);
      expect(h.repository.pinned, isNull);
      expect(h.events.single.isReplay, isTrue);
    });

    test('still stops at the real ring', () async {
      final h = EngineHarness();
      expect(await h.engine.goBack('real_ring', isReplay: true), isNull);
    });
  });

  group('where Back opens a step', () {
    test('marks the route as one the user came back to', () {
      final location = onboardingBackLocation(
        '/onboarding/connect',
        isReplay: false,
      );
      expect(location, '/onboarding/connect?back=true');
      expect(isOnboardingCameBackUri(Uri.parse(location)), isTrue);
      expect(isOnboardingReplayUri(Uri.parse(location)), isFalse);
    });

    test('carries the replay flag on', () {
      final uri = Uri.parse(
        onboardingBackLocation('/onboarding', isReplay: true),
      );
      expect(uri.path, '/onboarding');
      expect(isOnboardingCameBackUri(uri), isTrue);
      expect(isOnboardingReplayUri(uri), isTrue);
    });

    test('a step opened going forward is not one the user came back to', () {
      expect(
        isOnboardingCameBackUri(Uri.parse('/onboarding/connect')),
        isFalse,
      );
    });
  });
}
