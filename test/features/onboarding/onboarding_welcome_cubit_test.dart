import 'package:bloc_test/bloc_test.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/server_info.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_server_info_usecase.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_welcome_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_welcome_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetServerInfoUsecase extends Mock implements GetServerInfoUsecase {}

void main() {
  late MockGetServerInfoUsecase mockGetServerInfo;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://api.critalarm.app'));
    registerFallbackValue(const NoParams());
  });

  setUp(() {
    mockGetServerInfo = MockGetServerInfoUsecase();
  });

  group('OnboardingWelcomeCubit', () {
    test('initial state has default server URL and no error', () async {
      final cubit = OnboardingWelcomeCubit(mockGetServerInfo);
      expect(cubit.state.serverUrl, 'https://api.critalarm.app');
      expect(cubit.state.isValidating, isFalse);
      expect(cubit.state.errorMessage, isNull);
      expect(cubit.state.canNavigate, isFalse);
      await cubit.close();
    });

    blocTest<OnboardingWelcomeCubit, OnboardingWelcomeState>(
      'serverUrlChanged updates url and resets canNavigate',
      build: () => OnboardingWelcomeCubit(mockGetServerInfo),
      act: (cubit) => cubit.serverUrlChanged('https://alerts.mybox.local'),
      expect: () => [
        const OnboardingWelcomeState(serverUrl: 'https://alerts.mybox.local'),
      ],
    );

    blocTest<OnboardingWelcomeCubit, OnboardingWelcomeState>(
      'validateAndContinue with empty URL emits validation error',
      build: () => OnboardingWelcomeCubit(mockGetServerInfo),
      seed: () => const OnboardingWelcomeState(serverUrl: '   '),
      act: (cubit) => cubit.validateAndContinue(),
      expect: () => [
        const OnboardingWelcomeState(
          serverUrl: '   ',
          errorMessage: 'Server URL cannot be empty',
        ),
      ],
    );

    blocTest<OnboardingWelcomeCubit, OnboardingWelcomeState>(
      'validateAndContinue with malformed URL emits invalid url error',
      build: () => OnboardingWelcomeCubit(mockGetServerInfo),
      seed: () => const OnboardingWelcomeState(serverUrl: 'not a valid url'),
      act: (cubit) => cubit.validateAndContinue(),
      expect: () => [
        const OnboardingWelcomeState(
          serverUrl: 'not a valid url',
          errorMessage: 'Enter a valid URL (e.g. https://api.critalarm.app)',
        ),
      ],
    );

    blocTest<OnboardingWelcomeCubit, OnboardingWelcomeState>(
      'validateAndContinue with valid URL succeeds and sets canNavigate to '
      'true',
      setUp: () {
        const info = ServerInfo(
          version: '0.1.0',
          baseUrl: 'https://api.critalarm.app',
          relayUrl: 'https://relay.critalarm.app',
        );
        when(
          () => mockGetServerInfo(any()),
        ).thenAnswer((_) async => info.toSuccess());
      },
      build: () => OnboardingWelcomeCubit(mockGetServerInfo),
      act: (cubit) => cubit.validateAndContinue(),
      expect: () => [
        const OnboardingWelcomeState(isValidating: true),
        const OnboardingWelcomeState(canNavigate: true),
      ],
    );

    blocTest<OnboardingWelcomeCubit, OnboardingWelcomeState>(
      'validateAndContinue when server check fails emits error message',
      setUp: () {
        when(() => mockGetServerInfo(any())).thenAnswer(
          (_) async => const Failure.api(
            statusCode: 502,
            message: 'Bad Gateway',
          ).toFailure(),
        );
      },
      build: () => OnboardingWelcomeCubit(mockGetServerInfo),
      act: (cubit) => cubit.validateAndContinue(),
      expect: () => [
        const OnboardingWelcomeState(isValidating: true),
        const OnboardingWelcomeState(errorMessage: 'Bad Gateway'),
      ],
    );

    blocTest<OnboardingWelcomeCubit, OnboardingWelcomeState>(
      'navigationHandled clears canNavigate',
      build: () => OnboardingWelcomeCubit(mockGetServerInfo),
      seed: () => const OnboardingWelcomeState(canNavigate: true),
      act: (cubit) => cubit.navigationHandled(),
      expect: () => [
        const OnboardingWelcomeState(),
      ],
    );
  });
}
