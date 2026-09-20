import 'package:critalarm/core/alarm/quiet_hours.dart';
import 'package:critalarm/core/alarm/quiet_hours_store.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/models/account_access.dart';
import 'package:critalarm/core/paywall/pro_override.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/onboarding/domain/repositories/connection_repository.dart';
import 'package:critalarm/features/onboarding/domain/usecases/clear_connection_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/establish_api_session_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_server_info_usecase.dart';
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
    this.apiSessions,
    this.getServerInfo,
    this.establishSession,
    this.getTopics,
    this.quietHoursStore,
    ProOverride? proOverride,
  }) : _proOverride = proOverride ?? appProOverride,
       super(const SettingsState()) {
    _proOverride.listenable?.addListener(_onForceProChanged);
  }

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
  final ApiSessionStore? apiSessions;

  /// The two halves of re-establishing the session when the server changes.
  /// Null in the tests that only care about the saved URL.
  final GetServerInfoUsecase? getServerInfo;
  final EstablishApiSessionUsecase? establishSession;
  final GetTopicsUsecase? getTopics;

  /// Where the quiet hours window lives. Null in the tests that do not care
  /// about it, and then the three controls only move in memory.
  final QuietHoursStore? quietHoursStore;

  final ProOverride _proOverride;

  /// The developer Force Pro switch moved. The plan row reads
  /// [AccountAccess.isPaid], so hand it a fresh one and let the screen rebuild.
  void _onForceProChanged() {
    if (isClosed) return;
    emit(
      state.copyWith(
        access: AccountAccess(
          state.access.identity,
          proOverride: _proOverride,
        ),
      ),
    );
  }

  @override
  Future<void> close() {
    _proOverride.listenable?.removeListener(_onForceProChanged);
    return super.close();
  }

  bool get isPaywallEnabled => telemetryGate?.isPaywallEnabled ?? false;
  bool get paywallEnabled => isPaywallEnabled;

  Future<void> load({bool forceDisconnected = false}) async {
    emit(state.copyWith(status: SettingsStatus.loading));

    // The cubit is registered as a factory, so a fresh one arrives every time
    // the screen opens. Reading the window here is what makes the three
    // controls survive leaving the screen and relaunching.
    final window = quietHoursStore?.read();
    if (window != null) {
      emit(
        state.copyWith(
          quietHoursEnabled: window.isEnabled,
          quietHoursStartMinutes: window.startMinutes,
          quietHoursEndMinutes: window.endMinutes,
          criticalRingsQuietHours: window.criticalRingsThrough,
        ),
      );
    }

    // Which mode the server runs in decides whether the Account row is drawn.
    // It comes out of preferences, so read it before anything that waits on
    // the network: bundled with the topics call below, the row only appeared
    // once the server answered, and it popped in under the Server row.
    final session = await apiSessions?.read();
    if (session != null) {
      emit(state.copyWith(serverMode: session.mode));
    }

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
        access: AccountAccess(identity, proOverride: _proOverride),
        topics: result?.getOrNull() ?? [],
        errorMessage: result?.exceptionOrNull()?.message,
      ),
    );
  }

  Future<void> toggleQuietHours({required bool isEnabled}) async {
    emit(state.copyWith(quietHoursEnabled: isEnabled));
    await _saveQuietHours();
  }

  Future<void> toggleCriticalRingsQuietHours({
    required bool isEnabled,
  }) async {
    emit(state.copyWith(criticalRingsQuietHours: isEnabled));
    await _saveQuietHours();
  }

  /// Both ends of the window, in minutes from local midnight.
  Future<void> setQuietHoursWindow({
    required int startMinutes,
    required int endMinutes,
  }) async {
    emit(
      state.copyWith(
        quietHoursStartMinutes: startMinutes,
        quietHoursEndMinutes: endMinutes,
      ),
    );
    await _saveQuietHours();
  }

  /// Saves all four values on every change, so the window the push path reads
  /// is never half of what the screen shows.
  Future<void> _saveQuietHours() async {
    await quietHoursStore?.write(
      QuietHours(
        isEnabled: state.quietHoursEnabled,
        startMinutes: state.quietHoursStartMinutes,
        endMinutes: state.quietHoursEndMinutes,
        criticalRingsThrough: state.criticalRingsQuietHours,
      ),
    );
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
    // Clearing the URL is not disconnecting. Left behind, the session keeps
    // pointing requests at the old server and the device identity hands it a
    // credential the next server never issued.
    await apiSessions?.clear();
    await identityStore?.clear();
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

    final session = await _establishSession(serverUrl, adminToken);

    emit(
      state.copyWith(
        isSavingConnection: false,
        isConnected: true,
        serverUrl: serverUrl,
        adminToken: adminToken,
        serverMode: session?.mode,
      ),
    );
  }

  /// Rewrites the stored session so the very next request goes to the server
  /// that was just saved. Without this the screen shows the new server while
  /// every request still goes to the old one until the app restarts.
  ///
  /// Returns null when the new server cannot be reached. The URL is saved
  /// either way, and the next launch establishes the session from it.
  Future<ApiSession?> _establishSession(
    String serverUrl,
    String adminToken,
  ) async {
    if (getServerInfo == null || establishSession == null) return null;
    final uri = Uri.tryParse(serverUrl);
    if (uri == null) return null;
    final info = (await getServerInfo!(uri)).getOrNull();
    if (info == null) return null;
    try {
      return await establishSession!(info, adminToken);
    } on Object {
      return null;
    }
  }
}
