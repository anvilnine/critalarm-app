import 'dart:async';

import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/entities/notification_permission_status.dart';
import 'package:critalarm/features/onboarding/domain/usecases/open_notification_settings_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/read_permission_setup_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/request_notification_permission_usecase.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/notification_permissions_state.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/features/permissions/domain/entities/permission_setup_step.dart';
import 'package:critalarm/features/permissions/domain/repositories/device_permissions_repository.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Walks the permission steps of this phone, one at a time.
///
/// The steps come from `permissionSetupStepsFor` through [readSetup], which
/// also reads each one's status. Nothing is drawn before that read: the
/// state has no current step until the cubit knows which one the user still
/// needs, so a granted step never shows.
class NotificationPermissionsCubit extends Cubit<NotificationPermissionsState> {
  NotificationPermissionsCubit(
    this._requestPermission,
    this._openSettings, {
    required this.readSetup,
    this.alarm,
    this.devicePermissions,
    this.replayForDemo = false,
    this.standalone = false,
    this.readTimeout = const Duration(seconds: 5),
    NotificationPermissionStep initialStep = NotificationPermissionStep.initial,
  }) : super(NotificationPermissionsState(step: initialStep));

  final RequestNotificationPermissionUsecase _requestPermission;
  final OpenNotificationSettingsUsecase _openSettings;

  /// Reads the step list and every status. The flow engine asks the same
  /// reader whether the permissions step is already satisfied.
  final ReadPermissionSetupUsecase readSetup;

  /// Asks for AlarmKit and starts the one local Live Activity. Null in tests
  /// that never reach the alarm step.
  final AlarmHost? alarm;

  /// Opens the settings page behind an Android step. The same repository
  /// Health uses, so there is one channel for it.
  final DevicePermissionsRepository? devicePermissions;

  /// True when the developer menu opened onboarding to look at it. Then every
  /// step is shown even where the permission is already granted, because the
  /// point is seeing the screens, not getting through them.
  final bool replayForDemo;

  /// True when Health opened this screen on its own, outside onboarding, to
  /// ask for a permission the user has never been asked. Then only a real
  /// system prompt earns a step, and the screen closes once none is left.
  final bool standalone;

  /// How long a status read may take. A read that is still out after this
  /// is given up on, so the screen is never left checking for good.
  final Duration readTimeout;

  /// The step whose system dialog is open. Its answer, yes or no, moves on.
  PermissionSetupStep? _dialogOpenFor;

  PermissionAskMode get _mode => replayForDemo
      ? PermissionAskMode.replay
      : standalone
      ? PermissionAskMode.standalone
      : PermissionAskMode.setup;

  /// The incident id the onboarding card uses. Not a real incident: it exists
  /// so the Allow prompt for Live Activities happens here rather than the
  /// first time the relay tries a remote start.
  static const onboardingIncidentId = 'inc_onboarding';

  /// Reads the system state without prompting, and lands on the first step
  /// that still needs an answer.
  ///
  /// Called when the screen opens and again every time the app comes back to
  /// the front. That is how a step behind a settings page finishes, and how a
  /// permission granted over in Settings is picked up without the user
  /// having to find a retry button. Nothing is assumed between reads.
  Future<void> refresh() async {
    // A system dialog sends the app to the background and back, which lands
    // here. Leave a request that is still running alone.
    if (state.isRequesting || state.isGranted) return;

    emit(state.copyWith(isChecking: true));
    PermissionSetupSnapshot? snapshot;
    try {
      // Null when the read timed out or failed. Nothing is known then, so
      // nothing changes: "Not now" is on screen either way, and the next
      // resume reads again.
      snapshot = await _readWithinTimeout();
    } finally {
      if (!isClosed) emit(state.copyWith(isChecking: false));
    }
    if (isClosed || snapshot == null) return;
    // The user answered while the read was out. Their answer stands.
    if (state.isRequesting || state.isGranted) return;

    final read = _withSteps(
      state.copyWith(
        available: snapshot.steps,
        granted: snapshot.granted,
        promptSpent: snapshot.promptSpent,
        alarm: snapshot.alarm,
        clearError: true,
      ),
    );

    // The denied screen stays until the user leaves it. It only closes
    // itself when Settings fixed everything while the app was away.
    if (state.isDenied) {
      emit(snapshot.everyGranted ? _finished(read) : read);
      return;
    }

    // A system dialog was open and the user is back. Yes or no, that was
    // their answer, and a refusal moves on like a refused notification.
    final answered = _dialogOpenFor;
    _dialogOpenFor = null;

    // A granted step is not worth a screen, the one on screen included: a
    // switch turned on in Settings moves the user on when they come back. A
    // replay stays put, because it is there to be looked at.
    final current = state.current;
    final stillNeeded =
        current != null &&
        current != answered &&
        (replayForDemo || !snapshot.granted.contains(current));
    if (stillNeeded) {
      emit(read);
      return;
    }
    _moveOn(read);
  }

  /// The status read, given up on after [readTimeout]. A read that hangs
  /// answers null rather than leaving the screen checking for good. The
  /// timer is the cubit's own, so closing the screen stops it.
  Future<PermissionSetupSnapshot?> _readWithinTimeout() {
    final done = Completer<PermissionSetupSnapshot?>();
    void finish(PermissionSetupSnapshot? snapshot) {
      if (!done.isCompleted) done.complete(snapshot);
    }

    _readTimer?.cancel();
    final timer = _readTimer = Timer(readTimeout, () => finish(null));
    unawaited(
      readSetup().then<void>(finish, onError: (Object _) => finish(null)),
    );
    return done.future.whenComplete(timer.cancel);
  }

  Timer? _readTimer;

  @override
  Future<void> close() {
    _readTimer?.cancel();
    return super.close();
  }

  /// Brings the list on screen up to date with what is granted now. The
  /// first time, that is the list the dots are drawn from. After that it is
  /// frozen: a step can only be added at its end.
  NotificationPermissionsState _withSteps(NotificationPermissionsState from) {
    final fresh = permissionStepsToRender(
      from.available,
      granted: from.granted,
      mode: _mode,
      alreadyShown: from.shown,
      cannotAsk: from.promptSpent,
    );
    return from.copyWith(
      steps: freezePermissionSteps(from.steps, fresh, order: from.available),
    );
  }

  /// The main button of the step on screen.
  Future<void> allowCurrentStep() async {
    final current = state.current;
    if (current == null || state.isRequesting) return;
    switch (current) {
      case PermissionSetupStep.iosNotifications:
      case PermissionSetupStep.androidNotifications:
        await _requestNotifications(current);
      case PermissionSetupStep.iosAlarms:
        await _requestAlarm(current);
      case PermissionSetupStep.iosTimeSensitiveExplainer:
        // Nothing to ask for. The button only reads "Continue".
        skipStep();
      case PermissionSetupStep.androidFullScreen:
        await _openSettingsPage(DevicePermissionType.fullScreenIntent);
      case PermissionSetupStep.androidBattery:
        // Android asks for this one in a dialog. Coming back from it is an
        // answer, whichever button was tapped.
        _dialogOpenFor = current;
        await _openSettingsPage(DevicePermissionType.batteryOptimization);
    }
  }

  /// "Not now", and what a refused or failed prompt does too: move to the
  /// next step without asking, or finish when there is none.
  void skipStep() {
    _dialogOpenFor = null;
    _moveOn(state);
  }

  Future<void> _requestNotifications(PermissionSetupStep current) async {
    // The system will not prompt again, so asking would do nothing. The
    // switch is in Settings: open it and wait, as for any settings step.
    if (state.promptSpent.contains(current)) {
      await _openSettings(const NoParams());
      return;
    }
    emit(
      state.copyWith(
        step: NotificationPermissionStep.requesting,
        clearError: true,
        canNavigate: false,
      ),
    );

    final result = await _requestPermission(const NoParams());
    if (isClosed) return;

    // A refusal moves on like a grant does. Home's health banner keeps
    // asking later.
    final granted = result.getOrNull() == NotificationPermissionStatus.granted;
    _moveOn(
      state.copyWith(granted: {...state.granted, if (granted) current}),
    );
  }

  /// The AlarmKit prompt, and with it the one local Live Activity.
  ///
  /// A denial does not stop onboarding. Apple's own guidance is that the app
  /// must not hold the user hostage over a permission, and AlarmKit never
  /// prompts twice, so refusing to move on would strand them for good.
  Future<void> _requestAlarm(PermissionSetupStep current) async {
    final alarmHost = alarm;
    if (alarmHost == null) {
      skipStep();
      return;
    }

    emit(
      state.copyWith(
        step: NotificationPermissionStep.requesting,
        clearError: true,
      ),
    );

    final authorization = await alarmHost.requestAuthorization();
    final started = await alarmHost.startLocalActivity(
      incidentId: onboardingIncidentId,
      topic: 'setup',
      server: '',
      title: LocaleKeys.onboarding_connect_ready_activity_title.tr(),
      state: 'acked',
    );
    if (isClosed) return;

    _moveOn(
      state.copyWith(
        alarm: authorization,
        liveActivityStarted: started,
        granted: {
          ...state.granted,
          if (authorization == AlarmAuthorization.authorized) current,
        },
      ),
    );
  }

  /// Android has no prompt for these. The permission lives on a settings
  /// page, so open it and wait here. Coming back re-reads it through
  /// [refresh], and "Not now" is still on screen for a user who says no.
  Future<void> _openSettingsPage(DevicePermissionType type) async {
    final repo = devicePermissions;
    if (repo == null) {
      skipStep();
      return;
    }
    await repo.openPermissionSettings(type);
  }

  void _moveOn(NotificationPermissionsState before) {
    final from = _withSteps(before);
    final next = nextPermissionStep(
      from.steps,
      alreadyShown: from.shown,
      granted: from.granted,
      showGranted: replayForDemo,
    );
    emit(
      next == null
          ? _finished(from)
          : from.copyWith(
              current: next,
              step: NotificationPermissionStep.initial,
              canNavigate: false,
              clearError: true,
            ),
    );
  }

  NotificationPermissionsState _finished(NotificationPermissionsState from) =>
      from.copyWith(
        step: NotificationPermissionStep.granted,
        canNavigate: true,
        isChecking: false,
        clearError: true,
      );

  /// Leaves the permission unanswered and carries on. The app says what it
  /// cannot do rather than blocking, and the health banner keeps asking later.
  void continueWithout() => emit(_finished(state));

  /// Opens the system app notification settings.
  Future<void> openSettings() async {
    await _openSettings(const NoParams());
  }

  /// Resets the navigation trigger once handled by the router.
  void navigationHandled() {
    emit(state.copyWith(canNavigate: false));
  }
}
