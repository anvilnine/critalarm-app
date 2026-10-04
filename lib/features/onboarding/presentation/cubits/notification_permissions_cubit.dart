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
    final snapshot = await readSetup();
    if (isClosed) return;
    // The user answered while the read was out. Their answer stands.
    if (state.isRequesting || state.isGranted) {
      emit(state.copyWith(isChecking: false));
      return;
    }

    final shown = state.shown;
    final rendered = permissionStepsToRender(
      snapshot.steps,
      granted: snapshot.granted,
      mode: _mode,
      alreadyShown: shown,
      // AlarmKit prompts once. After a refusal there is no prompt left.
      cannotAsk: {
        if (snapshot.alarm == AlarmAuthorization.denied)
          PermissionSetupStep.iosAlarms,
      },
    );
    final read = state.copyWith(
      isChecking: false,
      steps: rendered,
      granted: snapshot.granted,
      alarm: snapshot.alarm,
      clearError: true,
    );

    // The denied screen stays until the user leaves it. It only closes
    // itself when Settings fixed everything while the app was away.
    if (state.isDenied) {
      emit(snapshot.everyGranted ? _finished(read) : read);
      return;
    }

    // A granted step is not worth a screen, the one on screen included: a
    // switch turned on in Settings moves the user on when they come back. A
    // replay stays put, because it is there to be looked at.
    final current = state.current;
    final stillNeeded =
        current != null &&
        (replayForDemo || !snapshot.granted.contains(current));
    if (stillNeeded) {
      emit(read);
      return;
    }

    final next = nextPermissionStep(rendered, alreadyShown: shown);
    emit(next == null ? _finished(read) : read.copyWith(current: next));
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
        await _openSettingsPage(DevicePermissionType.batteryOptimization);
    }
  }

  /// "Not now", and what a refused or failed prompt does too: move to the
  /// next step without asking, or finish when there is none.
  void skipStep() => _moveOn(state);

  Future<void> _requestNotifications(PermissionSetupStep current) async {
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

  void _moveOn(NotificationPermissionsState from) {
    final next = nextPermissionStep(from.steps, alreadyShown: from.shown);
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
