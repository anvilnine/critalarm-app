import 'package:critalarm/app/initial_route_resolver.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_onboarding_completed_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetConnectionUsecase extends Mock implements GetConnectionUsecase {}

class MockGetOnboardingCompletedUsecase extends Mock
    implements GetOnboardingCompletedUsecase {}

void main() {
  group('initialLocationFor', () {
    test('opens onboarding without connection or completion', () {
      expect(
        initialLocationFor(
          hasServerConnection: false,
          hasCompletedOnboarding: false,
        ),
        '/onboarding',
      );
    });

    test('opens home with saved connection', () {
      expect(
        initialLocationFor(
          hasServerConnection: true,
          hasCompletedOnboarding: false,
        ),
        '/',
      );
    });

    test('opens home after completed onboarding', () {
      expect(
        initialLocationFor(
          hasServerConnection: false,
          hasCompletedOnboarding: true,
        ),
        '/',
      );
    });

    test('a tapped incident notification opens that incident', () {
      expect(
        initialLocationFor(
          hasServerConnection: true,
          hasCompletedOnboarding: true,
          deepLink: '/incidents/inc_1',
        ),
        '/incidents/inc_1',
      );
    });

    test('a tapped topic notification opens that topic', () {
      expect(
        initialLocationFor(
          hasServerConnection: true,
          hasCompletedOnboarding: false,
          deepLink: '/topics/prod',
        ),
        '/topics/prod',
      );
    });

    test('onboarding still wins before there is a server', () {
      expect(
        initialLocationFor(
          hasServerConnection: false,
          hasCompletedOnboarding: false,
          deepLink: '/incidents/inc_1',
        ),
        '/onboarding',
      );
    });

    test('a route that is not a push deep link is ignored', () {
      for (final route in ['/', '/settings', 'nonsense', null]) {
        expect(
          initialLocationFor(
            hasServerConnection: true,
            hasCompletedOnboarding: true,
            deepLink: route,
          ),
          '/',
          reason: route ?? 'null',
        );
      }
    });

    test('opens home with connection and completed onboarding', () {
      expect(
        initialLocationFor(
          hasServerConnection: true,
          hasCompletedOnboarding: true,
        ),
        '/',
      );
    });
  });

  group('InitialRouteResolver', () {
    late MockGetConnectionUsecase getConnection;
    late MockGetOnboardingCompletedUsecase getOnboardingCompleted;

    setUp(() {
      getConnection = MockGetConnectionUsecase();
      getOnboardingCompleted = MockGetOnboardingCompletedUsecase();
    });

    test('treats failed lookups as false', () async {
      when(() => getConnection(const NoParams())).thenAnswer(
        (_) async => const Failure.notFound().toFailure(),
      );
      when(() => getOnboardingCompleted(const NoParams())).thenAnswer(
        (_) async => const Failure.unexpected().toFailure(),
      );

      final location = await InitialRouteResolver(
        getConnection,
        getOnboardingCompleted,
        platformRoute: () => '/',
      )();

      expect(location, '/onboarding');
    });

    test('uses successful connection and completion values', () async {
      when(() => getConnection(const NoParams())).thenAnswer(
        (_) async => const ServerConnection(
          serverUrl: 'https://alerts.example.com',
          adminToken: 'ad_token',
        ).toSuccess(),
      );
      when(() => getOnboardingCompleted(const NoParams())).thenAnswer(
        (_) async => true.toSuccess(),
      );

      final location = await InitialRouteResolver(
        getConnection,
        getOnboardingCompleted,
        platformRoute: () => '/',
      )();

      expect(location, '/');

      final deepLinked = await InitialRouteResolver(
        getConnection,
        getOnboardingCompleted,
        platformRoute: () => '/incidents/inc_1',
      )();

      expect(deepLinked, '/incidents/inc_1');
    });
  });
}
