import 'package:bloc_test/bloc_test.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/onboarding/domain/repositories/connection_repository.dart';
import 'package:critalarm/features/onboarding/domain/usecases/clear_connection_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/save_connection_usecase.dart';
import 'package:critalarm/features/settings/domain/entities/privacy_settings.dart';
import 'package:critalarm/features/settings/domain/repositories/privacy_repository.dart';
import 'package:critalarm/features/settings/domain/usecases/get_privacy_settings_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/set_analytics_enabled_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/set_crash_reporting_enabled_usecase.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockConnectionRepository extends Mock implements ConnectionRepository {}

class MockPrivacyRepository extends Mock implements PrivacyRepository {}

class MockTelemetryGate extends Mock implements TelemetryGate {}

void main() {
  late MockConnectionRepository connectionRepo;
  late MockPrivacyRepository privacyRepo;
  late GetConnectionUsecase getConnectionUsecase;
  late ClearConnectionUsecase clearConnectionUsecase;
  late SaveConnectionUsecase saveConnectionUsecase;
  late GetPrivacySettingsUsecase getPrivacySettingsUsecase;
  late SetAnalyticsEnabledUsecase setAnalyticsEnabledUsecase;
  late SetCrashReportingEnabledUsecase setCrashReportingEnabledUsecase;
  late MockTelemetryGate telemetryGate;

  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(
      const ServerConnection(serverUrl: '', adminToken: ''),
    );
  });

  setUp(() {
    connectionRepo = MockConnectionRepository();
    privacyRepo = MockPrivacyRepository();
    telemetryGate = MockTelemetryGate();

    getConnectionUsecase = GetConnectionUsecase(connectionRepo);
    clearConnectionUsecase = ClearConnectionUsecase(connectionRepo);
    saveConnectionUsecase = SaveConnectionUsecase(connectionRepo);
    getPrivacySettingsUsecase = GetPrivacySettingsUsecase(privacyRepo);
    setAnalyticsEnabledUsecase = SetAnalyticsEnabledUsecase(privacyRepo);
    setCrashReportingEnabledUsecase = SetCrashReportingEnabledUsecase(
      privacyRepo,
    );
  });

  group('SettingsCubit', () {
    test('initial state has no server connection', () {
      final cubit = SettingsCubit();

      expect(cubit.state.status, SettingsStatus.initial);
      expect(cubit.state.quietHoursEnabled, isTrue);
      expect(cubit.state.criticalRingsQuietHours, isTrue);
      expect(cubit.state.escalationCallEnabled, isFalse);
      expect(cubit.state.serverUrl, isEmpty);
      expect(cubit.state.isConnected, isFalse);
      expect(cubit.state.analyticsEnabled, isFalse);
      expect(cubit.state.crashReportingEnabled, isFalse);
    });

    blocTest<SettingsCubit, SettingsState>(
      'loads saved server connection and privacy preferences on load',
      setUp: () {
        when(() => connectionRepo.getConnection()).thenAnswer(
          (_) async => const ServerConnection(
            serverUrl: 'https://my-server.lan',
            adminToken: 'token_123',
          ).toSuccess(),
        );
        when(() => privacyRepo.getPrivacySettings()).thenAnswer(
          (_) async => const PrivacySettings(
            analyticsEnabled: true,
            crashReportingEnabled: true,
          ).toSuccess(),
        );
      },
      build: () => SettingsCubit(
        getConnectionUsecase: getConnectionUsecase,
        getPrivacySettingsUsecase: getPrivacySettingsUsecase,
      ),
      act: (cubit) => cubit.load(),
      expect: () => [
        const SettingsState(status: SettingsStatus.loading),
        isA<SettingsState>()
            .having((s) => s.serverUrl, 'serverUrl', 'https://my-server.lan')
            .having((s) => s.adminToken, 'adminToken', 'token_123')
            .having((s) => s.isConnected, 'isConnected', isTrue),
        isA<SettingsState>()
            .having((s) => s.analyticsEnabled, 'analyticsEnabled', isTrue)
            .having(
              (s) => s.crashReportingEnabled,
              'crashReportingEnabled',
              isTrue,
            ),
        isA<SettingsState>().having(
          (s) => s.status,
          'status',
          SettingsStatus.success,
        ),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'sets isConnected false when no saved connection found',
      setUp: () {
        when(() => connectionRepo.getConnection()).thenAnswer(
          (_) async => const Failure.notFound(
            message: 'No saved connection',
          ).toFailure(),
        );
      },
      build: () => SettingsCubit(
        getConnectionUsecase: getConnectionUsecase,
      ),
      act: (cubit) => cubit.load(),
      expect: () => [
        const SettingsState(status: SettingsStatus.loading),
        isA<SettingsState>().having(
          (s) => s.status,
          'status',
          SettingsStatus.success,
        ),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'togglePrivacy toggles analytics and calls usecase',
      setUp: () {
        when(
          () => privacyRepo.setAnalyticsEnabled(
            enabled: any(named: 'enabled'),
          ),
        ).thenAnswer((_) async => unit.toSuccess());
      },
      build: () => SettingsCubit(
        setAnalyticsEnabledUsecase: setAnalyticsEnabledUsecase,
      ),
      act: (cubit) => cubit.toggleAnalytics(isEnabled: true),
      expect: () => [
        isA<SettingsState>().having(
          (s) => s.analyticsEnabled,
          'analyticsEnabled',
          isTrue,
        ),
      ],
      verify: (_) {
        verify(() => privacyRepo.setAnalyticsEnabled(enabled: true)).called(1);
      },
    );

    blocTest<SettingsCubit, SettingsState>(
      'toggleCrashReporting toggles crash reporting and calls usecase',
      setUp: () {
        when(
          () => privacyRepo.setCrashReportingEnabled(
            enabled: any(named: 'enabled'),
          ),
        ).thenAnswer((_) async => unit.toSuccess());
      },
      build: () => SettingsCubit(
        setCrashReportingEnabledUsecase: setCrashReportingEnabledUsecase,
      ),
      act: (cubit) => cubit.toggleCrashReporting(isEnabled: true),
      expect: () => [
        isA<SettingsState>().having(
          (s) => s.crashReportingEnabled,
          'crashReportingEnabled',
          isTrue,
        ),
      ],
      verify: (_) {
        verify(
          () => privacyRepo.setCrashReportingEnabled(enabled: true),
        ).called(1);
      },
    );

    blocTest<SettingsCubit, SettingsState>(
      'toggleAnalytics calls telemetryGate immediately when provided',
      setUp: () {
        when(
          () => privacyRepo.setAnalyticsEnabled(
            enabled: any(named: 'enabled'),
          ),
        ).thenAnswer((_) async => unit.toSuccess());
        when(
          () => telemetryGate.setAnalyticsEnabled(any()),
        ).thenAnswer((_) async {});
      },
      build: () => SettingsCubit(
        setAnalyticsEnabledUsecase: setAnalyticsEnabledUsecase,
        telemetryGate: telemetryGate,
      ),
      act: (cubit) => cubit.toggleAnalytics(isEnabled: true),
      expect: () => [
        isA<SettingsState>().having(
          (s) => s.analyticsEnabled,
          'analyticsEnabled',
          isTrue,
        ),
      ],
      verify: (_) {
        verify(() => telemetryGate.setAnalyticsEnabled(true)).called(1);
        verify(() => privacyRepo.setAnalyticsEnabled(enabled: true)).called(1);
      },
    );

    blocTest<SettingsCubit, SettingsState>(
      'toggleCrashReporting calls telemetryGate immediately when provided',
      setUp: () {
        when(
          () => privacyRepo.setCrashReportingEnabled(
            enabled: any(named: 'enabled'),
          ),
        ).thenAnswer((_) async => unit.toSuccess());
        when(
          () => telemetryGate.setCrashlyticsEnabled(any()),
        ).thenAnswer((_) async {});
      },
      build: () => SettingsCubit(
        setCrashReportingEnabledUsecase: setCrashReportingEnabledUsecase,
        telemetryGate: telemetryGate,
      ),
      act: (cubit) => cubit.toggleCrashReporting(isEnabled: true),
      expect: () => [
        isA<SettingsState>().having(
          (s) => s.crashReportingEnabled,
          'crashReportingEnabled',
          isTrue,
        ),
      ],
      verify: (_) {
        verify(() => telemetryGate.setCrashlyticsEnabled(true)).called(1);
        verify(
          () => privacyRepo.setCrashReportingEnabled(enabled: true),
        ).called(1);
      },
    );

    test('isPaywallEnabled and paywallEnabled delegate to telemetryGate', () {
      when(() => telemetryGate.isPaywallEnabled).thenReturn(true);
      final cubit = SettingsCubit(
        telemetryGate: telemetryGate,
      );

      expect(cubit.isPaywallEnabled, isTrue);
      expect(cubit.paywallEnabled, isTrue);
    });

    blocTest<SettingsCubit, SettingsState>(
      'disconnectServer clears connection from repository and updates state',
      setUp: () {
        when(
          () => connectionRepo.clearConnection(),
        ).thenAnswer((_) async => unit.toSuccess());
      },
      build: () => SettingsCubit(
        clearConnectionUsecase: clearConnectionUsecase,
      ),
      act: (cubit) => cubit.disconnectServer(),
      expect: () => [
        isA<SettingsState>().having(
          (s) => s.isDisconnecting,
          'isDisconnecting',
          isTrue,
        ),
        isA<SettingsState>()
            .having((s) => s.isDisconnecting, 'isDisconnecting', isFalse)
            .having((s) => s.isConnected, 'isConnected', isFalse)
            .having((s) => s.serverUrl, 'serverUrl', isEmpty)
            .having((s) => s.adminToken, 'adminToken', isEmpty),
      ],
      verify: (_) {
        verify(() => connectionRepo.clearConnection()).called(1);
      },
    );

    blocTest<SettingsCubit, SettingsState>(
      'saveConnection updates connection in repository and state',
      setUp: () {
        when(
          () => connectionRepo.saveConnection(any()),
        ).thenAnswer((_) async => unit.toSuccess());
      },
      build: () => SettingsCubit(
        saveConnectionUsecase: saveConnectionUsecase,
      ),
      act: (cubit) => cubit.saveConnection(
        serverUrl: 'https://new-host.io',
        adminToken: 'adm_secret',
      ),
      expect: () => [
        isA<SettingsState>().having(
          (s) => s.isSavingConnection,
          'isSavingConnection',
          isTrue,
        ),
        isA<SettingsState>()
            .having((s) => s.isSavingConnection, 'isSavingConnection', isFalse)
            .having((s) => s.isConnected, 'isConnected', isTrue)
            .having((s) => s.serverUrl, 'serverUrl', 'https://new-host.io')
            .having((s) => s.adminToken, 'adminToken', 'adm_secret'),
      ],
      verify: (_) {
        verify(
          () => connectionRepo.saveConnection(
            const ServerConnection(
              serverUrl: 'https://new-host.io',
              adminToken: 'adm_secret',
            ),
          ),
        ).called(1);
      },
    );

    blocTest<SettingsCubit, SettingsState>(
      'toggleQuietHours updates quietHoursEnabled',
      build: SettingsCubit.new,
      act: (cubit) => cubit.toggleQuietHours(isEnabled: false),
      expect: () => [
        isA<SettingsState>().having(
          (s) => s.quietHoursEnabled,
          'quietHoursEnabled',
          isFalse,
        ),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'toggleCriticalRingsQuietHours updates criticalRingsQuietHours',
      build: SettingsCubit.new,
      act: (cubit) => cubit.toggleCriticalRingsQuietHours(isEnabled: false),
      expect: () => [
        isA<SettingsState>().having(
          (s) => s.criticalRingsQuietHours,
          'criticalRingsQuietHours',
          isFalse,
        ),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'toggleEscalationCall updates escalationCallEnabled',
      build: SettingsCubit.new,
      act: (cubit) => cubit.toggleEscalationCall(isEnabled: true),
      expect: () => [
        isA<SettingsState>().having(
          (s) => s.escalationCallEnabled,
          'escalationCallEnabled',
          isTrue,
        ),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'setServerUrl updates serverUrl',
      build: SettingsCubit.new,
      act: (cubit) => cubit.setServerUrl('custom.alerts.io'),
      expect: () => [
        isA<SettingsState>().having(
          (s) => s.serverUrl,
          'serverUrl',
          'custom.alerts.io',
        ),
      ],
    );
  });
}
