import 'package:critalarm/features/in_app_notices/domain/repositories/in_app_notice_repository.dart';
import 'package:critalarm/features/onboarding/data/repositories/shared_prefs_onboarding_flow_repository.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_engine.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_step_facts.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:critalarm/features/onboarding/presentation/flow/onboarding_step_registry.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_navigation.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/features/topics/domain/first_message/first_message_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/onboarding_flow_fakes.dart';
import 'support/permission_setup_fakes.dart';

class _NoConnection extends Mock implements GetConnectionUsecase {}

class _NoNotices extends Mock implements InAppNoticeRepository {}

class _NoFirstMessage extends Mock implements FirstMessageStore {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const flow = BundledOnboardingFlows.defaultFlow;

  // A phone where setup is over.
  EngineHarness finished({bool connected = false}) {
    final h = EngineHarness(
      facts: FakeOnboardingStepFacts(connected: connected),
    );
    h.progress.completed = true;
    return h;
  }

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

    test('hook_up in a custom list is shown in its place', () async {
      final h = EngineHarness(
        repository: FakeOnboardingFlowRepository(
          pinned: const OnboardingFlow(
            id: 'custom',
            steps: ['welcome', 'connect', 'first_topic', 'hook_up', 'widgets'],
          ),
          completed: {'welcome', 'connect', 'first_topic'},
        ),
      );

      expect((await h.engine.resume()).stepId, 'hook_up');
    });

    test('hook_up is passed over once a first message was received', () async {
      final h = EngineHarness(
        facts: FakeOnboardingStepFacts(firstMessage: true),
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
          completed: {'welcome', 'how_it_rings', 'real_ring', 'hook_up'},
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
        '/onboarding/hook-up',
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
        '/onboarding/hook-up',
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

  group('a pinned flow is checked again when it is read', () {
    test('an empty list does not complete setup', () async {
      final h = EngineHarness(
        facts: FakeOnboardingStepFacts(connected: true),
        repository: FakeOnboardingFlowRepository(
          pinned: const OnboardingFlow(id: 'gone', steps: []),
          completed: {'welcome', 'how_it_rings'},
        ),
      );

      final next = await h.engine.resume();

      expect(next.route, '/onboarding');
      expect(h.progress.completed, isFalse);
      expect(h.repository.pinned, BundledOnboardingFlows.defaultFlow);
      expect(h.repository.completed, {'welcome', 'how_it_rings'});
    });

    test('a list of nothing but unknown ids does not complete setup', () async {
      final h = EngineHarness(
        repository: FakeOnboardingFlowRepository(
          pinned: const OnboardingFlow(
            id: 'old',
            steps: ['renamed_one', 'renamed_two'],
          ),
          completed: {'welcome'},
        ),
      );

      final next = await h.engine.resume();

      expect(next.route, '/onboarding/how-it-rings');
      expect(h.progress.completed, isFalse);
      expect(h.repository.pinned, BundledOnboardingFlows.defaultFlow);
      expect(h.repository.completed, {'welcome'});
    });

    test('one unknown id is dropped and the rest of the list kept', () async {
      final h = EngineHarness(
        repository: FakeOnboardingFlowRepository(
          pinned: const OnboardingFlow(
            id: 'custom',
            steps: ['welcome', 'renamed', 'connect', 'permissions'],
          ),
          completed: {'welcome'},
        ),
      );

      final next = await h.engine.resume();

      expect(next.stepId, 'connect');
      expect(h.repository.pinned?.id, 'custom');
      expect(h.repository.pinned?.steps, ['welcome', 'connect', 'permissions']);
      expect(h.repository.completed, {'welcome'});
    });

    test('a saved order the validator rejects falls to the default', () async {
      final h = EngineHarness(
        repository: FakeOnboardingFlowRepository(
          pinned: const OnboardingFlow(
            id: 'broken',
            steps: ['welcome', 'first_topic', 'connect'],
          ),
          completed: {'welcome'},
        ),
      );

      await h.engine.finishStep('how_it_rings');

      expect(h.repository.pinned, BundledOnboardingFlows.defaultFlow);
      expect(h.repository.completed, {'welcome', 'how_it_rings'});
    });

    test('a valid pin is left alone', () async {
      final repository = FakeOnboardingFlowRepository(
        pinned: BundledOnboardingFlows.legacy,
        completed: {'welcome'},
      );
      final h = EngineHarness(repository: repository);

      await h.engine.resume();

      expect(repository.writes, 0);
    });
  });

  group('after setup is complete', () {
    test('finishing a step writes no flow keys and goes back', () async {
      for (final step in ['connect', 'legacy_test', 'real_ring', 'welcome']) {
        final h = finished(connected: true);

        final next = await h.engine.finishStep(step);

        expect(next.isBack, isTrue, reason: step);
        expect(next.isHome, isFalse, reason: step);
        expect(next.route, isNull, reason: step);
        expect(h.repository.writes, 0, reason: step);
        expect(h.repository.pinned, isNull, reason: step);
        expect(h.repository.completed, isEmpty, reason: step);
        expect(h.events, isEmpty, reason: step);
      }
    });

    test('on real prefs, connecting late leaves no flow key behind', () async {
      SharedPreferences.setMockInitialValues({'onboarding_completed': true});
      final prefs = await SharedPreferences.getInstance();
      final h = EngineHarness(
        store: SharedPrefsOnboardingFlowRepository(prefs),
      );
      h.progress.completed = true;

      await h.engine.finishStep('connect');

      expect(prefs.getKeys(), {'onboarding_completed'});
    });

    test('a replay is still a replay', () async {
      final h = finished(connected: true);

      final next = await h.engine.finishStep('welcome', isReplay: true);

      expect(next.route, '/onboarding/how-it-rings');
      expect(h.repository.writes, 0);
    });
  });

  group('the screens opened on their own', () {
    test('Server settings and the Home card open the connect step', () {
      expect(
        OnboardingEntryPoint.connectServer,
        OnboardingStepRegistry.entryFor('connect')!.route,
      );
    });

    test('Health opens the test alarm, not the connect step', () {
      expect(
        OnboardingEntryPoint.testAlarm,
        OnboardingStepRegistry.entryFor('legacy_test')!.route,
      );
      expect(
        OnboardingEntryPoint.testAlarm,
        isNot(OnboardingEntryPoint.connectServer),
      );
    });

    // Where each of the three ends up once its step is finished. All three
    // are pushed, so there is a screen under them to go back to.
    for (final (name, entry, step, from) in [
      (
        'Server settings',
        OnboardingEntryPoint.connectServer,
        'connect',
        '/settings/server',
      ),
      (
        'the no-server card on Home',
        OnboardingEntryPoint.connectServer,
        'connect',
        '/',
      ),
      (
        'Health',
        OnboardingEntryPoint.testAlarm,
        'legacy_test',
        '/settings/permissions',
      ),
    ]) {
      test('$name: closes back to $from, never into setup', () async {
        final h = finished(connected: true);
        final here = Uri.parse(entry);

        final move = onboardingMoveFor(
          await h.engine.finishStep(step),
          isReplay: false,
          canPop: true,
          locationBefore: here,
          locationNow: here,
        );

        expect(move, const OnboardingMove.pop());
        expect(h.repository.writes, 0);
      });
    }

    test('with nothing under the screen it opens Home', () async {
      final h = finished();
      final here = Uri.parse(OnboardingEntryPoint.connectServer);

      final move = onboardingMoveFor(
        await h.engine.finishStep('connect'),
        isReplay: false,
        canPop: false,
        locationBefore: here,
        locationNow: here,
      );

      expect(move, const OnboardingMove.go('/'));
    });
  });

  group('onboardingMoveFor', () {
    final connect = Uri.parse('/onboarding/connect');
    const next = OnboardingDestination.step('permissions', '/onboarding');

    OnboardingMove move(
      OnboardingDestination destination, {
      bool isReplay = false,
      bool canPop = false,
      Uri? now,
    }) => onboardingMoveFor(
      destination,
      isReplay: isReplay,
      canPop: canPop,
      locationBefore: connect,
      locationNow: now ?? connect,
    );

    test('opens the next step', () {
      expect(move(next), const OnboardingMove.go('/onboarding'));
    });

    test('a replay carries its flag on', () {
      expect(
        move(next, isReplay: true),
        const OnboardingMove.go('/onboarding?demo=true'),
      );
    });

    test('setup complete opens Home, even when something could pop', () {
      expect(
        move(const OnboardingDestination.home(), canPop: true),
        const OnboardingMove.go('/'),
      );
    });

    test('does nothing when the user left the step meanwhile', () {
      for (final destination in [
        next,
        const OnboardingDestination.home(),
        const OnboardingDestination.back(),
      ]) {
        expect(
          move(destination, canPop: true, now: Uri.parse('/')),
          const OnboardingMove.stay(),
        );
      }
    });

    test('a changed query counts as having moved', () {
      expect(
        move(next, now: Uri.parse('/onboarding/connect?demo=true')),
        const OnboardingMove.stay(),
      );
    });
  });

  group('the permissions step is satisfied', () {
    // The engine asks the same reader the permissions screen draws from,
    // so "satisfied" and "nothing left to show" are one answer.
    Future<bool> satisfied(PermissionPhone phone) => DeviceOnboardingStepFacts(
      on: OnboardingPlatform(platform: phone.platform, isWeb: phone.isWeb),
      getConnection: _NoConnection(),
      readPermissionSetup: phone.read,
      notices: _NoNotices(),
      firstMessage: _NoFirstMessage(),
    ).hasEveryPermission();

    test('never without notifications', () async {
      final ios = PermissionPhone.ios26(alarmStatus: 'authorized');
      final android = PermissionPhone.android()
        ..device.grant(DevicePermissionType.fullScreenIntent);

      expect(await satisfied(ios), isFalse);
      expect(await satisfied(android), isFalse);
    });

    test('iOS 26: only once AlarmKit is authorized', () async {
      for (final (status, expected) in [
        ('notDetermined', false),
        ('denied', false),
        ('authorized', true),
      ]) {
        final phone = PermissionPhone.ios26(alarmStatus: status)
          ..grantNotifications();
        expect(await satisfied(phone), expected, reason: status);
      }
    });

    test('iOS 16 to 25: on notifications alone', () async {
      final phone = PermissionPhone.iosOld()..grantNotifications();
      expect(await satisfied(phone), isTrue);
    });

    test('Android: needs the full-screen intent permission too', () async {
      final phone = PermissionPhone.android()..grantNotifications();
      expect(await satisfied(phone), isFalse);

      phone.device.grant(DevicePermissionType.fullScreenIntent);
      expect(await satisfied(phone), isTrue);
    });

    test(
      'Android on a listed maker: needs the battery exemption too',
      () async {
        final phone = PermissionPhone.android(maker: samsung)
          ..grantNotifications()
          ..device.grant(DevicePermissionType.fullScreenIntent);
        expect(await satisfied(phone), isFalse);

        phone.device.grant(DevicePermissionType.batteryOptimization);
        expect(await satisfied(phone), isTrue);
      },
    );

    test('Android on a Pixel: the battery exemption does not count', () async {
      final phone = PermissionPhone.android()
        ..grantNotifications()
        ..device.grant(DevicePermissionType.fullScreenIntent);
      expect(await satisfied(phone), isTrue);
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
