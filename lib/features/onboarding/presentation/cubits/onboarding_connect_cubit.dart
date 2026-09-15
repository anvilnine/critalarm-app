import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/models/server_info_validator.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/trigger_test_alarm_usecase.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/onboarding/domain/usecases/complete_onboarding_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/establish_api_session_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_server_info_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/save_connection_usecase.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_connect_state.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Cubit managing Screen 2: server connection, admin token input, compatibility
/// validation, and the test alarm "Ring me now" sequence.
class OnboardingConnectCubit extends Cubit<OnboardingConnectState> {
  OnboardingConnectCubit(
    this._getServerInfo,
    this._saveConnection,
    this._triggerTestAlarm, {
    required this.establishSession,
    this.getTopics,
    this.getConnection,
    this.completeOnboarding,
    bool initialConnected = false,
  }) : super(
         OnboardingConnectState(
           status: initialConnected
               ? OnboardingConnectStatus.connected
               : OnboardingConnectStatus.idle,
         ),
       );

  final GetTopicsUsecase? getTopics;
  final GetConnectionUsecase? getConnection;

  Future<void> loadConnection() async {
    final result = await getConnection?.call(const NoParams());
    final connection = result?.getOrNull();
    if (connection != null) {
      emit(
        state.copyWith(
          serverUrl: connection.serverUrl,
          status: OnboardingConnectStatus.connected,
        ),
      );
      await loadTestTopic();
    }
  }

  final EstablishApiSessionUsecase establishSession;
  final GetServerInfoUsecase _getServerInfo;
  final SaveConnectionUsecase _saveConnection;
  final CompleteOnboardingUsecase? completeOnboarding;
  final TriggerTestAlarmUsecase _triggerTestAlarm;

  void serverUrlChanged(String url) {
    emit(
      state.copyWith(
        serverUrl: url,
        requiresAdminToken: false,
        clearAdminTokenError: true,
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
        qrNotice: LocaleKeys.onboarding_connect_qr_notice.tr(),
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
          serverUrlError: LocaleKeys.onboarding_connect_server_url_error_empty
              .tr(),
        ),
      );
      return;
    }

    if (!ServerInfoValidation.isValidServerUrl(trimmedUrl)) {
      emit(
        state.copyWith(
          serverUrlError: LocaleKeys.onboarding_connect_server_url_error_invalid
              .tr(),
        ),
      );
      return;
    }

    final trimmedToken = state.adminToken.trim();
    emit(
      state.copyWith(
        status: OnboardingConnectStatus.connecting,
        clearServerUrlError: true,
        clearAdminTokenError: true,
        clearErrorMessage: true,
      ),
    );

    final result = await _getServerInfo(Uri.parse(trimmedUrl));
    await result.fold(
      (info) async {
        if (!isSemverCompatible(info.version)) {
          emit(
            state.copyWith(
              status: OnboardingConnectStatus.failure,
              errorMessage: LocaleKeys.onboarding_connect_version_incompatible
                  .tr(namedArgs: {'version': info.version}),
            ),
          );
          return;
        }

        final mode = ServerMode.fromWireValue(info.mode);
        if (mode == ServerMode.selfhosted && trimmedToken.isEmpty) {
          emit(
            state.copyWith(
              status: OnboardingConnectStatus.idle,
              requiresAdminToken: true,
              adminTokenError: LocaleKeys
                  .onboarding_connect_admin_token_error_empty
                  .tr(),
            ),
          );
          return;
        }
        try {
          final session = await establishSession.call(info, trimmedToken);
          final saved = await _saveConnection(
            ServerConnection(
              serverUrl: info.baseUrl,
              adminToken: session.managementCredential,
            ),
          );
          await saved.fold(
            (_) async {
              await loadTestTopic();
              emit(
                state.copyWith(
                  serverUrl: info.baseUrl,
                  status: OnboardingConnectStatus.connected,
                  clearErrorMessage: true,
                ),
              );
            },
            (failure) async => emit(
              state.copyWith(
                status: OnboardingConnectStatus.failure,
                errorMessage: failure.message,
              ),
            ),
          );
        } on Object catch (error) {
          emit(
            state.copyWith(
              status: OnboardingConnectStatus.failure,
              errorMessage: error.toString(),
            ),
          );
        }
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

  Future<void> loadTestTopic() async {
    final result = await getTopics?.call(const NoParams());
    final topics = result?.getOrNull() ?? [];
    emit(
      state.copyWith(
        topic: topics.where((t) => t.critical).firstOrNull?.name ?? '',
        errorMessage: result?.exceptionOrNull()?.message,
      ),
    );
  }

  Future<void> ringTestAlarm({String? topic}) async {
    if (getTopics != null) await loadTestTopic();
    final targetTopic = getTopics == null
        ? (topic ?? state.topic)
        : state.topic;
    if (targetTopic.isEmpty) {
      emit(
        state.copyWith(
          testAlarmStatus: TestAlarmStatus.failure,
          errorMessage:
              'Create a topic and enable critical delivery '
              'before testing an alarm.',
        ),
      );
      return;
    }
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
