import 'package:critalarm/app/initial_route_resolver.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/links/connect_link_holder.dart';
import 'package:critalarm/core/push/push_deep_link.dart';
import 'package:critalarm/core/push/push_host.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_onboarding_completed_usecase.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../features/onboarding/support/onboarding_flow_fakes.dart';

class MockGetOnboardingCompletedUsecase extends Mock
    implements GetOnboardingCompletedUsecase {}

void main() {
  group('a link that starts the app while setup is unfinished', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel(PushHost.channelName);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late ConnectLinkHolder holder;
    late PushHost host;

    void platformHolds(String link) {
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'takePending'
            ? {
                'tap': {PushHost.linkKey: link, 'tap_id': '1'},
              }
            : null,
      );
    }

    setUp(() {
      holder = ConnectLinkHolder();
      host = PushHost(null, holder);
    });

    tearDown(() async {
      await host.dispose();
      await holder.dispose();
      messenger.setMockMethodCallHandler(channel, null);
    });

    test('a connect link fills the holder and setup resumes where it '
        'was', () async {
      platformHolds(
        'https://critalarm.app/connect#url=https%3A%2F%2Falarm.example.com&token=tk_x',
      );
      final tapped = await host.takePendingRoute();
      expect(tapped, isNull);
      expect(
        initialLocationFor(
          hasCompletedOnboarding: false,
          resumeRoute: '/onboarding/connect',
          deepLink: tapped,
        ),
        '/onboarding/connect',
      );
      expect(holder.pending?.serverUrl.host, 'alarm.example.com');
    });

    test('a topic link is ignored and setup resumes where it was', () async {
      platformHolds('https://critalarm.app/open/topics/prod');
      final tapped = await host.takePendingRoute();
      expect(tapped, '/topics/prod');
      expect(
        initialLocationFor(
          hasCompletedOnboarding: false,
          resumeRoute: '/onboarding/connect',
          deepLink: tapped,
        ),
        '/onboarding/connect',
      );
      expect(holder.pending, isNull);
    });
  });

  group('initialLocationFor', () {
    test('opens onboarding at the welcome screen when nothing is saved', () {
      expect(
        initialLocationFor(hasCompletedOnboarding: false),
        '/onboarding/welcome',
      );
    });

    test('opens the route the flow engine resumes at', () {
      expect(
        initialLocationFor(
          hasCompletedOnboarding: false,
          resumeRoute: '/onboarding/connect',
        ),
        '/onboarding/connect',
      );
      expect(
        initialLocationFor(
          hasCompletedOnboarding: false,
          resumeRoute: '/onboarding/real-ring',
        ),
        '/onboarding/real-ring',
      );
    });

    test('a saved server alone does not end onboarding', () {
      // The connection is written before the alarm test runs, so treating it
      // as "finished" used to skip the rest of onboarding for good.
      expect(
        initialLocationFor(
          hasCompletedOnboarding: false,
          resumeRoute: '/onboarding/real-ring',
        ),
        isNot('/'),
      );
    });

    test('opens home after completed onboarding', () {
      expect(initialLocationFor(hasCompletedOnboarding: true), '/');
    });

    test('a tapped incident notification opens that incident', () {
      expect(
        initialLocationFor(
          hasCompletedOnboarding: true,
          deepLink: '/incidents/inc_1',
        ),
        '/incidents/inc_1',
      );
    });

    test('a tapped topic notification opens that topic', () {
      expect(
        initialLocationFor(
          hasCompletedOnboarding: true,
          deepLink: '/topics/prod',
        ),
        '/topics/prod',
      );
    });

    test('onboarding still wins over a deep link', () {
      expect(
        initialLocationFor(
          hasCompletedOnboarding: false,
          resumeRoute: '/onboarding/connect',
          deepLink: '/incidents/inc_1',
        ),
        '/onboarding/connect',
      );
    });

    test('home is a deep link, for the open count widget', () {
      expect(isPushDeepLink('/'), isTrue);
      expect(
        initialLocationFor(hasCompletedOnboarding: true, deepLink: '/'),
        '/',
      );
    });

    test('a locked widget tap opens the paywall', () {
      expect(isPushDeepLink(PushDeepLink.paywallLocation), isTrue);
      expect(
        initialLocationFor(
          hasCompletedOnboarding: true,
          deepLink: PushDeepLink.paywallLocation,
        ),
        '/paywall?source=widget_locked',
      );
    });

    test('a link to the Reliability screen opens it', () {
      expect(isPushDeepLink('/settings/reliability'), isTrue);
      expect(
        initialLocationFor(
          hasCompletedOnboarding: true,
          deepLink: '/settings/reliability',
        ),
        '/settings/reliability',
      );
      expect(
        initialLocationFor(
          hasCompletedOnboarding: false,
          deepLink: '/settings/reliability',
        ),
        '/onboarding/welcome',
      );
    });

    test('Settings itself is not a push deep link', () {
      expect(isPushDeepLink('/settings'), isFalse);
    });

    test('a route that is not a push deep link is ignored', () {
      for (final route in [
        '/settings/privacy',
        '/settings/developer',
        'nonsense',
        '//',
        null,
      ]) {
        expect(
          initialLocationFor(
            hasCompletedOnboarding: true,
            deepLink: route,
          ),
          '/',
          reason: route ?? 'null',
        );
      }
    });
  });

  group('InitialRouteResolver', () {
    late MockGetOnboardingCompletedUsecase getOnboardingCompleted;

    setUp(() {
      getOnboardingCompleted = MockGetOnboardingCompletedUsecase();
    });

    void completedIs({required bool value}) =>
        when(() => getOnboardingCompleted(const NoParams())).thenAnswer(
          (_) async => value.toSuccess(),
        );

    InitialRouteResolver resolver(
      EngineHarness h, {
      String platformRoute = '/',
    }) => InitialRouteResolver(
      getOnboardingCompleted,
      h.engine,
      platformRoute: () => platformRoute,
    );

    test('treats a failed lookup as unfinished onboarding', () async {
      when(() => getOnboardingCompleted(const NoParams())).thenAnswer(
        (_) async => const Failure.unexpected().toFailure(),
      );

      expect(await resolver(EngineHarness())(), '/onboarding/welcome');
    });

    test('a fresh install opens the welcome', () async {
      completedIs(value: false);

      expect(await resolver(EngineHarness())(), '/onboarding/welcome');
    });

    test('resumes at the first open step of the pinned flow', () async {
      completedIs(value: false);
      final h = EngineHarness(
        facts: FakeOnboardingStepFacts(connected: true),
        repository: FakeOnboardingFlowRepository(
          pinned: BundledOnboardingFlows.defaultFlow,
          completed: {'welcome', 'how_it_rings'},
        ),
      );

      expect(await resolver(h)(), '/onboarding');
    });

    test('a tapped notification does not cut setup short', () async {
      completedIs(value: false);
      final h = EngineHarness(
        repository: FakeOnboardingFlowRepository(
          pinned: BundledOnboardingFlows.defaultFlow,
          completed: {'welcome', 'how_it_rings'},
        ),
      );

      expect(
        await resolver(h, platformRoute: '/incidents/inc_1')(),
        '/onboarding/connect',
      );
    });

    test('places a user who was halfway through the old order', () async {
      completedIs(value: false);
      final h = EngineHarness(
        facts: FakeOnboardingStepFacts(connected: true, permissions: true),
        repository: FakeOnboardingFlowRepository(legacyStep: 'test'),
      );

      expect(await resolver(h)(), '/onboarding/first-topic');
    });

    test('no step left completes setup and opens Home', () async {
      completedIs(value: false);
      final h = EngineHarness(
        facts: FakeOnboardingStepFacts(
          connected: true,
          permissions: true,
          ownsTopic: true,
        ),
        repository: FakeOnboardingFlowRepository(
          pinned: BundledOnboardingFlows.defaultFlow,
          completed: {'welcome', 'how_it_rings', 'real_ring', 'hook_up'},
        ),
      );

      expect(
        await resolver(h, platformRoute: '/incidents/inc_1')(),
        '/incidents/inc_1',
      );
      expect(h.progress.completed, isTrue);
    });

    test('a finished user lands home, and a deep link still wins', () async {
      completedIs(value: true);
      final h = EngineHarness();

      expect(await resolver(h)(), '/');
      expect(
        await resolver(h, platformRoute: '/incidents/inc_1')(),
        '/incidents/inc_1',
      );
      // Setup is over, so the engine is not asked and nothing is written.
      expect(h.events, isEmpty);
      expect(h.repository.writes, 0);
    });
  });
}
