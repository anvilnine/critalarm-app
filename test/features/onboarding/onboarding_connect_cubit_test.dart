import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/server_info.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/data/repositories/shared_prefs_onboarding_progress_repository.dart';
import 'package:critalarm/features/onboarding/domain/connect/background_connect.dart';
import 'package:critalarm/features/onboarding/domain/connect/connect_privacy_line.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/onboarding/domain/usecases/complete_onboarding_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/establish_api_session_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_server_info_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/onboarding_draft_usecases.dart';
import 'package:critalarm/features/onboarding/domain/usecases/save_connection_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/set_up_later_usecase.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_connect_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_connect_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockGetServerInfoUsecase extends Mock implements GetServerInfoUsecase {}

class MockSaveConnectionUsecase extends Mock implements SaveConnectionUsecase {}

class MockCompleteOnboardingUsecase extends Mock
    implements CompleteOnboardingUsecase {}

class MockEstablishSession extends Mock implements EstablishApiSessionUsecase {}

class MockGetConnectionUsecase extends Mock implements GetConnectionUsecase {}

class MockBackgroundConnect extends Mock implements BackgroundConnect {}

void main() {
  late MockEstablishSession mockEstablishSession;
  late MockGetServerInfoUsecase mockGetServerInfo;
  late MockSaveConnectionUsecase mockSaveConnection;
  late MockCompleteOnboardingUsecase mockCompleteOnboarding;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://api.critalarm.app'));
    registerFallbackValue(
      const ServerInfo(
        version: '0.1.0',
        baseUrl: 'https://api.critalarm.app',
        relayUrl: 'https://relay.critalarm.app',
      ),
    );
    registerFallbackValue(const NoParams());
    registerFallbackValue(
      const ServerConnection(serverUrl: '', adminToken: ''),
    );
  });

  setUp(() {
    mockEstablishSession = MockEstablishSession();
    when(() => mockEstablishSession(any(), any())).thenAnswer((
      invocation,
    ) async {
      final info = invocation.positionalArguments[0] as ServerInfo;
      return ApiSession(
        baseUri: Uri.parse(info.baseUrl),
        relayUri: Uri.parse(info.relayUrl),
        mode: ServerMode.selfhosted,
        managementCredential: invocation.positionalArguments[1] as String,
      );
    });
    mockGetServerInfo = MockGetServerInfoUsecase();
    mockSaveConnection = MockSaveConnectionUsecase();
    mockCompleteOnboarding = MockCompleteOnboardingUsecase();
    when(() => mockGetServerInfo(any())).thenAnswer(
      (_) async => const ServerInfo(
        version: '0.1.0',
        baseUrl: 'https://api.critalarm.app',
        relayUrl: 'https://relay.critalarm.app',
      ).toSuccess(),
    );
  });

  group('OnboardingConnectCubit', () {
    test('initial state has no server URL and idle status', () async {
      final cubit = OnboardingConnectCubit(
        mockGetServerInfo,
        mockSaveConnection,
        establishSession: mockEstablishSession,
      );
      expect(cubit.state.serverUrl, isEmpty);
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
        establishSession: mockEstablishSession,
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
        establishSession: mockEstablishSession,
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
        establishSession: mockEstablishSession,
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
        establishSession: mockEstablishSession,
      ),
      act: (cubit) => cubit.scanQrTapped(),
      expect: () => [
        const OnboardingConnectState(
          qrNotice:
              'QR scanning is not in this version. Paste the token instead.',
        ),
      ],
    );

    blocTest<OnboardingConnectCubit, OnboardingConnectState>(
      'connect with empty URL emits serverUrlError',
      build: () => OnboardingConnectCubit(
        mockGetServerInfo,
        mockSaveConnection,
        establishSession: mockEstablishSession,
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
        establishSession: mockEstablishSession,
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
        establishSession: mockEstablishSession,
      ),
      seed: () => const OnboardingConnectState(
        serverUrl: 'https://api.critalarm.app',
        adminToken: '   ',
      ),
      act: (cubit) => cubit.connect(),
      expect: () => [
        const OnboardingConnectState(
          serverUrl: 'https://api.critalarm.app',
          adminToken: '   ',
          status: OnboardingConnectStatus.connecting,
        ),
        const OnboardingConnectState(
          serverUrl: 'https://api.critalarm.app',
          adminToken: '   ',
          requiresAdminToken: true,
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
        establishSession: mockEstablishSession,
      ),
      seed: () => const OnboardingConnectState(
        serverUrl: 'https://api.critalarm.app',
        adminToken: 'ad_12345',
      ),
      act: (cubit) => cubit.connect(),
      expect: () => [
        const OnboardingConnectState(
          serverUrl: 'https://api.critalarm.app',
          adminToken: 'ad_12345',
          status: OnboardingConnectStatus.connecting,
        ),
        const OnboardingConnectState(
          serverUrl: 'https://api.critalarm.app',
          adminToken: 'ad_12345',
          status: OnboardingConnectStatus.failure,
          errorMessage: 'Something went wrong on the server. Try again.',
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
        establishSession: mockEstablishSession,
      ),
      seed: () => const OnboardingConnectState(
        serverUrl: 'https://api.critalarm.app',
        adminToken: 'ad_12345',
      ),
      act: (cubit) => cubit.connect(),
      expect: () => [
        const OnboardingConnectState(
          serverUrl: 'https://api.critalarm.app',
          adminToken: 'ad_12345',
          status: OnboardingConnectStatus.connecting,
        ),
        const OnboardingConnectState(
          serverUrl: 'https://api.critalarm.app',
          adminToken: 'ad_12345',
          status: OnboardingConnectStatus.failure,
          errorMessage:
              'Your server is 1.2.0. Update it to 0.x, then connect again.',
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
        establishSession: mockEstablishSession,
      ),
      seed: () => const OnboardingConnectState(
        serverUrl: 'https://api.critalarm.app',
        adminToken: 'ad_12345',
      ),
      act: (cubit) => cubit.connect(),
      expect: () => [
        const OnboardingConnectState(
          serverUrl: 'https://api.critalarm.app',
          adminToken: 'ad_12345',
          status: OnboardingConnectStatus.connecting,
        ),
        const OnboardingConnectState(
          serverUrl: 'https://api.critalarm.app',
          adminToken: 'ad_12345',
          status: OnboardingConnectStatus.failure,
          errorMessage:
              'Your server is custom-build-xyz. Update it to 0.x, '
              'then connect again.',
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
        establishSession: mockEstablishSession,
      ),
      seed: () => const OnboardingConnectState(
        serverUrl: 'https://api.critalarm.app',
        adminToken: 'ad_12345',
      ),
      act: (cubit) => cubit.connect(),
      expect: () => [
        const OnboardingConnectState(
          serverUrl: 'https://api.critalarm.app',
          adminToken: 'ad_12345',
          status: OnboardingConnectStatus.connecting,
        ),
        const OnboardingConnectState(
          serverUrl: 'https://api.critalarm.app',
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
      'navigateToHome marks onboarding complete before requesting navigation',
      setUp: () {
        when(() => mockCompleteOnboarding(any())).thenAnswer(
          (_) async => unit.toSuccess(),
        );
      },
      build: () => OnboardingConnectCubit(
        mockGetServerInfo,
        mockSaveConnection,
        establishSession: mockEstablishSession,
        setUpLater: SetUpLaterUsecase(mockCompleteOnboarding),
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
        establishSession: mockEstablishSession,
        setUpLater: SetUpLaterUsecase(mockCompleteOnboarding),
      ),
      act: (cubit) => cubit.navigateToHome(),
      expect: () => [
        const OnboardingConnectState(
          errorMessage: 'Something went wrong on the server. Try again.',
        ),
      ],
    );

    blocTest<OnboardingConnectCubit, OnboardingConnectState>(
      'editConnection transitions status back to idle',
      build: () => OnboardingConnectCubit(
        mockGetServerInfo,
        mockSaveConnection,
        establishSession: mockEstablishSession,
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

  group('the connect and test steps share the cubit', () {
    late SharedPrefsOnboardingProgressRepository progress;
    late MockGetConnectionUsecase getConnection;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      progress = SharedPrefsOnboardingProgressRepository(
        await SharedPreferences.getInstance(),
      );
      getConnection = MockGetConnectionUsecase();
      when(() => getConnection(any())).thenAnswer(
        (_) async => const ServerConnection(
          serverUrl: 'https://alerts.example.com',
          adminToken: 'ad_token',
        ).toSuccess(),
      );
    });

    OnboardingConnectCubit build({bool initialConnected = false}) =>
        OnboardingConnectCubit(
          mockGetServerInfo,
          mockSaveConnection,
          establishSession: mockEstablishSession,
          getConnection: getConnection,
          readDraft: ReadOnboardingDraftUsecase(progress),
          saveDraft: SaveOnboardingDraftUsecase(progress),
          initialConnected: initialConnected,
        );

    test('a saved server marks the connect step connected', () async {
      final cubit = build();

      await cubit.loadConnection();

      expect(cubit.state.isConnected, isTrue);
      expect(cubit.state.serverUrl, 'https://alerts.example.com');
      await cubit.close();
    });

    test('a replay leaves the connect form up over a saved server', () async {
      final cubit = build();

      await cubit.loadConnection(adoptSavedConnection: false);

      expect(cubit.state.isConnected, isFalse);
      expect(cubit.state.status, OnboardingConnectStatus.idle);
      await cubit.close();
    });

    test('the test step starts connected and reads the server', () async {
      final cubit = build(initialConnected: true);
      expect(cubit.state.isConnected, isTrue);

      await cubit.loadConnection();

      expect(cubit.state.serverUrl, 'https://alerts.example.com');
      await cubit.close();
    });

    test('typing saves the form and no step', () async {
      final prefs = await SharedPreferences.getInstance();
      final cubit = build()
        ..toggleSelfHosting()
        ..serverUrlChanged('https://alerts.mybox.local');
      await Future<void>.delayed(Duration.zero);
      await pumpEventQueue();

      final draft = (await progress.readDraft()).getOrNull()!;
      expect(draft.serverUrl, 'https://alerts.mybox.local');
      expect(draft.isSelfHosting, isTrue);
      expect(prefs.containsKey('onboarding_step'), isFalse);
      await cubit.close();
    });

    test('a successful connect drops the typed form', () async {
      when(() => mockSaveConnection(any())).thenAnswer(
        (_) async => unit.toSuccess(),
      );
      final cubit = build()
        ..toggleSelfHosting()
        ..serverUrlChanged('https://alerts.mybox.local')
        ..adminTokenChanged('ad_secret');
      await pumpEventQueue();

      await cubit.connect();
      await pumpEventQueue();

      expect(cubit.state.isConnected, isTrue);
      final draft = (await progress.readDraft()).getOrNull()!;
      expect(draft.serverUrl, isEmpty);
      expect(draft.adminToken, isEmpty);
      expect(draft.isSelfHosting, isFalse);
      await cubit.close();
    });

    test('opening either step writes nothing', () async {
      final prefs = await SharedPreferences.getInstance();
      final cubit = build();

      await cubit.loadConnection();
      await pumpEventQueue();

      expect(prefs.getKeys(), isEmpty);
      await cubit.close();
    });
  });

  group('Continue with Crit Alarm Cloud', () {
    late MockBackgroundConnect background;

    setUp(() {
      background = MockBackgroundConnect();
      when(() => background.start(any())).thenAnswer((_) async {});
      when(() => background.cancel()).thenAnswer((_) async {});
      when(() => background.state).thenReturn(const BackgroundConnectState());
    });

    OnboardingConnectCubit build({Future<bool> Function()? isOnline}) =>
        OnboardingConnectCubit(
          mockGetServerInfo,
          mockSaveConnection,
          establishSession: mockEstablishSession,
          backgroundConnect: background,
          isOnline: isOnline,
        );

    test('hands the Cloud address to the background connect and does not '
        'connect itself', () async {
      final cubit = build();

      await cubit.connectToCloud();

      verify(() => background.start('https://api.critalarm.app')).called(1);
      verifyNever(() => mockGetServerInfo(any()));
      verifyNever(() => mockEstablishSession(any(), any()));
      verifyNever(() => mockSaveConnection(any()));
      // The step is not held on "connecting": the screen moves on.
      expect(cubit.state.status, OnboardingConnectStatus.idle);
      // The form keeps what the user typed, if anything.
      expect(cubit.state.serverUrl, isEmpty);
      await cubit.close();
    });

    test(
      'works the same with no network: the intent is all it needs',
      () async {
        when(() => mockGetServerInfo(any())).thenAnswer(
          (_) async => const Failure.unexpected(message: 'offline').toFailure(),
        );
        final cubit = build(isOnline: () async => false);

        await cubit.connectToCloud();

        verify(() => background.start('https://api.critalarm.app')).called(1);
        expect(cubit.state.errorMessage, isNull);
        await cubit.close();
      },
    );

    test('a connect by hand cancels the Cloud connect still pending', () async {
      when(() => mockSaveConnection(any())).thenAnswer(
        (_) async => unit.toSuccess(),
      );
      final cubit = build()
        ..toggleSelfHosting()
        ..serverUrlChanged('https://alerts.mybox.local')
        ..adminTokenChanged('ad_secret');

      await cubit.connect();

      verify(() => background.cancel()).called(1);
      verifyNever(() => background.start(any()));
      await cubit.close();
    });

    test('opened on its own it waits, says what is happening, and is done '
        'when the connect lands', () async {
      final changes = StreamController<BackgroundConnectState>.broadcast();
      addTearDown(changes.close);
      when(() => background.stream).thenAnswer((_) => changes.stream);
      when(() => background.state).thenReturn(
        const BackgroundConnectState(
          status: BackgroundConnectStatus.connecting,
        ),
      );
      final cubit = build();

      await cubit.connectToCloud(waitForResult: true);
      expect(cubit.state.status, OnboardingConnectStatus.connecting);
      final connecting = cubit.state.cloudWaitLine;
      expect(connecting, isNotNull);

      changes.add(
        const BackgroundConnectState(
          status: BackgroundConnectStatus.waitingForNetwork,
        ),
      );
      await pumpEventQueue();
      expect(cubit.state.status, OnboardingConnectStatus.connecting);
      expect(cubit.state.cloudWaitLine, isNot(connecting));

      changes.add(
        const BackgroundConnectState(
          status: BackgroundConnectStatus.connected,
          serverUrl: 'https://api.critalarm.app',
        ),
      );
      await pumpEventQueue();
      expect(cubit.state.isConnected, isTrue);
      expect(cubit.state.cloudWaitLine, isNull);
      // No confirmation: the Cloud needs none, so the screen closes.
      expect(cubit.state.confirmation, isNull);
      await cubit.close();
    });

    test('opened on its own, a connect that gives up says why and lets the '
        'user try again', () async {
      final changes = StreamController<BackgroundConnectState>.broadcast();
      addTearDown(changes.close);
      when(() => background.stream).thenAnswer((_) => changes.stream);
      when(() => background.state).thenReturn(
        const BackgroundConnectState(
          status: BackgroundConnectStatus.connecting,
        ),
      );
      final cubit = build();
      await cubit.connectToCloud(waitForResult: true);

      changes.add(
        const BackgroundConnectState(
          status: BackgroundConnectStatus.failed,
          failure: BackgroundConnectFailure.refused,
        ),
      );
      await pumpEventQueue();

      expect(cubit.state.status, OnboardingConnectStatus.failure);
      expect(cubit.state.errorMessage, isNotNull);
      expect(cubit.state.cloudWaitLine, isNull);
      await cubit.close();
    });

    test('opened after a background failure, it says why', () async {
      when(() => background.state).thenReturn(
        const BackgroundConnectState(
          status: BackgroundConnectStatus.failed,
          failure: BackgroundConnectFailure.refused,
        ),
      );
      final cubit = build();

      await cubit.loadConnection();

      expect(cubit.state.errorMessage, isNotNull);
      await cubit.close();
    });
  });

  group('Cloud probe and privacy line', () {
    OnboardingConnectCubit build({Future<bool> Function()? isOnline}) =>
        OnboardingConnectCubit(
          mockGetServerInfo,
          mockSaveConnection,
          establishSession: mockEstablishSession,
          isOnline: isOnline ?? () async => true,
        );

    test('no line and no offline card before the answer', () async {
      final cubit = build();
      expect(cubit.state.cloudPrivacyLine, isNull);
      expect(cubit.state.cloudOnline, isNull);
      await cubit.close();
    });

    test('the answer gives the line and says the phone is online', () async {
      when(() => mockGetServerInfo(any())).thenAnswer(
        (_) async => const ServerInfo(
          version: '0.9.0',
          baseUrl: 'https://api.critalarm.app',
          relayUrl: 'https://relay.critalarm.app',
          mode: ServerModes.hosted,
          statedRelayContent: 'none',
        ).toSuccess(),
      );
      final cubit = build();

      await cubit.probeCloud();

      expect(cubit.state.cloudOnline, isTrue);
      expect(cubit.state.cloudPrivacyLine, ConnectPrivacyLine.cloudNone);
      verify(
        () => mockGetServerInfo(Uri.parse('https://api.critalarm.app')),
      ).called(1);
      await cubit.close();
    });

    test('relay_content full gives the line that says so', () async {
      when(() => mockGetServerInfo(any())).thenAnswer(
        (_) async => const ServerInfo(
          version: '0.9.0',
          baseUrl: 'https://api.critalarm.app',
          relayUrl: 'https://relay.critalarm.app',
          mode: ServerModes.hosted,
          relayContent: 'full',
          statedRelayContent: 'full',
        ).toSuccess(),
      );
      final cubit = build();

      await cubit.probeCloud();

      expect(cubit.state.cloudPrivacyLine, ConnectPrivacyLine.cloudFull);
      await cubit.close();
    });

    test('offline: the card shows and there is no line', () async {
      when(() => mockGetServerInfo(any())).thenAnswer(
        (_) async => const Failure.unexpected(message: 'offline').toFailure(),
      );
      final cubit = build(isOnline: () async => false);

      await cubit.probeCloud();

      expect(cubit.state.cloudOnline, isFalse);
      expect(cubit.state.cloudPrivacyLine, isNull);
      await cubit.close();
    });

    test('server down but network up: no card and still no line', () async {
      when(() => mockGetServerInfo(any())).thenAnswer(
        (_) async => const Failure.api(statusCode: 503).toFailure(),
      );
      final cubit = build(isOnline: () async => true);

      await cubit.probeCloud();

      expect(cubit.state.cloudOnline, isTrue);
      expect(cubit.state.cloudPrivacyLine, isNull);
      await cubit.close();
    });

    test('a line shown earlier goes away when the next answer fails', () async {
      when(() => mockGetServerInfo(any())).thenAnswer(
        (_) async => const ServerInfo(
          version: '0.9.0',
          baseUrl: 'https://api.critalarm.app',
          relayUrl: 'https://relay.critalarm.app',
          mode: ServerModes.hosted,
          statedRelayContent: 'none',
        ).toSuccess(),
      );
      final cubit = build(isOnline: () async => false);
      await cubit.probeCloud();
      expect(cubit.state.cloudPrivacyLine, isNotNull);

      when(() => mockGetServerInfo(any())).thenAnswer(
        (_) async => const Failure.unexpected(message: 'offline').toFailure(),
      );
      await cubit.probeCloud();

      expect(cubit.state.cloudPrivacyLine, isNull);
      expect(cubit.state.cloudOnline, isFalse);
      await cubit.close();
    });
  });

  group('own server stays in the foreground', () {
    setUp(() {
      when(() => mockSaveConnection(any())).thenAnswer(
        (_) async => unit.toSuccess(),
      );
    });

    OnboardingConnectCubit build() => OnboardingConnectCubit(
      mockGetServerInfo,
      mockSaveConnection,
      establishSession: mockEstablishSession,
    );

    test('no confirmation and no line before the server answers', () async {
      final cubit = build()
        ..toggleSelfHosting()
        ..serverUrlChanged('https://alerts.mybox.local:8443');

      expect(cubit.state.confirmation, isNull);
      expect(cubit.typedHost, 'alerts.mybox.local:8443');
      await cubit.close();
    });

    test(
      'success holds on a confirmation with the host and its line',
      () async {
        when(() => mockGetServerInfo(any())).thenAnswer(
          (_) async => const ServerInfo(
            version: '0.4.0',
            baseUrl: 'https://alerts.mybox.local:8443',
            relayUrl: 'https://relay.critalarm.app',
            statedRelayContent: 'none',
          ).toSuccess(),
        );
        final cubit = build()
          ..toggleSelfHosting()
          ..serverUrlChanged('https://alerts.mybox.local:8443')
          ..adminTokenChanged('ad_secret');

        await cubit.connect();

        expect(cubit.state.isConnected, isTrue);
        expect(
          cubit.state.confirmation,
          const ConnectConfirmation(
            host: 'alerts.mybox.local:8443',
            privacyLine: ConnectPrivacyLine.ownNone,
          ),
        );
        await cubit.close();
      },
    );

    test(
      'a server that sends the text through the relay gets that line',
      () async {
        when(() => mockGetServerInfo(any())).thenAnswer(
          (_) async => const ServerInfo(
            version: '0.4.0',
            baseUrl: 'https://alerts.mybox.local',
            relayUrl: 'https://relay.critalarm.app',
            relayContent: 'full',
            statedRelayContent: 'full',
          ).toSuccess(),
        );
        final cubit = build()
          ..toggleSelfHosting()
          ..serverUrlChanged('https://alerts.mybox.local')
          ..adminTokenChanged('ad_secret');

        await cubit.connect();

        expect(cubit.state.confirmation?.host, 'alerts.mybox.local');
        expect(
          cubit.state.confirmation?.privacyLine,
          ConnectPrivacyLine.ownFull,
        );
        await cubit.close();
      },
    );

    test('an unknown relay_content confirms the host with no line', () async {
      when(() => mockGetServerInfo(any())).thenAnswer(
        (_) async => const ServerInfo(
          version: '0.4.0',
          baseUrl: 'https://alerts.mybox.local',
          relayUrl: 'https://relay.critalarm.app',
          relayContent: 'partial',
          statedRelayContent: 'partial',
        ).toSuccess(),
      );
      final cubit = build()
        ..toggleSelfHosting()
        ..serverUrlChanged('https://alerts.mybox.local')
        ..adminTokenChanged('ad_secret');

      await cubit.connect();

      expect(cubit.state.confirmation?.host, 'alerts.mybox.local');
      expect(cubit.state.confirmation?.privacyLine, isNull);
      await cubit.close();
    });

    test(
      'a server that sends no relay_content confirms with no line',
      () async {
        when(() => mockGetServerInfo(any())).thenAnswer(
          (_) async => const ServerInfo(
            version: '0.4.0',
            baseUrl: 'https://alerts.mybox.local',
            relayUrl: 'https://relay.critalarm.app',
          ).toSuccess(),
        );
        final cubit = build()
          ..toggleSelfHosting()
          ..serverUrlChanged('https://alerts.mybox.local')
          ..adminTokenChanged('ad_secret');

        await cubit.connect();

        expect(cubit.state.confirmation?.host, 'alerts.mybox.local');
        expect(cubit.state.confirmation?.privacyLine, isNull);
        await cubit.close();
      },
    );

    test('a failed connect shows no confirmation', () async {
      when(() => mockGetServerInfo(any())).thenAnswer(
        (_) async => const Failure.unexpected(message: 'offline').toFailure(),
      );
      final cubit = build()
        ..toggleSelfHosting()
        ..serverUrlChanged('https://alerts.mybox.local')
        ..adminTokenChanged('ad_secret');

      await cubit.connect();

      expect(cubit.state.status, OnboardingConnectStatus.failure);
      expect(cubit.state.confirmation, isNull);
      expect(cubit.state.errorMessage, isNotNull);
      await cubit.close();
    });
  });
}
