import 'dart:async';

import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/api/network_failure_message.dart';
import 'package:critalarm/core/models/server_info_validator.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/incidents/domain/setup_test_kind.dart';
import 'package:critalarm/features/onboarding/domain/connect/background_connect.dart';
import 'package:critalarm/features/onboarding/domain/connect/connect_privacy_line.dart';
import 'package:critalarm/features/onboarding/domain/entities/onboarding_draft.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_replay_rules.dart';
import 'package:critalarm/features/onboarding/domain/usecases/connect_to_server_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/establish_api_session_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_server_info_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/onboarding_draft_usecases.dart';
import 'package:critalarm/features/onboarding/domain/usecases/save_connection_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/set_up_later_usecase.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_connect_state.dart';
import 'package:critalarm/features/onboarding/presentation/model/background_connect_copy.dart';
import 'package:critalarm/features/onboarding/presentation/model/connect_outcome_message.dart';
import 'package:critalarm/features/onboarding/presentation/model/local_test_alarm.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Cubit behind two setup steps that share a screen file: the server
/// connection (admin token input, compatibility validation) and the local
/// test alarm of the first shipped order.
class OnboardingConnectCubit extends Cubit<OnboardingConnectState> {
  OnboardingConnectCubit(
    this._getServerInfo,
    this._saveConnection, {
    required this.establishSession,
    this.getTopics,
    this.getConnection,
    this.setUpLater,
    this.alarmHost,
    this.readDraft,
    this.saveDraft,
    this.backgroundConnect,
    ConnectToServerUsecase? connectToServer,
    Future<bool> Function()? isOnline,
    bool initialConnected = false,
  }) : _sharedConnect = connectToServer,
       _isOnline = isOnline ?? hasInternet,
       super(
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

  /// Runs the Crit Alarm Cloud connect behind the user. Null in tests that
  /// only exercise the form, where Cloud connects in the foreground.
  final BackgroundConnect? backgroundConnect;

  /// Asked only when the Cloud did not answer, to tell "no network" from a
  /// server that is slow or down.
  final Future<bool> Function() _isOnline;

  /// Where Crit Alarm Cloud lives.
  static const cloudUrl = 'https://api.critalarm.app';

  /// False on a replay, which writes no draft.
  bool _savesDraft = true;

  SaveOnboardingDraftUsecase? get _draftWriter =>
      _savesDraft ? saveDraft : null;

  /// How long the onboarding test alarm waits before it rings.
  static const int testAlarmDelaySeconds = LocalTestAlarm.delaySeconds;

  /// The alarm the phone sets for itself. The logic lives in
  /// [LocalTestAlarm], shared with the real ring step.
  late final LocalTestAlarm _localTest = LocalTestAlarm(
    host: alarmHost,
    onChanged: _showLocalTest,
    saveCountdownEndsAt: _saveCountdown,
  );

  void _showLocalTest(LocalTestAlarmState test) {
    if (isClosed) return;
    final failed = test.isFailure;
    emit(
      state.copyWith(
        alarm: test.alarm,
        testAlarmStatus: test.status,
        isCountingDown: test.isCountingDown,
        countdownSeconds: test.countdownSeconds,
        canLaunchDemoAlarm: test.canLaunch,
        topic: test.status == TestAlarmStatus.idle ? null : phoneOnlyTestTopic,
        incidentId: test.status == TestAlarmStatus.idle
            ? null
            : phoneOnlyTestIncidentId,
        errorMessage: failed
            ? LocaleKeys.onboarding_connect_hook_no_alarm_body.tr()
            : null,
        clearErrorMessage: test.status == TestAlarmStatus.ringing,
      ),
    );
  }

  /// [adoptSavedConnection] false leaves the form up even when a server is
  /// already saved, for a replay that is only a look at the connect screen.
  ///
  /// [isReplay] keeps the form from writing the saved draft.
  Future<void> loadConnection({
    bool adoptSavedConnection = true,
    bool isReplay = false,
  }) async {
    _savesDraft = onboardingSavesFormDraft(isReplay: isReplay);
    final authorization = await alarmHost?.authorizationStatus();
    if (authorization != null && !isClosed) {
      emit(state.copyWith(alarm: authorization));
    }

    // What the user typed last time, first: a half-typed server survives a
    // force-quit this way.
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

    // Sent back here by a connect that gave up behind the user: say why.
    final background = backgroundConnect?.state;
    if (background != null && background.isFailed && !isClosed) {
      emit(state.copyWith(errorMessage: backgroundConnectLine(background)));
    }

    final result = await getConnection?.call(const NoParams());
    final connection = result?.getOrNull();
    if (connection != null && adoptSavedConnection && !isClosed) {
      emit(
        state.copyWith(
          serverUrl: connection.serverUrl,
          status: OnboardingConnectStatus.connected,
        ),
      );
      await loadTestTopic();
      _resumeCountdown(draft);
    }
  }

  /// A countdown that was running when the app went away.
  void _resumeCountdown(OnboardingDraft? draft) {
    final left = draft?.secondsLeft;
    if (left == null) return;
    _localTest.resume(left);
  }

  /// Keeps the half-typed form. Which step the user is on is not saved here:
  /// the flow engine works that out.
  Future<void> _rememberForm() async {
    final save = _draftWriter;
    final read = readDraft;
    if (save == null || read == null) return;
    final current =
        (await read(const NoParams())).getOrNull() ?? const OnboardingDraft();
    await save(
      current.copyWith(
        serverUrl: state.serverUrl,
        adminToken: state.adminToken,
        isSelfHosting: state.isSelfHosting,
      ),
    );
  }

  Future<void> _forgetForm() async {
    final save = _draftWriter;
    final read = readDraft;
    if (save == null || read == null) return;
    final current =
        (await read(const NoParams())).getOrNull() ?? const OnboardingDraft();
    await save(OnboardingDraft(countdownEndsAt: current.countdownEndsAt));
  }

  Future<void> _saveCountdown(DateTime? endsAt) async {
    final save = _draftWriter;
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

  /// The one way a server is connected, shared with a connect link. Built
  /// from the three parts when the app does not hand it over, as tests do.
  final ConnectToServerUsecase? _sharedConnect;
  late final ConnectToServerUsecase _connectToServer =
      _sharedConnect ??
      ConnectToServerUsecase(
        _getServerInfo,
        establishSession,
        _saveConnection,
        cancelPendingConnect: backgroundConnect?.cancel,
      );

  /// The "Set this up later" exit. Null in tests that never leave.
  final SetUpLaterUsecase? setUpLater;

  void toggleSelfHosting() {
    // The failure from the mode the user just left does not belong over the
    // form they just opened.
    emit(
      state.copyWith(
        isSelfHosting: !state.isSelfHosting,
        clearErrorMessage: true,
        clearServerUrlError: true,
        clearAdminTokenError: true,
      ),
    );
    unawaited(_rememberForm());
  }

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
    unawaited(_rememberForm());
  }

  void adminTokenChanged(String token) {
    emit(
      state.copyWith(
        adminToken: token,
        clearAdminTokenError: true,
        clearErrorMessage: true,
      ),
    );
    unawaited(_rememberForm());
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

  static bool isSemverCompatible(String version) =>
      ServerInfoValidation.isSemverCompatible(version);

  /// Asks Crit Alarm Cloud for its `/v1/info`. One request answers two
  /// questions: whether the phone is online, and which privacy line is true.
  Future<void> probeCloud() async {
    final result = await _getServerInfo(Uri.parse(cloudUrl));
    if (isClosed) return;
    final info = result.getOrNull();
    if (info != null) {
      final line = connectPrivacyLine(
        mode: info.mode,
        relayContent: info.statedRelayContent,
      );
      emit(
        state.copyWith(
          cloudOnline: true,
          cloudPrivacyLine: line,
          clearCloudPrivacyLine: line == null,
        ),
      );
      return;
    }
    // No answer, so no line. Whether that is the network or the server is a
    // separate question.
    final online = await _isOnline();
    if (isClosed) return;
    emit(state.copyWith(cloudOnline: online, clearCloudPrivacyLine: true));
  }

  /// Continue with Crit Alarm Cloud. Hands the connect to
  /// [backgroundConnect] and answers as soon as the intent is on disk, so
  /// the screen can move on at once, online or not.
  ///
  /// [waitForResult] is for the screen opened on its own after setup, from
  /// Home or Server settings. There is no next step to move on to, so the
  /// screen stays up, says what the connect is doing, and closes when it
  /// lands. Leaving early is fine: the connect carries on.
  Future<void> connectToCloud({bool waitForResult = false}) async {
    final background = backgroundConnect;
    if (background == null) {
      serverUrlChanged(cloudUrl);
      await connect();
      return;
    }
    emit(state.copyWith(clearErrorMessage: true));
    await background.start(cloudUrl);
    if (!waitForResult || isClosed) return;
    _showCloudConnect(background.state);
    await _cloudConnectChanges?.cancel();
    _cloudConnectChanges = background.stream.listen(_showCloudConnect);
  }

  StreamSubscription<BackgroundConnectState>? _cloudConnectChanges;

  void _showCloudConnect(BackgroundConnectState connect) {
    if (isClosed) return;
    if (connect.isPending) {
      emit(
        state.copyWith(
          status: OnboardingConnectStatus.connecting,
          cloudWaitLine: backgroundConnectLine(connect),
          clearErrorMessage: true,
        ),
      );
    } else if (connect.isConnected) {
      emit(
        state.copyWith(
          serverUrl: connect.serverUrl,
          status: OnboardingConnectStatus.connected,
          clearCloudWaitLine: true,
          clearErrorMessage: true,
        ),
      );
    } else {
      emit(
        state.copyWith(
          status: connect.isFailed
              ? OnboardingConnectStatus.failure
              : OnboardingConnectStatus.idle,
          errorMessage: connect.isFailed
              ? backgroundConnectLine(connect)
              : null,
          clearCloudWaitLine: true,
        ),
      );
    }
  }

  /// Connects to the server in the form, in the foreground: the user typed
  /// an address and wants to know it worked.
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

    emit(
      state.copyWith(
        status: OnboardingConnectStatus.connecting,
        clearServerUrlError: true,
        clearAdminTokenError: true,
        clearErrorMessage: true,
        clearConfirmation: true,
      ),
    );
    // The user picked a server by hand, so a Cloud connect still waiting
    // behind them is no longer wanted. The use case drops the background
    // half of it.
    await _cloudConnectChanges?.cancel();
    _cloudConnectChanges = null;

    final outcome = await _connectToServer(
      serverUrl: trimmedUrl,
      adminToken: state.adminToken,
    );
    switch (outcome) {
      case Connected(:final info):
        // The form has done its job. Left behind, the typed admin token
        // would sit in the draft for as long as the app lives when the
        // screen was opened after setup.
        await _forgetForm();
        await loadTestTopic();
        emit(
          state.copyWith(
            serverUrl: info.baseUrl,
            status: OnboardingConnectStatus.connected,
            clearErrorMessage: true,
            // Typed by hand: show that it worked before moving on.
            confirmation: state.isSelfHosting
                ? ConnectConfirmation(
                    host: _hostOf(info.baseUrl),
                    privacyLine: connectPrivacyLine(
                      mode: info.mode,
                      relayContent: info.statedRelayContent,
                    ),
                  )
                : null,
          ),
        );
      case AdminTokenMissing():
        emit(
          state.copyWith(
            status: OnboardingConnectStatus.idle,
            requiresAdminToken: true,
            adminTokenError: LocaleKeys
                .onboarding_connect_admin_token_error_empty
                .tr(),
          ),
        );
      case ServerUnreachable() ||
          ServerAddressDiffers() ||
          ServerDowngrade() ||
          ServerIncompatible() ||
          ConnectionNotSaved() ||
          ConnectTransportError():
        emit(
          state.copyWith(
            status: OnboardingConnectStatus.failure,
            errorMessage: connectOutcomeMessage(outcome),
          ),
        );
    }
  }

  /// The part of a server address a person recognises: the host, with the
  /// port when it is not the usual one.
  static String _hostOf(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return url;
    return uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
  }

  /// The host of the address in the form, for the line shown while it is
  /// being checked.
  String get typedHost => _hostOf(state.serverUrl.trim());

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
  Future<void> startLocalTestAlarm() =>
      _localTest.start(server: state.serverUrl);

  void cancelCountdown() => _localTest.cancel();

  void demoAlarmHandled() => _localTest.launched();

  void editConnection() {
    emit(
      state.copyWith(
        status: OnboardingConnectStatus.idle,
        testAlarmStatus: TestAlarmStatus.idle,
        isCountingDown: false,
        clearErrorMessage: true,
        clearConfirmation: true,
      ),
    );
  }

  /// Set this up later, and "Go to your topics" on the test step: leaves
  /// setup for Home. A replay completes nothing.
  Future<void> navigateToHome({bool isReplay = false}) async {
    final leave = setUpLater;
    if (leave == null) return;

    final result = await leave(isReplay: isReplay);
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
    unawaited(_cloudConnectChanges?.cancel());
    _localTest.dispose();
    return super.close();
  }
}
