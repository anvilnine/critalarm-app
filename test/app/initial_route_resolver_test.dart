import 'package:critalarm/app/initial_route_resolver.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/entities/onboarding_draft.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_onboarding_completed_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/onboarding_draft_usecases.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetOnboardingCompletedUsecase extends Mock
    implements GetOnboardingCompletedUsecase {}

class MockReadOnboardingDraftUsecase extends Mock
    implements ReadOnboardingDraftUsecase {}

void main() {
  group('initialLocationFor', () {
    test('opens onboarding at step one when nothing is saved', () {
      expect(
        initialLocationFor(hasCompletedOnboarding: false),
        '/onboarding',
      );
    });

    test('resumes the step the user had reached', () {
      expect(
        initialLocationFor(
          hasCompletedOnboarding: false,
          step: OnboardingStep.connect,
        ),
        '/onboarding/connect',
      );
      expect(
        initialLocationFor(
          hasCompletedOnboarding: false,
          step: OnboardingStep.test,
        ),
        '/onboarding/connect',
      );
    });

    test('a saved server alone does not end onboarding', () {
      // The connection is written before the alarm test runs, so treating it
      // as "finished" used to skip the rest of onboarding for good.
      expect(
        initialLocationFor(
          hasCompletedOnboarding: false,
          step: OnboardingStep.test,
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
          step: OnboardingStep.connect,
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

    test('a route that is not a push deep link is ignored', () {
      for (final route in ['/settings', 'nonsense', '//', null]) {
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
    late MockReadOnboardingDraftUsecase readDraft;

    setUp(() {
      getOnboardingCompleted = MockGetOnboardingCompletedUsecase();
      readDraft = MockReadOnboardingDraftUsecase();
    });

    test('treats failed lookups as unfinished onboarding', () async {
      when(() => getOnboardingCompleted(const NoParams())).thenAnswer(
        (_) async => const Failure.unexpected().toFailure(),
      );
      when(() => readDraft(const NoParams())).thenAnswer(
        (_) async => const Failure.notFound().toFailure(),
      );

      final location = await InitialRouteResolver(
        getOnboardingCompleted,
        readDraft,
        platformRoute: () => '/',
      )();

      expect(location, '/onboarding');
    });

    test('resumes the saved step', () async {
      when(() => getOnboardingCompleted(const NoParams())).thenAnswer(
        (_) async => false.toSuccess(),
      );
      when(() => readDraft(const NoParams())).thenAnswer(
        (_) async => const OnboardingDraft(
          step: OnboardingStep.test,
        ).toSuccess(),
      );

      final location = await InitialRouteResolver(
        getOnboardingCompleted,
        readDraft,
        platformRoute: () => '/',
      )();

      expect(location, '/onboarding/connect');
    });

    test('a finished user lands home, and a deep link still wins', () async {
      when(() => getOnboardingCompleted(const NoParams())).thenAnswer(
        (_) async => true.toSuccess(),
      );
      when(() => readDraft(const NoParams())).thenAnswer(
        (_) async => const OnboardingDraft().toSuccess(),
      );

      expect(
        await InitialRouteResolver(
          getOnboardingCompleted,
          readDraft,
          platformRoute: () => '/',
        )(),
        '/',
      );

      expect(
        await InitialRouteResolver(
          getOnboardingCompleted,
          readDraft,
          platformRoute: () => '/incidents/inc_1',
        )(),
        '/incidents/inc_1',
      );
    });
  });
}
