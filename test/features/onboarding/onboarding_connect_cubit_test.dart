import 'package:bloc_test/bloc_test.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/server_info.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/trigger_test_alarm_usecase.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/onboarding/domain/usecases/complete_onboarding_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_server_info_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/save_connection_usecase.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_connect_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_connect_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetServerInfoUsecase extends Mock implements GetServerInfoUsecase {}

class MockSaveConnectionUsecase extends Mock implements SaveConnectionUsecase {}

class MockCompleteOnboardingUsecase extends Mock
    implements CompleteOnboardingUsecase {}

class MockTriggerTestAlarmUsecase extends Mock
    implements TriggerTestAlarmUsecase {}

void main() {
  late MockGetServerInfoUsecase mockGetServerInfo;
  late MockSaveConnectionUsecase mockSaveConnection;
  late MockCompleteOnboardingUsecase mockCompleteOnboarding;
  late MockTriggerTestAlarmUsecase mockTriggerTestAlarm;

  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(
      const ServerConnection(serverUrl: '', adminToken: ''),
    );
  });

  setUp(() {
    mockGetServerInfo = MockGetServerInfoUsecase();
    mockSaveConnection = MockSaveConnectionUsecase();
    mockCompleteOnboarding = MockCompleteOnboardingUsecase();
    mockTriggerTestAlarm = MockTriggerTestAlarmUsecase();
  });

  group('OnboardingConnectCubit', () {
    test('initial state has default server URL and idle status', () async {
      final cubit = OnboardingConnectCubit(
        mockGetServerInfo,
        mockSaveConnection,
        mockTriggerTestAlarm,
      );
      expect(cubit.state.serverUrl, 'https://api.critalarm.app');
      expect(cubit.state.adminToken, isEmpty);
      expect(cubit.state.status, OnboardingConnectStatus.idle);
      expect(cubit.state.testAlarmStatus, TestAlarmStatus.idle);
      expect(cubit.state.isConnected, isFalse);
      await cubit.close();
    });

    blocTest<OnboardingConnectCubit, OnboardingConnectState>(
      'serverUrlChanged updates url and clears errors',
      build: () => OnboardingConnectCubit(
        mockGetServerInfo,
        mockSaveConnection,
        mockTriggerTestAlarm,
      ),
      seed: () => const OnboardingConnectState(
        serverUrlError: 'Invalid URL',
        errorMessage: 'Connection failed',
      ),
      act: (cubit) => cubit.serverUrlChanged('https://alerts.mybox.local'),
      expect: () => [
        const OnboardingConnectState(
          serverUrl: 'https://alerts.mybox.local',
        ),
      ],
    );

    blocTest<OnboardingConnectCubit, OnboardingConnectState>(
      'adminTokenChanged updates token and clears errors',
      build: () => OnboardingConnectCubit(
        mockGetServerInfo,
        mockSaveConnection,
        mockTriggerTestAlarm,
      ),
      seed: () => const OnboardingConnectState(
        adminTokenError: 'Required',
      ),
      act: (cubit) => cubit.adminTokenChanged('ad_secret_123'),
      expect: () => [
        const OnboardingConnectState(
          adminToken: 'ad_secret_123',
        ),
      ],
    );

    blocTest<OnboardingConnectCubit, OnboardingConnectState>(
      'pasteToken updates token from clipboard',
      build: () => OnboardingConnectCubit(
        mockGetServerInfo,
        mockSaveConnection,
        mockTriggerTestAlarm,
      ),
      act: (cubit) => cubit.pasteToken('ad_pasted_token'),
      expect: () => [
        const OnboardingConnectState(
          adminToken: 'ad_pasted_token',
        ),
      ],
    );

    blocTest<OnboardingConnectCubit, OnboardingConnectState>(
      'scanQrTapped emits placeholder notification notice',
      build: () => OnboardingConnectCubit(
        mockGetServerInfo,
        mockSaveConnection,
        mockTriggerTestAlarm,
      ),
      act: (cubit) => cubit.scanQrTapped(),
      expect: () => [
        const OnboardingConnectState(
          qrNotice: 'Scanning is not ready yet. Paste the token instead.',
        ),
      ],
    );

    blocTest<OnboardingConnectCubit, OnboardingConnectState>(
      'connect with empty URL emits serverUrlError',
      build: () => OnboardingConnectCubit(
        mockGetServerInfo,
        mockSaveConnection,
        mockTriggerTestAlarm,
      ),
      seed: () => const OnboardingConnectState(
        serverUrl: '   ',
        adminToken: 'ad_valid',
      ),
      act: (cubit) => cubit.connect(),
      expect: () => [
        const OnboardingConnectState(
          serverUrl: '   ',
          adminToken: 'ad_valid',
          serverUrlError: 'Server URL cannot be empty',
        ),
      ],
    );

    blocTest<OnboardingConnectCubit, OnboardingConnectState>(
      'connect with malformed URL emits serverUrlError',
      build: () => OnboardingConnectCubit(
        mockGetServerInfo,
        mockSaveConnection,
        mockTriggerTestAlarm,
      ),
      seed: () => const OnboardingConnectState(
        serverUrl: 'not_a_valid_url',
        adminToken: 'ad_valid',
      ),
      act: (cubit) => cubit.connect(),
      expect: () => [
        const OnboardingConnectState(
          serverUrl: 'not_a_valid_url',
          adminToken: 'ad_valid',
          serverUrlError: 'Enter a valid URL (e.g. https://api.critalarm.app)',
        ),
      ],
    );

    blocTest<OnboardingConnectCubit, OnboardingConnectState>(
      'connect with empty admin token emits adminTokenError',
      build: () => OnboardingConnectCubit(
        mockGetServerInfo,
        mockSaveConnection,
        mockTriggerTestAlarm,
      ),
      seed: () => const OnboardingConnectState(
        adminToken: '   ',
      ),
      act: (cubit) => cubit.connect(),
      expect: () => [
        const OnboardingConnectState(
          adminToken: '   ',
          adminTokenError: 'Admin token cannot be empty',
        ),
      ],
    );

    blocTest<OnboardingConnectCubit, OnboardingConnectState>(
      'connect when server call fails emits failure status and errorMessage',
      setUp: () {
        when(() => mockGetServerInfo(any())).thenAnswer(
          (_) async => const Failure.api(
            statusCode: 502,
            message: 'Bad Gateway',
          ).toFailure(),
        );
      },
      build: () => OnboardingConnectCubit(
        mockGetServerInfo,
        mockSaveConnection,
        mockTriggerTestAlarm,
      ),
      seed: () => const OnboardingConnectState(
        adminToken: 'ad_12345',
      ),
      act: (cubit) => cubit.connect(),
      expect: () => [
        const OnboardingConnectState(
          adminToken: 'ad_12345',
          status: OnboardingConnectStatus.connecting,
        ),
        const OnboardingConnectState(
          adminToken: 'ad_12345',
          status: OnboardingConnectStatus.failure,
          errorMessage: 'Bad Gateway',
        ),
      ],
    );

    blocTest<OnboardingConnectCubit, OnboardingConnectState>(
      'connect when server version has major >= 1 emits compatibility error',
      setUp: () {
        const incompatibleInfo = ServerInfo(
          version: '1.2.0',
          baseUrl: 'https://api.critalarm.app',
          relayUrl: 'https://relay.critalarm.app',
        );
        when(() => mockGetServerInfo(any())).thenAnswer(
          (_) async => incompatibleInfo.toSuccess(),
        );
      },
      build: () => OnboardingConnectCubit(
        mockGetServerInfo,
        mockSaveConnection,
        mockTriggerTestAlarm,
      ),
      seed: () => const OnboardingConnectState(
        adminToken: 'ad_12345',
      ),
      act: (cubit) => cubit.connect(),
      expect: () => [
        const OnboardingConnectState(
          adminToken: 'ad_12345',
          status: OnboardingConnectStatus.connecting,
        ),
        const OnboardingConnectState(
          adminToken: 'ad_12345',
          status: OnboardingConnectStatus.failure,
          errorMessage:
              'This app needs a v0.x server. Yours is 1.2.0.',
        ),
      ],
    );

    blocTest<OnboardingConnectCubit, OnboardingConnectState>(
      'connect when server version is unrecognized emits compatibility error',
      setUp: () {
        const unrecognizedInfo = ServerInfo(
          version: 'custom-build-xyz',
          baseUrl: 'https://api.critalarm.app',
          relayUrl: 'https://relay.critalarm.app',
        );
        when(() => mockGetServerInfo(any())).thenAnswer(
          (_) async => unrecognizedInfo.toSuccess(),
        );
      },
      build: () => OnboardingConnectCubit(
        mockGetServerInfo,
        mockSaveConnection,
        mockTriggerTestAlarm,
      ),
      seed: () => const OnboardingConnectState(
        adminToken: 'ad_12345',
      ),
      act: (cubit) => cubit.connect(),
      expect: () => [
        const OnboardingConnectState(
          adminToken: 'ad_12345',
          status: OnboardingConnectStatus.connecting,
        ),
        const OnboardingConnectState(
          adminToken: 'ad_12345',
          status: OnboardingConnectStatus.failure,
          errorMessage:
              'This app needs a v0.x server. Yours is custom-build-xyz.',
        ),
      ],
    );

    blocTest<OnboardingConnectCubit, OnboardingConnectState>(
      'connect when valid and semver major == 0 stores connection and succeeds',
      setUp: () {
        const compatibleInfo = ServerInfo(
          version: '0.1.0',
          baseUrl: 'https://api.critalarm.app',
          relayUrl: 'https://relay.critalarm.app',
        );
        when(() => mockGetServerInfo(any())).thenAnswer(
          (_) async => compatibleInfo.toSuccess(),
        );
        when(() => mockSaveConnection(any())).thenAnswer(
          (_) async => unit.toSuccess(),
        );
      },
      build: () => OnboardingConnectCubit(
        mockGetServerInfo,
        mockSaveConnection,
        mockTriggerTestAlarm,
      ),
      seed: () => const OnboardingConnectState(
        adminToken: 'ad_12345',
      ),
      act: (cubit) => cubit.connect(),
      expect: () => [
        const OnboardingConnectState(
          adminToken: 'ad_12345',
          status: OnboardingConnectStatus.connecting,
        ),
        const OnboardingConnectState(
          adminToken: 'ad_12345',
          status: OnboardingConnectStatus.connected,
        ),
      ],
      verify: (_) {
        verify(
          () => mockSaveConnection(
            const ServerConnection(
              serverUrl: 'https://api.critalarm.app',
              adminToken: 'ad_12345',
            ),
          ),
        ).called(1);
      },
    );

    blocTest<OnboardingConnectCubit, OnboardingConnectState>(
      'ringTestAlarm succeeds and emits ringing then success with incidentId',
      setUp: () {
        when(() => mockTriggerTestAlarm('prod-db')).thenAnswer(
          (_) async => 'inc_test_999'.toSuccess(),
        );
      },
      build: () => OnboardingConnectCubit(
        mockGetServerInfo,
        mockSaveConnection,
        mockTriggerTestAlarm,
      ),
      seed: () => const OnboardingConnectState(
        status: OnboardingConnectStatus.connected,
      ),
      act: (cubit) => cubit.ringTestAlarm(),
      expect: () => [
        const OnboardingConnectState(
          status: OnboardingConnectStatus.connected,
          testAlarmStatus: TestAlarmStatus.ringing,
        ),
        const OnboardingConnectState(
          status: OnboardingConnectStatus.connected,
          testAlarmStatus: TestAlarmStatus.success,
          incidentId: 'inc_test_999',
        ),
      ],
    );

    blocTest<OnboardingConnectCubit, OnboardingConnectState>(
      'ringTestAlarm failure emits ringing then failure with errorMessage',
      setUp: () {
        when(() => mockTriggerTestAlarm('prod-db')).thenAnswer(
          (_) async => const Failure.api(
            statusCode: 500,
            message: 'Server error',
          ).toFailure(),
        );
      },
      build: () => OnboardingConnectCubit(
        mockGetServerInfo,
        mockSaveConnection,
        mockTriggerTestAlarm,
      ),
      seed: () => const OnboardingConnectState(
        status: OnboardingConnectStatus.connected,
      ),
      act: (cubit) => cubit.ringTestAlarm(),
      expect: () => [
        const OnboardingConnectState(
          status: OnboardingConnectStatus.connected,
          testAlarmStatus: TestAlarmStatus.ringing,
        ),
        const OnboardingConnectState(
          status: OnboardingConnectStatus.connected,
          testAlarmStatus: TestAlarmStatus.failure,
          errorMessage: 'Server error',
        ),
      ],
    );

    blocTest<OnboardingConnectCubit, OnboardingConnectState>(
      'navigateToHome marks onboarding complete before requesting navigation',
      setUp: () {
        when(() => mockCompleteOnboarding(any())).thenAnswer(
          (_) async => unit.toSuccess(),
        );
      },
      build: () => OnboardingConnectCubit(
        mockGetServerInfo,
        mockSaveConnection,
        mockTriggerTestAlarm,
        completeOnboarding: mockCompleteOnboarding,
      ),
      act: (cubit) => cubit.navigateToHome(),
      expect: () => [const OnboardingConnectState(canNavigateToHome: true)],
      verify: (_) {
        verify(() => mockCompleteOnboarding(any())).called(1);
      },
    );

    blocTest<OnboardingConnectCubit, OnboardingConnectState>(
      'navigateToHome reports completion failure without navigation',
      setUp: () {
        when(() => mockCompleteOnboarding(any())).thenAnswer(
          (_) async =>
              const Failure.unexpected(message: 'Could not save').toFailure(),
        );
      },
      build: () => OnboardingConnectCubit(
        mockGetServerInfo,
        mockSaveConnection,
        mockTriggerTestAlarm,
        completeOnboarding: mockCompleteOnboarding,
      ),
      act: (cubit) => cubit.navigateToHome(),
      expect: () => [
        const OnboardingConnectState(errorMessage: 'Could not save'),
      ],
    );

    blocTest<OnboardingConnectCubit, OnboardingConnectState>(
      'editConnection transitions status back to idle',
      build: () => OnboardingConnectCubit(
        mockGetServerInfo,
        mockSaveConnection,
        mockTriggerTestAlarm,
      ),
      seed: () => const OnboardingConnectState(
        status: OnboardingConnectStatus.connected,
      ),
      act: (cubit) => cubit.editConnection(),
      expect: () => [
        const OnboardingConnectState(),
      ],
    );
  });
}
