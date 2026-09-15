import 'package:critalarm/core/models/account_access.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/onboarding/domain/repositories/connection_repository.dart';
import 'package:critalarm/features/onboarding/domain/usecases/clear_connection_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/save_connection_usecase.dart';
import 'package:critalarm/features/settings/domain/repositories/privacy_repository.dart';
import 'package:critalarm/features/settings/domain/usecases/get_privacy_settings_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/set_analytics_enabled_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/set_crash_reporting_enabled_usecase.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_state.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Cubit managing state and preferences on the Settings screen.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    this.getConnectionUsecase,
    this.clearConnectionUsecase,
    this.saveConnectionUsecase,
    this.connectionRepository,
    this.getPrivacySettingsUsecase,
    this.setAnalyticsEnabledUsecase,
    this.setCrashReportingEnabledUsecase,
    this.privacyRepository,
    this.telemetryGate,
    this.identityStore,
    this.getTopics,
  }) : super(const SettingsState());

  final GetConnectionUsecase? getConnectionUsecase;
  final ClearConnectionUsecase? clearConnectionUsecase;
  final SaveConnectionUsecase? saveConnectionUsecase;
  final ConnectionRepository? connectionRepository;
  final GetPrivacySettingsUsecase? getPrivacySettingsUsecase;
  final SetAnalyticsEnabledUsecase? setAnalyticsEnabledUsecase;
  final SetCrashReportingEnabledUsecase? setCrashReportingEnabledUsecase;
  final PrivacyRepository? privacyRepository;
  final TelemetryGate? telemetryGate;
  final DeviceIdentityStore? identityStore;
  final GetTopicsUsecase? getTopics;

  bool get isPaywallEnabled => telemetryGate?.isPaywallEnabled ?? false;
  bool get paywallEnabled => isPaywallEnabled;

  Future<void> load({bool forceDisconnected = false}) async {
    emit(state.copyWith(status: SettingsStatus.loading));

    if (forceDisconnected) {
      emit(
        state.copyWith(
          isConnected: false,
          serverUrl: '',
          adminToken: '',
        ),
      );
    } else if (getConnectionUsecase != null) {
      final connResult = await getConnectionUsecase!(const NoParams());
      connResult.fold(
        (conn) {
          emit(
            state.copyWith(
              serverUrl: conn.serverUrl,
              adminToken: conn.adminToken,
              isConnected: true,
            ),
          );
        },
        (_) {
          emit(state.copyWith(isConnected: false));
        },
      );
    } else if (connectionRepository != null) {
      final connResult = await connectionRepository!.getConnection();
      connResult.fold(
        (conn) {
          emit(
            state.copyWith(
              serverUrl: conn.serverUrl,
              adminToken: conn.adminToken,
              isConnected: true,
            ),
          );
        },
        (_) {
          emit(state.copyWith(isConnected: false));
        },
      );
    }

    // Load privacy settings if available
    if (getPrivacySettingsUsecase != null) {
      final privacyResult = await getPrivacySettingsUsecase!(const NoParams());
      await privacyResult.fold(
        (privacy) async {
          emit(
            state.copyWith(
              analyticsEnabled: privacy.analyticsEnabled,
              crashReportingEnabled: privacy.crashReportingEnabled,
            ),
          );
          if (privacy.analyticsEnabled) {
            await telemetryGate?.setAnalyticsEnabled(true);
          }
          if (privacy.crashReportingEnabled) {
            await telemetryGate?.setCrashlyticsEnabled(true);
          }
        },
        (_) async {},
      );
    } else if (privacyRepository != null) {
      final privacyResult = await privacyRepository!.getPrivacySettings();
      await privacyResult.fold(
        (privacy) async {
          emit(
            state.copyWith(
              analyticsEnabled: privacy.analyticsEnabled,
              crashReportingEnabled: privacy.crashReportingEnabled,
            ),
          );
          if (privacy.analyticsEnabled) {
            await telemetryGate?.setAnalyticsEnabled(true);
          }
          if (privacy.crashReportingEnabled) {
            await telemetryGate?.setCrashlyticsEnabled(true);
          }
        },
        (_) async {},
      );
    }

    final identity = await identityStore?.readOrCreate();
    final result = await getTopics?.call(const NoParams());
    emit(
      state.copyWith(
        status: SettingsStatus.success,
        access: AccountAccess(identity),
        topics: result?.getOrNull() ?? [],
        errorMessage: result?.exceptionOrNull()?.message,
      ),
    );
  }

  void toggleQuietHours({required bool isEnabled}) {
    emit(state.copyWith(quietHoursEnabled: isEnabled));
  }

  void toggleCriticalRingsQuietHours({required bool isEnabled}) {
    emit(state.copyWith(criticalRingsQuietHours: isEnabled));
  }

  void toggleEscalationCall({required bool isEnabled}) {
    emit(state.copyWith(escalationCallEnabled: isEnabled));
  }

  void setServerUrl(String url) {
    emit(state.copyWith(serverUrl: url));
  }

  Future<void> toggleAnalytics({required bool isEnabled}) async {
    emit(state.copyWith(analyticsEnabled: isEnabled));
    await telemetryGate?.setAnalyticsEnabled(isEnabled);
    if (setAnalyticsEnabledUsecase != null) {
      await setAnalyticsEnabledUsecase!(isEnabled);
    } else if (privacyRepository != null) {
      await privacyRepository!.setAnalyticsEnabled(enabled: isEnabled);
    }
  }

  Future<void> toggleCrashReporting({required bool isEnabled}) async {
    emit(state.copyWith(crashReportingEnabled: isEnabled));
    await telemetryGate?.setCrashlyticsEnabled(isEnabled);
    if (setCrashReportingEnabledUsecase != null) {
      await setCrashReportingEnabledUsecase!(isEnabled);
    } else if (privacyRepository != null) {
      await privacyRepository!.setCrashReportingEnabled(enabled: isEnabled);
    }
  }

  Future<void> disconnectServer() async {
    emit(state.copyWith(isDisconnecting: true));
    if (clearConnectionUsecase != null) {
      await clearConnectionUsecase!(const NoParams());
    } else if (connectionRepository != null) {
      await connectionRepository!.clearConnection();
    }
    emit(
      state.copyWith(
        isDisconnecting: false,
        isConnected: false,
        serverUrl: '',
        adminToken: '',
      ),
    );
  }

  Future<void> saveConnection({
    required String serverUrl,
    required String adminToken,
  }) async {
    emit(state.copyWith(isSavingConnection: true));
    final connection = ServerConnection(
      serverUrl: serverUrl,
      adminToken: adminToken,
    );

    if (saveConnectionUsecase != null) {
      await saveConnectionUsecase!(connection);
    } else if (connectionRepository != null) {
      await connectionRepository!.saveConnection(connection);
    }

    emit(
      state.copyWith(
        isSavingConnection: false,
        isConnected: true,
        serverUrl: serverUrl,
        adminToken: adminToken,
      ),
    );
  }
}
