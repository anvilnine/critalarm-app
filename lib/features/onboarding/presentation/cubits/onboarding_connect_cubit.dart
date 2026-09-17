import 'dart:async';

import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/api/network_failure_message.dart';
import 'package:critalarm/core/models/server_info_validator.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/trigger_test_alarm_usecase.dart';
import 'package:critalarm/features/onboarding/domain/entities/onboarding_draft.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/onboarding/domain/usecases/complete_onboarding_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/establish_api_session_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_server_info_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/onboarding_draft_usecases.dart';
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
    this.alarmHost,
    this.readDraft,
    this.saveDraft,
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
  final AlarmHost? alarmHost;

  /// Null in tests that do not care about surviving a force-quit.
  final ReadOnboardingDraftUsecase? readDraft;
  final SaveOnboardingDraftUsecase? saveDraft;

  Timer? _countdownTimer;

  /// How long the onboarding test alarm waits before it rings. The countdown
  /// on screen and the alarm the OS holds are both set from this, so they
  /// cannot drift apart.
  static const testAlarmDelaySeconds = 5;

  Future<void> loadConnection() async {
    // What the user typed and where they had got to last time, first: a
    // half-typed server survives a force-quit this way.
    final draft = (await readDraft?.call(const NoParams()))?.getOrNull();
    if (draft != null && !isClosed) {
      emit(
        state.copyWith(
          serverUrl: draft.serverUrl.isEmpty
              ? state.serverUrl
              : draft.serverUrl,
          adminToken: draft.adminToken.isEmpty
              ? state.adminToken
              : draft.adminToken,
          isSelfHosting: draft.isSelfHosting,
        ),
      );
    }

    final result = await getConnection?.call(const NoParams());
    final connection = result?.getOrNull();
    if (connection != null && !isClosed) {
      emit(
        state.copyWith(
          serverUrl: connection.serverUrl,
          status: OnboardingConnectStatus.connected,
        ),
      );
      unawaited(_rememberStep(OnboardingStep.test));
      await loadTestTopic();
      _resumeCountdown(draft);
      return;
    }
    unawaited(_rememberStep(OnboardingStep.connect));
  }

  /// A countdown that was running when the app went away. The alarm itself is
  /// held by the OS, so this only catches the on-screen clock up.
  void _resumeCountdown(OnboardingDraft? draft) {
    final left = draft?.secondsLeft;
    if (left == null) return;
    if (left <= 0) {
      // The alarm is already due or has rung. Go straight to the screen that
      // handles it rather than counting down to something in the past.
      emit(
        state.copyWith(
          isCountingDown: false,
          countdownSeconds: 0,
          testAlarmStatus: TestAlarmStatus.success,
          topic: 'demo-topic',
          incidentId: 'inc_demo',
          canLaunchDemoAlarm: true,
        ),
      );
      unawaited(_saveCountdown(null));
      return;
    }
    emit(
      state.copyWith(
        isCountingDown: true,
        countdownSeconds: left,
        testAlarmStatus: TestAlarmStatus.ringing,
        topic: 'demo-topic',
        incidentId: 'inc_demo',
      ),
    );
    _tickCountdown();
  }

  Future<void> _rememberStep(OnboardingStep step) async {
    final save = saveDraft;
    final read = readDraft;
    if (save == null || read == null) return;
    final current =
        (await read(const NoParams())).getOrNull() ?? const OnboardingDraft();
    await save(
      current.copyWith(
        step: step,
        serverUrl: state.serverUrl,
        adminToken: state.adminToken,
        isSelfHosting: state.isSelfHosting,
      ),
    );
  }

  Future<void> _saveCountdown(DateTime? endsAt) async {
    final save = saveDraft;
    final read = readDraft;
    if (save == null || read == null) return;
    final current =
        (await read(const NoParams())).getOrNull() ?? const OnboardingDraft();
    await save(
      endsAt == null
          ? current.copyWith(clearCountdown: true)
          : current.copyWith(countdownEndsAt: endsAt),
    );
  }

  final EstablishApiSessionUsecase establishSession;
  final GetServerInfoUsecase _getServerInfo;
  final SaveConnectionUsecase _saveConnection;
  final CompleteOnboardingUsecase? completeOnboarding;
  final TriggerTestAlarmUsecase _triggerTestAlarm;

  void toggleSelfHosting() {
    // The failure from the mode the user just left does not belong over the
    // form they just opened.
    emit(
      state.copyWith(
        isSelfHosting: !state.isSelfHosting,
        clearErrorMessage: true,
        clearServerUrlError: true,
        clearAdminTokenError: true,
        clearQrNotice: true,
      ),
    );
    unawaited(_rememberStep(OnboardingStep.connect));
  }

  void serverUrlChanged(String url) {
    emit(
      state.copyWith(
        serverUrl: url,
        requiresAdminToken: false,
        clearAdminTokenError: true,
        clearServerUrlError: true,
        clearErrorMessage: true,
        clearQrNotice: true,
      ),
    );
    unawaited(_rememberStep(OnboardingStep.connect));
  }

  void adminTokenChanged(String token) {
    emit(
      state.copyWith(
        adminToken: token,
        clearAdminTokenError: true,
        clearErrorMessage: true,
        clearQrNotice: true,
      ),
    );
    unawaited(_rememberStep(OnboardingStep.connect));
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

  Future<void> connectToCloud() async {
    serverUrlChanged('https://api.critalarm.app');
    await connect();
  }

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
                errorMessage: failureMessage(failure),
              ),
            ),
          );
        } on Object catch (error) {
          emit(
            state.copyWith(
              status: OnboardingConnectStatus.failure,
              // An exception dump is not a sentence. This one is a transport
              // error, so it gets the transport wording.
              errorMessage: networkFailureMessage(error),
            ),
          );
        }
      },
      (failure) async {
        emit(
          state.copyWith(
            status: OnboardingConnectStatus.failure,
            errorMessage: failureMessage(failure),
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

  /// The local test alarm, set for [testAlarmDelaySeconds] from now.
  ///
  /// The OS holds the alarm, so it rings even if the app is backgrounded or
  /// killed before the countdown ends. When the platform cannot set one, the
  /// countdown is skipped rather than run in silence and then congratulate
  /// the user for a ring that never happened.
  Future<void> startLocalTestAlarm() async {
    _countdownTimer?.cancel();

    final host = alarmHost;
    // Android parses this back out of the alarm intent and drops the whole
    // start when it is not an http or https URL, so an empty string meant the
    // service stopped itself and the countdown below congratulated the user
    // for a ring that never happened.
    final server = state.serverUrl.trim();
    final scheduled =
        host != null &&
        server.isNotEmpty &&
        await host
              .scheduleAlarm(
                incidentId: 'inc_demo',
                topic: 'demo-topic',
                server: server,
                title: LocaleKeys.onboarding_connect_demo_alarm_title.tr(),
                body: LocaleKeys.onboarding_connect_demo_alarm_body.tr(),
                delaySeconds: testAlarmDelaySeconds,
                // inc_demo is not on the server. The flag travels with the
                // alarm to the Stop button on its notification, so that
                // button leaves no card behind either.
                handOverToStatusCard: false,
              )
              .catchError((_) => false);
    if (isClosed) return;

    if (!scheduled) {
      emit(
        state.copyWith(
          isCountingDown: false,
          countdownSeconds: testAlarmDelaySeconds,
          testAlarmStatus: TestAlarmStatus.failure,
          topic: 'demo-topic',
          incidentId: 'inc_demo',
          errorMessage: LocaleKeys.onboarding_connect_hook_no_alarm_body.tr(),
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        isCountingDown: true,
        countdownSeconds: testAlarmDelaySeconds,
        testAlarmStatus: TestAlarmStatus.ringing,
        topic: 'demo-topic',
        incidentId: 'inc_demo',
        canLaunchDemoAlarm: false,
        clearErrorMessage: true,
      ),
    );
    unawaited(
      _saveCountdown(
        DateTime.now().add(const Duration(seconds: testAlarmDelaySeconds)),
      ),
    );
    _tickCountdown();
  }

  /// Drives the on-screen clock. The alarm is already set; this only counts.
  void _tickCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final nextSec = state.countdownSeconds - 1;
      if (nextSec <= 0) {
        timer.cancel();
        unawaited(_saveCountdown(null));
        emit(
          state.copyWith(
            countdownSeconds: 0,
            isCountingDown: false,
            testAlarmStatus: TestAlarmStatus.success,
            canLaunchDemoAlarm: true,
          ),
        );
      } else {
        emit(state.copyWith(countdownSeconds: nextSec));
      }
    });
  }

  void cancelCountdown() {
    _countdownTimer?.cancel();
    final host = alarmHost;
    if (host != null) {
      // No handover. inc_demo is not on the server, so an acked card for it
      // would sit there for good: it is ongoing, so it cannot be swiped away,
      // and its Done button would POST a close for an incident that does not
      // exist.
      unawaited(
        host
            .cancelAlarm('inc_demo', handOverToStatusCard: false)
            .catchError((_) => false),
      );
    }
    unawaited(_saveCountdown(null));
    emit(
      state.copyWith(
        isCountingDown: false,
        countdownSeconds: testAlarmDelaySeconds,
        testAlarmStatus: TestAlarmStatus.idle,
      ),
    );
  }

  void demoAlarmHandled() {
    emit(state.copyWith(canLaunchDemoAlarm: false));
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
            errorMessage: failureMessage(failure),
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
        isCountingDown: false,
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
      (failure) => emit(state.copyWith(errorMessage: failureMessage(failure))),
    );
  }

  void navigationHandled() {
    emit(state.copyWith(canNavigateToHome: false));
  }

  @override
  Future<void> close() {
    _countdownTimer?.cancel();
    return super.close();
  }
}
