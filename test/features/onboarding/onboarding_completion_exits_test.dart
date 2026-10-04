import 'package:critalarm/core/models/server_info.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/incidents/domain/setup_test_kind.dart';
import 'package:critalarm/features/onboarding/data/repositories/prefs_setup_test_ring.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_engine.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_source.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_step_catalog.dart';
import 'package:critalarm/features/onboarding/domain/usecases/complete_onboarding_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/establish_api_session_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_onboarding_completed_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_server_info_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/save_connection_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/set_up_later_usecase.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_connect_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/flow/onboarding_step_registry.dart';
import 'package:critalarm/features/topics/data/prefs_first_topic_handoff.dart';
import 'package:critalarm/features/topics/domain/first_topic_handoff.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/onboarding_flow_fakes.dart';

class _MockGetServerInfo extends Mock implements GetServerInfoUsecase {}

class _MockSaveConnection extends Mock implements SaveConnectionUsecase {}

class _MockEstablishSession extends Mock
    implements EstablishApiSessionUsecase {}

/// Every step has a screen and none is already true, so the flow alone
/// decides what comes next. This is the registry once the step after the
/// real ring has its screen.
class _EveryStepCatalog implements OnboardingStepCatalog {
  @override
  Map<String, Set<String>> get requires => OnboardingStepRegistry.requiresById;

  @override
  bool isAvailable(String stepId) => true;

  @override
  Future<bool> isSatisfied(String stepId) async => false;

  @override
  String? routeOf(String stepId) => '/onboarding/$stepId';
}

/// Counts how often setup was completed.
class _Completion {
  _Completion(FakeOnboardingFlowRepository flow) {
    usecase = CompleteOnboardingUsecase(progress, flow, () => calls++);
  }

  final progress = FakeOnboardingProgressRepository();
  late final CompleteOnboardingUsecase usecase;
  int calls = 0;
}

void main() {
  const withHookUp = OnboardingFlow(
    id: '2026-10-b',
    steps: [
      OnboardingStepId.welcome,
      OnboardingStepId.howItRings,
      OnboardingStepId.connect,
      OnboardingStepId.permissions,
      OnboardingStepId.firstTopic,
      OnboardingStepId.realRing,
      OnboardingStepId.hookUp,
    ],
  );

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://api.critalarm.app'));
    registerFallbackValue(const NoParams());
    registerFallbackValue(
      const ServerConnection(serverUrl: '', adminToken: ''),
    );
    registerFallbackValue(
      const ServerInfo(
        version: '0.1.0',
        baseUrl: 'https://api.critalarm.app',
        relayUrl: 'https://relay.critalarm.app',
      ),
    );
  });

  /// An engine on [flow] with every step before the real ring done.
  ({OnboardingFlowEngine engine, _Completion completion}) engineOn(
    OnboardingFlow flow, {
    OnboardingStepCatalog? catalog,
  }) {
    final repository = FakeOnboardingFlowRepository(
      pinned: flow,
      completed: {
        for (final step in flow.steps)
          if (step != OnboardingStepId.realRing &&
              step != OnboardingStepId.hookUp &&
              step != OnboardingStepId.legacyTest)
            step,
      },
    );
    final completion = _Completion(repository);
    final engine = OnboardingFlowEngine(
      sources: const [BundledOnboardingFlowSource()],
      catalog:
          catalog ??
          OnboardingStepRegistry(
            on: iPhone,
            facts: FakeOnboardingStepFacts(
              connected: true,
              permissions: true,
              ownsTopic: true,
            ),
          ),
      repository: repository,
      completeOnboarding: completion.usecase,
      getOnboardingCompleted: GetOnboardingCompletedUsecase(
        completion.progress,
      ),
    );
    return (engine: engine, completion: completion);
  }

  group('Continue on the It works screen', () {
    test('is what a setup run on 2026-10-a shows, for both tests', () {
      const flow = BundledOnboardingFlows.defaultFlow;
      expect(flow.id, '2026-10-a');
      for (final kind in [SetupTestKind.serverSent, SetupTestKind.phoneOnly]) {
        final exits = ackedExitsFor(
          kind: kind,
          isOnboardingDone: false,
          flowHasRealRing: flow.contains(OnboardingStepId.realRing),
          hasOwnedTopic: true,
        );
        expect(exits, AckedExits.continueSetup);
        expect(exits.completesSetup, isFalse);
      }
    });

    test('does not complete setup while a step is left', () async {
      final run = engineOn(withHookUp, catalog: _EveryStepCatalog());

      final next = await run.engine.finishStep(OnboardingStepId.realRing);

      expect(next.stepId, OnboardingStepId.hookUp);
      expect(next.isHome, isFalse);
      expect(run.completion.calls, 0);
      expect(run.completion.progress.completed, isFalse);
    });

    test(
      'lets the engine finish when the real ring is the last step',
      () async {
        // The bundled flow today: the step after the ring has no screen yet.
        final run = engineOn(BundledOnboardingFlows.defaultFlow);

        final next = await run.engine.finishStep(OnboardingStepId.realRing);

        expect(next.isHome, isTrue);
        expect(run.completion.calls, 1);
      },
    );
  });

  group('Set this up later', () {
    test('completes setup', () async {
      final completion = _Completion(FakeOnboardingFlowRepository());

      final result = await SetUpLaterUsecase(completion.usecase)();

      expect(result.isSuccess(), isTrue);
      expect(completion.calls, 1);
      expect(completion.progress.completed, isTrue);
    });

    test('forgets the pinned flow, the topic and the test incident', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final handoff = PrefsFirstTopicHandoff(prefs);
      final ring = PrefsSetupTestRing(prefs);
      await handoff.hold(
        const FirstTopicHandoffEntry(
          topicName: 'setup-test',
          serverUrl: 'https://api.critalarm.app',
          token: 'tk_secret',
        ),
      );
      await ring.hold('inc_7');
      final flow = FakeOnboardingFlowRepository(
        pinned: BundledOnboardingFlows.defaultFlow,
        completed: {OnboardingStepId.welcome},
      );
      final progress = FakeOnboardingProgressRepository();

      await SetUpLaterUsecase(
        CompleteOnboardingUsecase(progress, flow, null, handoff, ring),
      )();

      expect(progress.completed, isTrue);
      expect(flow.pinned, isNull);
      expect(handoff.entry, isNull);
      expect(handoff.savedTopicName, isNull);
      expect(ring.incidentId, isNull);
      expect(prefs.getString(PrefsSetupTestRing.incidentIdKey), isNull);
    });

    test('the exit on the connect and test screens goes through it', () async {
      final completion = _Completion(FakeOnboardingFlowRepository());
      final cubit = OnboardingConnectCubit(
        _MockGetServerInfo(),
        _MockSaveConnection(),
        establishSession: _MockEstablishSession(),
        setUpLater: SetUpLaterUsecase(completion.usecase),
      );

      await cubit.navigateToHome();

      expect(completion.calls, 1);
      expect(cubit.state.canNavigateToHome, isTrue);
      await cubit.close();
    });
  });

  group('legacy-1', () {
    test('keeps both exits, and both complete setup', () {
      const flow = BundledOnboardingFlows.legacy;
      expect(flow.contains(OnboardingStepId.realRing), isFalse);
      final exits = ackedExitsFor(
        kind: SetupTestKind.phoneOnly,
        isOnboardingDone: false,
        flowHasRealRing: flow.contains(OnboardingStepId.realRing),
        hasOwnedTopic: false,
      );
      expect(exits, AckedExits.legacyCreateTopicOrFinish);
      expect(exits.completesSetup, isTrue);
    });

    test('with a topic already made, Finish completes setup', () {
      final exits = ackedExitsFor(
        kind: SetupTestKind.phoneOnly,
        isOnboardingDone: false,
        flowHasRealRing: false,
        hasOwnedTopic: true,
      );
      expect(exits, AckedExits.legacyFinish);
      expect(exits.completesSetup, isTrue);
    });
  });

  group('a replay', () {
    test('Set this up later completes nothing', () async {
      final completion = _Completion(FakeOnboardingFlowRepository());

      final result = await SetUpLaterUsecase(completion.usecase)(
        isReplay: true,
      );

      expect(result.isSuccess(), isTrue);
      expect(completion.calls, 0);
      expect(completion.progress.completed, isFalse);
    });

    test(
      'the exit on the connect and test screens completes nothing',
      () async {
        final completion = _Completion(FakeOnboardingFlowRepository());
        final cubit = OnboardingConnectCubit(
          _MockGetServerInfo(),
          _MockSaveConnection(),
          establishSession: _MockEstablishSession(),
          setUpLater: SetUpLaterUsecase(completion.usecase),
        );

        await cubit.navigateToHome(isReplay: true);

        expect(completion.calls, 0);
        expect(cubit.state.canNavigateToHome, isTrue);
        await cubit.close();
      },
    );

    test('finishing the real ring step saves and completes nothing', () async {
      final run = engineOn(withHookUp, catalog: _EveryStepCatalog());
      final before = run.engine.repository.read().completed;

      await run.engine.finishStep(OnboardingStepId.realRing, isReplay: true);

      expect(run.completion.calls, 0);
      expect(run.engine.repository.read().completed, before);
    });

    test('its test alarm ends on the one way out', () {
      // A replay runs after setup, so the alarm it rings is a test run again.
      final exits = ackedExitsFor(
        kind: SetupTestKind.phoneOnly,
        isOnboardingDone: true,
        flowHasRealRing: true,
        hasOwnedTopic: true,
      );
      expect(exits, AckedExits.retest);
      expect(exits.completesSetup, isFalse);
    });
  });
}
