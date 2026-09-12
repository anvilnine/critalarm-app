import 'package:critalarm/core/models/server_info_validator.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/trigger_test_alarm_usecase.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/onboarding/domain/usecases/complete_onboarding_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_server_info_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/save_connection_usecase.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_connect_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Cubit managing Screen 2: server connection, admin token input, compatibility
/// validation, and the test alarm "Ring me now" sequence.
class OnboardingConnectCubit extends Cubit<OnboardingConnectState> {
  OnboardingConnectCubit(
    this._getServerInfo,
    this._saveConnection,
    this._triggerTestAlarm, {
    this.completeOnboarding,
    bool initialConnected = false,
  }) : super(
         OnboardingConnectState(
           status: initialConnected
               ? OnboardingConnectStatus.connected
               : OnboardingConnectStatus.idle,
         ),
       );

  final GetServerInfoUsecase _getServerInfo;
  final SaveConnectionUsecase _saveConnection;
  final CompleteOnboardingUsecase? completeOnboarding;
  final TriggerTestAlarmUsecase _triggerTestAlarm;

  void serverUrlChanged(String url) {
    emit(
      state.copyWith(
        serverUrl: url,
        clearServerUrlError: true,
        clearErrorMessage: true,
      ),
    );
  }

  void adminTokenChanged(String token) {
    emit(
      state.copyWith(
        adminToken: token,
        clearAdminTokenError: true,
        clearErrorMessage: true,
      ),
    );
  }

  void pasteToken(String token) {
    emit(
      state.copyWith(
        adminToken: token,
        clearAdminTokenError: true,
        clearErrorMessage: true,
      ),
    );
  }

  void scanQrTapped() {
    emit(
      state.copyWith(
        qrNotice: 'QR scanner placeholder - paste token instead',
      ),
    );
  }

  void clearQrNotice() {
    emit(state.copyWith(clearQrNotice: true));
  }

  static bool isSemverCompatible(String version) =>
      ServerInfoValidation.isSemverCompatible(version);

  Future<void> connect() async {
    final trimmedUrl = state.serverUrl.trim();
    if (trimmedUrl.isEmpty) {
      emit(
        state.copyWith(
          serverUrlError: 'Server URL cannot be empty',
        ),
      );
      return;
    }

    if (!ServerInfoValidation.isValidServerUrl(trimmedUrl)) {
      emit(
        state.copyWith(
          serverUrlError: 'Enter a valid URL (e.g. https://api.critalarm.app)',
        ),
      );
      return;
    }

    final trimmedToken = state.adminToken.trim();
    if (trimmedToken.isEmpty) {
      emit(
        state.copyWith(
          adminTokenError: 'Admin token cannot be empty',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: OnboardingConnectStatus.connecting,
        clearServerUrlError: true,
        clearAdminTokenError: true,
        clearErrorMessage: true,
      ),
    );

    final result = await _getServerInfo(const NoParams());
    await result.fold(
      (info) async {
        if (!isSemverCompatible(info.version)) {
          emit(
            state.copyWith(
              status: OnboardingConnectStatus.failure,
              errorMessage:
                  'Server version ${info.version} is incompatible. '
                  'Crit Alarm requires v0.x.',
            ),
          );
          return;
        }

        // Semver is compatible (major == 0). Store connection.
        await _saveConnection(
          ServerConnection(
            serverUrl: trimmedUrl,
            adminToken: trimmedToken,
          ),
        );

        emit(
          state.copyWith(
            status: OnboardingConnectStatus.connected,
            clearErrorMessage: true,
          ),
        );
      },
      (failure) async {
        emit(
          state.copyWith(
            status: OnboardingConnectStatus.failure,
            errorMessage: failure.message,
          ),
        );
      },
    );
  }

  Future<void> ringTestAlarm({String? topic}) async {
    final targetTopic = topic ?? state.topic;
    emit(
      state.copyWith(
        testAlarmStatus: TestAlarmStatus.ringing,
        topic: targetTopic,
        clearErrorMessage: true,
        clearIncidentId: true,
      ),
    );

    final result = await _triggerTestAlarm(targetTopic);
    result.fold(
      (incidentId) {
        emit(
          state.copyWith(
            testAlarmStatus: TestAlarmStatus.success,
            incidentId: incidentId,
            clearErrorMessage: true,
          ),
        );
      },
      (failure) {
        emit(
          state.copyWith(
            testAlarmStatus: TestAlarmStatus.failure,
            errorMessage: failure.message,
          ),
        );
      },
    );
  }

  void editConnection() {
    emit(
      state.copyWith(
        status: OnboardingConnectStatus.idle,
        testAlarmStatus: TestAlarmStatus.idle,
        clearErrorMessage: true,
      ),
    );
  }

  Future<void> navigateToHome() async {
    final completion = completeOnboarding;
    if (completion == null) return;

    final result = await completion(const NoParams());
    result.fold(
      (_) => emit(state.copyWith(canNavigateToHome: true)),
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
    );
  }

  void navigationHandled() {
    emit(state.copyWith(canNavigateToHome: false));
  }
}
