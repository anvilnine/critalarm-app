import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_engine.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_step_facts.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/onboarding_flow_fakes.dart';

void main() {
  const flow = BundledOnboardingFlows.defaultFlow;

  group('resume', () {
    test('nothing pinned opens welcome and saves nothing', () async {
      final h = EngineHarness();

      final next = await h.engine.resume();

      expect(next.stepId, 'welcome');
      expect(next.route, '/onboarding/welcome');
      expect(h.repository.writes, 0);
    });

    test('a completed step is skipped', () async {
      final h = EngineHarness(
        repository: FakeOnboardingFlowRepository(
          pinned: flow,
          completed: {'welcome', 'how_it_rings'},
        ),
      );

      expect((await h.engine.resume()).route, '/onboarding/connect');
    });

    test('a satisfied step is skipped', () async {
      final h = EngineHarness(
        facts: FakeOnboardingStepFacts(connected: true, permissions: true),
        repository: FakeOnboardingFlowRepository(
          pinned: flow,
          completed: {'welcome', 'how_it_rings'},
        ),
      );

      expect((await h.engine.resume()).route, '/onboarding/first-topic');
    });

    test('an unavailable step is skipped', () async {
      // The permissions screen is mobile only.
      final h = EngineHarness(
        on: web,
        facts: FakeOnboardingStepFacts(connected: true),
        repository: FakeOnboardingFlowRepository(
          pinned: flow,
          completed: {'welcome', 'how_it_rings'},
        ),
      );

      expect((await h.engine.resume()).stepId, 'first_topic');
    });

    test('hook_up in a custom list is skipped, not shown', () async {
      final h = EngineHarness(
        repository: FakeOnboardingFlowRepository(
          pinned: const OnboardingFlow(
            id: 'custom',
            steps: ['welcome', 'connect', 'first_topic', 'hook_up', 'widgets'],
          ),
          completed: {'welcome', 'connect', 'first_topic'},
        ),
      );

      expect((await h.engine.resume()).stepId, 'widgets');
    });

    test('a step id from another version is skipped', () async {
      final h = EngineHarness(
        repository: FakeOnboardingFlowRepository(
          pinned: const OnboardingFlow(
            id: 'newer',
            steps: ['welcome', 'not_built_yet', 'connect'],
          ),
          completed: {'welcome'},
        ),
      );

      expect((await h.engine.resume()).stepId, 'connect');
    });

    test('every step done means setup is complete', () async {
      final h = EngineHarness(
        facts: FakeOnboardingStepFacts(
          connected: true,
          permissions: true,
          ownsTopic: true,
        ),
        repository: FakeOnboardingFlowRepository(
          pinned: flow,
          completed: {'welcome', 'how_it_rings', 'real_ring'},
        ),
      );

      final next = await h.engine.resume();

      expect(next.isHome, isTrue);
      expect(h.progress.completed, isTrue);
      expect(h.repository.pinned, isNull);
      expect(h.repository.completed, isEmpty);
    });
  });

  group('finishStep', () {
    test('marks the step completed and opens the next open one', () async {
      final h = EngineHarness(
        repository: FakeOnboardingFlowRepository(
          pinned: flow,
          completed: {'welcome'},
        ),
      );

      final next = await h.engine.finishStep('how_it_rings');

      expect(next.route, '/onboarding/connect');
      expect(h.repository.completed, {'welcome', 'how_it_rings'});
    });

    test('walks the default flow in order on a fresh phone', () async {
      final h = EngineHarness();
      final seen = <String>[(await h.engine.resume()).route!];

      for (final step in flow.steps.take(flow.steps.length - 1)) {
        seen.add((await h.engine.finishStep(step)).route!);
      }

      expect(seen, [
        '/onboarding/welcome',
        '/onboarding/how-it-rings',
        '/onboarding/connect',
        '/onboarding',
        '/onboarding/first-topic',
        '/onboarding/real-ring',
      ]);
      expect(h.progress.completed, isFalse);
    });

    test('walks the legacy flow in its own order', () async {
      final h = EngineHarness(
        repository: FakeOnboardingFlowRepository(
          pinned: BundledOnboardingFlows.legacy,
        ),
      );
      final seen = <String>[(await h.engine.resume()).route!];

      for (final step in ['welcome', 'how_it_rings', 'permissions']) {
        seen.add((await h.engine.finishStep(step)).route!);
      }
      seen
        ..add((await h.engine.finishStep('widgets')).route!)
        ..add((await h.engine.finishStep('connect')).route!);

      expect(seen, [
        '/onboarding/welcome',
        '/onboarding/how-it-rings',
        '/onboarding',
        '/onboarding/widgets',
        '/onboarding/connect',
        '/onboarding/test',
      ]);
    });

    test('finishing the last step completes setup and goes Home', () async {
      final h = EngineHarness(
        repository: FakeOnboardingFlowRepository(
          pinned: flow,
          completed: flow.steps.toSet()..remove('real_ring'),
        ),
      );

      final next = await h.engine.finishStep('real_ring');

      expect(next.isHome, isTrue);
      expect(h.progress.completed, isTrue);
      expect(h.repository.pinned, isNull);
    });

    test('reports each step finished and entered, with the flow id', () async {
      final h = EngineHarness();

      await h.engine.finishStep('welcome');

      expect(
        h.events.map((e) => (e.kind, e.stepId, e.flowId, e.isReplay)),
        [
          (OnboardingStepEventKind.finished, 'welcome', '2026-10-a', false),
          (OnboardingStepEventKind.entered, 'how_it_rings', '2026-10-a', false),
        ],
      );
    });
  });

  group('a replay', () {
    test('skips nothing and saves nothing', () async {
      // Everything is already true for this user, and setup is long over.
      final h = EngineHarness(
        facts: FakeOnboardingStepFacts(
          connected: true,
          permissions: true,
          ownsTopic: true,
        ),
      );
      final seen = <String>[];

      for (final step in flow.steps) {
        final next = await h.engine.finishStep(step, isReplay: true);
        seen.add(next.route ?? 'home');
      }

      expect(seen, [
        '/onboarding/how-it-rings',
        '/onboarding/connect',
        '/onboarding',
        '/onboarding/first-topic',
        '/onboarding/real-ring',
        'home',
      ]);
      expect(h.repository.writes, 0);
      expect(h.repository.pinned, isNull);
      expect(h.progress.completed, isFalse);
    });

    test('still leaves out a step this phone does not have', () async {
      final h = EngineHarness(on: web);

      final next = await h.engine.finishStep('connect', isReplay: true);

      expect(next.stepId, 'first_topic');
    });

    test('does not disturb a run that is pinned and in progress', () async {
      final repository = FakeOnboardingFlowRepository(
        pinned: BundledOnboardingFlows.legacy,
        completed: {'welcome'},
      );
      final h = EngineHarness(repository: repository);

      await h.engine.finishStep('how_it_rings', isReplay: true);

      expect(repository.pinned, BundledOnboardingFlows.legacy);
      expect(repository.completed, {'welcome'});
      expect(repository.writes, 0);
    });
  });

  group('the permissions step is satisfied', () {
    bool satisfied(
      OnboardingPlatform on, {
      bool notifications = true,
      AlarmAuthorization alarm = AlarmAuthorization.unsupported,
      bool fullScreen = false,
    }) => onboardingPermissionsSatisfied(
      on: on,
      notificationsGranted: notifications,
      alarm: alarm,
      fullScreenGranted: fullScreen,
    );

    test('never without notifications', () {
      expect(
        satisfied(
          iPhone,
          notifications: false,
          alarm: AlarmAuthorization.authorized,
        ),
        isFalse,
      );
      expect(
        satisfied(androidPhone, notifications: false, fullScreen: true),
        isFalse,
      );
    });

    test('iOS 26: only once AlarmKit is authorized', () {
      expect(
        satisfied(iPhone, alarm: AlarmAuthorization.notDetermined),
        isFalse,
      );
      expect(satisfied(iPhone, alarm: AlarmAuthorization.denied), isFalse);
      expect(satisfied(iPhone, alarm: AlarmAuthorization.authorized), isTrue);
    });

    test('iOS 16 to 25: on notifications alone', () {
      expect(satisfied(iPhone), isTrue);
    });

    test('Android: needs the full-screen intent permission too', () {
      expect(satisfied(androidPhone), isFalse);
      expect(satisfied(androidPhone, fullScreen: true), isTrue);
    });
  });

  group('a relaunch after connecting', () {
    EngineHarness connected(
      OnboardingPlatform on, {
      required bool permissions,
    }) => EngineHarness(
      on: on,
      facts: FakeOnboardingStepFacts(connected: true, permissions: permissions),
      repository: FakeOnboardingFlowRepository(
        pinned: flow,
        completed: {'welcome', 'how_it_rings', 'connect'},
      ),
    );

    test('iOS resumes at /onboarding while AlarmKit is unanswered', () async {
      final h = connected(iPhone, permissions: false);
      expect((await h.engine.resume()).route, '/onboarding');
    });

    test('Android resumes at /onboarding without full-screen intent', () async {
      final h = connected(androidPhone, permissions: false);
      expect((await h.engine.resume()).route, '/onboarding');
    });

    test('Android resumes at the first topic with both granted', () async {
      final h = connected(androidPhone, permissions: true);
      expect((await h.engine.resume()).route, '/onboarding/first-topic');
    });
  });
}
