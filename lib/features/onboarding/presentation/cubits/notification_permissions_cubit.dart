import 'dart:math' as math;

import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/entities/notification_permission_status.dart';
import 'package:critalarm/features/onboarding/domain/usecases/check_notification_permission_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/open_notification_settings_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/request_notification_permission_usecase.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/notification_permissions_state.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_status.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/features/permissions/domain/repositories/device_permissions_repository.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Cubit managing the Screen 1 Permissions step (Option B: 2-step stepper).
class NotificationPermissionsCubit extends Cubit<NotificationPermissionsState> {
  NotificationPermissionsCubit(
    this._requestPermission,
    this._openSettings, {
    this.alarm,
    this.checkPermission,
    this.devicePermissions,
    TargetPlatform? platform,
    this.replayForDemo = false,
    this.standalone = false,
    NotificationPermissionStep initialStep = NotificationPermissionStep.initial,
  }) : _platform = platform ?? defaultTargetPlatform,
       super(NotificationPermissionsState(step: initialStep));

  final RequestNotificationPermissionUsecase _requestPermission;
  final OpenNotificationSettingsUsecase _openSettings;

  /// Null off iOS, and in tests that only care about the notification step.
  final AlarmHost? alarm;

  /// Null in tests that do not exercise the skip-what-is-granted path.
  final CheckNotificationPermissionUsecase? checkPermission;

  /// Reads and opens the Android full-screen alarm permission. The same
  /// repository Health uses, so there is one channel for it. Null in tests
  /// and off Android.
  final DevicePermissionsRepository? devicePermissions;

  final TargetPlatform _platform;

  /// Android with a way to ask: step 2 is the full-screen alarm permission.
  bool get _androidFullScreen =>
      !kIsWeb &&
      _platform == TargetPlatform.android &&
      devicePermissions != null;

  Future<bool> _readFullScreenGranted() async {
    final repo = devicePermissions;
    if (repo == null) return false;
    final result = await repo.checkPermission(
      DevicePermissionType.fullScreenIntent,
    );
    return result.fold(
      (status) => status == DevicePermissionStatus.granted,
      (_) => false,
    );
  }

  /// True when the developer menu opened onboarding to look at it. Then every
  /// step is shown even where the permission is already granted, because the
  /// point is seeing the screens, not getting through them.
  final bool replayForDemo;

  /// True when Health opened this screen on its own, outside onboarding, to
  /// ask for a permission the user has never been asked. Then only a real
  /// system prompt earns a step, and the screen closes once none is left.
  final bool standalone;

  /// Whether step 2 still has a prompt behind it. In onboarding it always
  /// shows, even as an explanation. On its own it needs AlarmKit to be able
  /// to ask, which it does only once.
  bool _hasAlarmStep(AlarmAuthorization authorization, {bool? fullScreen}) {
    if (_androidFullScreen) {
      return !standalone || !(fullScreen ?? state.fullScreenGranted);
    }
    return !standalone || authorization == AlarmAuthorization.notDetermined;
  }

  /// The incident id the onboarding card uses. Not a real incident: it exists
  /// so the Allow prompt for Live Activities happens here rather than the
  /// first time the relay tries a remote start.
  static const onboardingIncidentId = 'inc_onboarding';

  /// Reads the system state without prompting, and moves past anything the
  /// user has already granted.
  ///
  /// Called when the screen opens and again every time the app comes back to
  /// the front, so a permission granted over in Settings is picked up without
  /// the user having to find a retry button.
  Future<void> refresh() async {
    final check = checkPermission;
    final alarmHost = alarm;
    if (check == null && alarmHost == null) {
      return;
    }
    // A system dialog sends the app to the background and back, which lands
    // here. Leave a request that is still running alone.
    if (state.isRequesting) return;

    emit(state.copyWith(isChecking: true));

    var notificationsGranted = state.notificationsGranted;
    if (check != null) {
      final result = await check(const NoParams());
      notificationsGranted = result.fold(
        (status) => status == NotificationPermissionStatus.granted,
        (_) => notificationsGranted,
      );
    }

    var authorization = state.alarm;
    if (alarmHost != null) {
      authorization = await alarmHost.authorizationStatus();
    }
    // Android, and iOS below 26, have no alarm permission to ask for. There is
    // one step on those phones, not two.
    final alarmSupported =
        alarmHost != null && authorization != AlarmAuthorization.unsupported;
    final androidStep = _androidFullScreen;
    final fullScreenGranted = androidStep && await _readFullScreenGranted();
    final alarmGranted = androidStep
        ? fullScreenGranted
        : authorization == AlarmAuthorization.authorized;

    final hasStep2 =
        (alarmSupported || androidStep) &&
        _hasAlarmStep(authorization, fullScreen: fullScreenGranted);

    if (isClosed) return;

    if (replayForDemo) {
      emit(
        state.copyWith(
          isChecking: false,
          alarm: authorization,
          alarmSupported: alarmSupported,
          fullScreenStep: androidStep,
          fullScreenGranted: fullScreenGranted,
          notificationsGranted: notificationsGranted,
        ),
      );
      return;
    }

    // Without an alarm permission to ask for, step 2 only explains what this
    // phone does. There is nothing left to grant.
    final step2Granted = !hasStep2 || alarmGranted;
    final everythingGranted = notificationsGranted && step2Granted;

    emit(
      state.copyWith(
        isChecking: false,
        alarm: authorization,
        alarmSupported: alarmSupported,
        fullScreenStep: androidStep,
        fullScreenGranted: fullScreenGranted,
        notificationsGranted: notificationsGranted,
        criticalAlertsGranted:
            alarmGranted || (!alarmSupported && !androidStep),
        // A granted step is not worth a screen. Land on the first one that
        // still needs an answer, but never send the user back a step they
        // already answered or skipped.
        activeSubstep: math.max(
          state.activeSubstep,
          notificationsGranted && hasStep2 ? 1 : 0,
        ),
        step: everythingGranted
            ? NotificationPermissionStep.granted
            : NotificationPermissionStep.initial,
        canNavigate: everythingGranted,
        clearError: true,
      ),
    );
  }

  /// Step 1: Requests system notification permission.
  Future<void> requestNotifications() async {
    emit(
      state.copyWith(
        step: NotificationPermissionStep.requesting,
        clearError: true,
        canNavigate: false,
      ),
    );

    final result = await _requestPermission(const NoParams());
    if (isClosed) return;

    result.fold(
      (status) {
        if (status == NotificationPermissionStatus.granted) {
          _afterNotificationsGranted();
        } else {
          // A refusal moves on. Home's health banner keeps asking later.
          skipStep();
        }
      },
      (_) => skipStep(),
    );
  }

  /// "Not now", and what a refused or failed prompt does too: move to the
  /// next step without asking, or finish when there is none.
  void skipStep() {
    if (state.activeSubstep == 0 &&
        alarm != null &&
        _hasAlarmStep(state.alarm)) {
      emit(
        state.copyWith(
          activeSubstep: 1,
          step: NotificationPermissionStep.initial,
          canNavigate: false,
          clearError: true,
        ),
      );
      return;
    }
    continueWithout();
  }

  void _afterNotificationsGranted() {
    final alarmHost = alarm;
    if (alarmHost == null || !_hasAlarmStep(state.alarm)) {
      emit(
        state.copyWith(
          notificationsGranted: true,
          criticalAlertsGranted:
              alarmHost == null || state.criticalAlertsGranted,
          alarmSupported: alarmHost != null && state.alarmSupported,
          step: NotificationPermissionStep.granted,
          canNavigate: true,
          clearError: true,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        notificationsGranted: true,
        activeSubstep: 1,
        step: NotificationPermissionStep.initial,
        clearError: true,
      ),
    );
  }

  /// Step 2: the alarm permission (AlarmKit on iOS 26 and up).
  ///
  /// A denial no longer stops onboarding. Apple's own guidance is that the app
  /// must not hold the user hostage over a permission, and AlarmKit never
  /// prompts twice, so refusing to move on would strand them for good.
  Future<void> requestCriticalAlerts() async {
    final alarmHost = alarm;
    if (_androidFullScreen) {
      // Android has no prompt. The permission lives on a settings page, so
      // open it and wait here. Coming back re-reads it through [refresh], and
      // "Not now" is still on screen for a user who says no.
      await devicePermissions!.openPermissionSettings(
        DevicePermissionType.fullScreenIntent,
      );
      return;
    }
    if (alarmHost == null) {
      emit(
        state.copyWith(
          criticalAlertsGranted: true,
          alarmSupported: false,
          step: NotificationPermissionStep.granted,
          canNavigate: true,
        ),
      );
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

    // `unsupported` is not a grant. It means this OS has no such permission,
    // so the step is not a step here and the app must not claim the alarm
    // will ring through silent mode.
    final supported = authorization != AlarmAuthorization.unsupported;
    emit(
      state.copyWith(
        alarm: authorization,
        alarmSupported: supported,
        liveActivityStarted: started,
        criticalAlertsGranted:
            authorization == AlarmAuthorization.authorized || !supported,
        step: NotificationPermissionStep.granted,
        canNavigate: true,
        clearError: true,
      ),
    );
  }

  /// Leaves the permission unanswered and carries on. The app says what it
  /// cannot do rather than blocking, and the health banner keeps asking later.
  void continueWithout() {
    emit(
      state.copyWith(
        step: NotificationPermissionStep.granted,
        canNavigate: true,
        clearError: true,
      ),
    );
  }

  /// Backward-compatible combined request for tests or single-tap.
  Future<void> requestPermissions() async {
    if (state.activeSubstep == 0 && !state.notificationsGranted) {
      await requestNotifications();
    } else {
      await requestCriticalAlerts();
    }
  }

  /// The two iOS prompts that follow the notification one.
  Future<void> requestAlarmAndActivity() => requestCriticalAlerts();

  /// Reads the alarm state back without prompting, for the status row.
  Future<void> refreshAlarmAuthorization() async {
    final alarmHost = alarm;
    if (alarmHost == null) return;
    emit(state.copyWith(alarm: await alarmHost.authorizationStatus()));
  }

  /// Opens the system app notification settings.
  Future<void> openSettings() async {
    await _openSettings(const NoParams());
  }

  /// Resets the navigation trigger once handled by the router.
  void navigationHandled() {
    emit(state.copyWith(canNavigate: false));
  }

  /// Resets to initial state.
  void reset() {
    emit(const NotificationPermissionsState());
  }
}
