import 'package:critalarm/features/onboarding/domain/flow/onboarding_back_rule.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_engine.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_step_facts.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/onboarding_flow_fakes.dart';

void main() {
  final flow = BundledOnboardingFlows.defaultFlow.steps;

  /// With no steps given, every step of the flow was on screen. With no
  /// flow given, it is the default one.
  String? backFrom(
    String step, {
    List<String>? shown,
    List<String>? inFlow,
    bool hasFirstTopic = false,
  }) => onboardingBackStepFor(
    currentStep: step,
    flowSteps: inFlow ?? flow,
    shownSteps: (shown ?? inFlow ?? flow).toSet(),
    hasFirstTopic: hasFirstTopic,
  );

  group('the Back rule when every step was shown', () {
    test('the welcome has nothing to go back to', () {
      expect(backFrom('welcome'), isNull);
    });

    test('connect goes back to the welcome', () {
      expect(backFrom('connect'), 'welcome');
    });

    test('in 2026-10-a how it rings sits between the two', () {
      final older = BundledOnboardingFlows.october2026A.steps;
      expect(backFrom('how_it_rings', inFlow: older), 'welcome');
      expect(backFrom('connect', inFlow: older), 'how_it_rings');
    });

    test('the permissions go back to connect', () {
      expect(backFrom('permissions'), 'connect');
    });

    test('the first topic goes back to the permissions', () {
      expect(backFrom('first_topic'), 'permissions');
    });

    test('the real ring, the offer and hook up never go back', () {
      expect(backFrom('real_ring'), isNull);
      expect(backFrom('offer'), isNull);
      expect(backFrom('hook_up'), isNull);
    });

    test('once the first topic exists nothing goes back', () {
      for (final step in flow) {
        expect(backFrom(step, hasFirstTopic: true), isNull, reason: step);
      }
    });
  });

  group('the Back rule only opens steps that were shown', () {
    test('a step that was never shown is not a Back target', () {
      // The permissions were all granted, so the run passed them over.
      const shown = ['welcome', 'connect', 'first_topic'];
      expect(backFrom('first_topic', shown: shown), 'connect');

      // A server was already saved, so connect never showed.
      const noConnect = ['welcome', 'permissions'];
      expect(backFrom('permissions', shown: noConnect), 'welcome');
    });

    test('with nothing shown before it a step has no Back', () {
      // What a restart in the middle of setup leaves.
      expect(backFrom('permissions', shown: ['permissions']), isNull);
      expect(backFrom('permissions', shown: const []), isNull);
    });

    test('a step that was not shown has no Back', () {
      expect(backFrom('connect', shown: ['welcome']), isNull);
    });

    test('a step that is not in the flow has no Back', () {
      const shown = ['welcome', 'legacy_test'];
      expect(backFrom('legacy_test', shown: shown), isNull);
    });

    test('a step outside the tracker is never landed on', () {
      final legacy = BundledOnboardingFlows.legacy.steps;
      // widgets sits before connect there and is outside the tracker.
      expect(legacy.indexOf('widgets'), legacy.indexOf('connect') - 1);
      expect(backFrom('connect', inFlow: legacy), 'permissions');
      expect(backFrom('widgets', inFlow: legacy), isNull);
    });

    test('follows the order of the flow, not the order of seeing', () {
      final legacy = BundledOnboardingFlows.legacy.steps;
      expect(backFrom('permissions', inFlow: legacy), 'how_it_rings');
      expect(
        backFrom(
          'permissions',
          shown: ['permissions', 'connect', 'welcome'],
        ),
        'connect',
      );
      expect(backFrom('legacy_test', inFlow: legacy), isNull);
    });

    test('a step seen once stays in reach after going back past it', () {
      // Back from the permissions to connect, back again to the welcome,
      // then forward: connect passes itself over, and is still shown.
      const shown = ['welcome', 'connect', 'permissions'];
      expect(backFrom('permissions', shown: shown), 'connect');
    });
  });

  group('going back in a run', () {
    /// A fresh install walked forward until [step] is on screen. The server
    /// is connected at the connect step, as it is on a phone.
    Future<EngineHarness> runUpTo(
      String step, {
      OnboardingPlatform on = iPhone,
      FakeOnboardingStepFacts? facts,
    }) async {
      final h = EngineHarness(on: on, facts: facts);
      var at = (await h.engine.resume()).stepId;
      while (at != null && at != step) {
        if (at == 'connect') h.facts.connected = true;
        at = (await h.engine.finishStep(at)).stepId;
      }
      expect(at, step);
      return h;
    }

    test('opens the earlier step, which keeps what it had', () async {
      final h = await runUpTo('first_topic');

      final back = await h.engine.goBack('first_topic');

      expect(back?.stepId, 'permissions');
      expect(back?.route, '/onboarding');
      // The step gone back to keeps what it had.
      expect(h.repository.completed, {'welcome', 'connect', 'permissions'});
      expect(h.events.last.kind, OnboardingStepEventKind.entered);
      expect(h.events.last.stepId, 'permissions');
      // Going back takes nothing out of the steps that were shown.
      expect(h.engine.shownSteps, contains('first_topic'));
    });

    test('connect stays in reach after going back past it', () async {
      final h = await runUpTo('permissions');

      expect((await h.engine.goBack('permissions'))?.stepId, 'connect');
      expect((await h.engine.goBack('connect'))?.stepId, 'welcome');
      // A server is saved, so going forward passes connect over.
      expect((await h.engine.finishStep('welcome')).stepId, 'permissions');

      expect(await h.engine.backStepFrom('permissions'), 'connect');
      expect((await h.engine.goBack('permissions'))?.stepId, 'connect');
    });

    test('going forward again opens the step that was left', () async {
      final h = await runUpTo('connect');

      expect((await h.engine.goBack('connect'))?.stepId, 'welcome');
      expect(h.repository.completed, {'welcome'});
      expect(await h.engine.backStepFrom('welcome'), isNull);

      // Forward opens connect again.
      expect((await h.engine.finishStep('welcome')).stepId, 'connect');
      expect(await h.engine.backStepFrom('connect'), 'welcome');
    });

    test('permissions that were all granted are never gone back to', () async {
      final h = await runUpTo(
        'first_topic',
        facts: FakeOnboardingStepFacts(permissions: true),
      );

      expect(h.engine.shownSteps, isNot(contains('permissions')));
      expect(await h.engine.backStepFrom('first_topic'), 'connect');
    });

    test('a server saved before setup is never gone back to', () async {
      final h = await runUpTo(
        'permissions',
        facts: FakeOnboardingStepFacts(connected: true),
      );

      expect(h.engine.shownSteps, isNot(contains('connect')));
      expect(await h.engine.backStepFrom('permissions'), 'welcome');
    });

    test(
      'a step that skipped itself on screen is never gone back to',
      () async {
        final h = await runUpTo('permissions');

        final next = await h.engine.finishStep(
          'permissions',
          skippedItself: true,
        );

        expect(next.stepId, 'first_topic');
        expect(await h.engine.backStepFrom('first_topic'), 'connect');
      },
    );

    test('after a restart there is no Back until the user moves '
        'forward', () async {
      final h = EngineHarness(
        facts: FakeOnboardingStepFacts(connected: true),
        repository: FakeOnboardingFlowRepository(
          pinned: BundledOnboardingFlows.defaultFlow,
          completed: {'welcome', 'connect'},
        ),
      );

      expect((await h.engine.resume()).stepId, 'permissions');
      expect(await h.engine.backStepFrom('permissions'), isNull);

      expect((await h.engine.finishStep('permissions')).stepId, 'first_topic');
      expect(await h.engine.backStepFrom('first_topic'), 'permissions');
    });

    test('a pinned 2026-10-a run goes back by the same rule', () async {
      final h = EngineHarness(
        repository: FakeOnboardingFlowRepository(
          pinned: BundledOnboardingFlows.october2026A,
          completed: {'welcome'},
        ),
      );
      expect((await h.engine.resume()).stepId, 'how_it_rings');
      expect((await h.engine.finishStep('how_it_rings')).stepId, 'connect');

      expect(await h.engine.backStepFrom('connect'), 'how_it_rings');
      // Back to how it rings, and forward opens connect again.
      expect((await h.engine.goBack('connect'))?.stepId, 'how_it_rings');
      expect((await h.engine.finishStep('how_it_rings')).stepId, 'connect');
      expect(h.repository.pinned, BundledOnboardingFlows.october2026A);
    });

    test('there is no Back once the first topic is owned', () async {
      final h = await runUpTo('permissions');
      h.facts.ownsTopic = true;
      final writes = h.repository.writes;

      expect(await h.engine.backStepFrom('permissions'), isNull);
      expect(await h.engine.goBack('permissions'), isNull);
      expect(h.repository.writes, writes);
    });

    test('there is no Back once the first topic step is finished', () async {
      final h = EngineHarness(
        repository: FakeOnboardingFlowRepository(
          pinned: BundledOnboardingFlows.defaultFlow,
          completed: {'welcome', 'first_topic'},
        ),
      );
      expect((await h.engine.resume()).stepId, 'connect');
      h.facts.connected = true;
      expect((await h.engine.finishStep('connect')).stepId, 'permissions');

      expect(await h.engine.backStepFrom('permissions'), isNull);
    });

    test('a setup screen opened after setup has no Back', () async {
      final h = await runUpTo('connect');
      h.progress.completed = true;

      expect(await h.engine.backStepFrom('connect'), isNull);
      expect(await h.engine.goBack('connect'), isNull);
    });

    test('on the web the first topic goes back to connect', () async {
      final h = await runUpTo('first_topic', on: web);

      expect(await h.engine.backStepFrom('first_topic'), 'connect');
    });

    test('no step counts as shown once setup ends', () async {
      final h = await runUpTo('first_topic');
      h.facts
        ..ownsTopic = true
        ..firstMessage = true;
      var next = await h.engine.finishStep('first_topic');
      while (!next.isHome) {
        next = await h.engine.finishStep(next.stepId!);
      }

      expect(h.engine.shownSteps, isEmpty);
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
      // The replay opens the welcome by its route, then moves on from it.
      var at = 'welcome';
      while (at != 'first_topic') {
        at = (await h.engine.finishStep(at, isReplay: true)).stepId!;
      }

      final back = await h.engine.goBack('first_topic', isReplay: true);

      expect(back?.stepId, 'permissions');
      expect(h.repository.writes, 0);
      expect(h.repository.pinned, isNull);
      expect(h.events.every((event) => event.isReplay), isTrue);
    });

    test('the first step of a replay can be gone back to', () async {
      final h = EngineHarness()..progress.completed = true;

      await h.engine.finishStep('welcome', isReplay: true);

      expect(
        await h.engine.backStepFrom('connect', isReplay: true),
        'welcome',
      );
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
