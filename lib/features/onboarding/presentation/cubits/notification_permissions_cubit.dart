import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/entities/notification_permission_status.dart';
import 'package:critalarm/features/onboarding/domain/usecases/check_notification_permission_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/open_notification_settings_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/request_notification_permission_usecase.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/notification_permissions_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Cubit managing the Screen 1 Permissions step (Option B: 2-step stepper).
class NotificationPermissionsCubit extends Cubit<NotificationPermissionsState> {
  NotificationPermissionsCubit(
    this._requestPermission,
    this._openSettings, {
    this.alarm,
    this.checkPermission,
    this.replayForDemo = false,
    NotificationPermissionStep initialStep = NotificationPermissionStep.initial,
  }) : super(NotificationPermissionsState(step: initialStep));

  final RequestNotificationPermissionUsecase _requestPermission;
  final OpenNotificationSettingsUsecase _openSettings;

  /// Null off iOS, and in tests that only care about the notification step.
  final AlarmHost? alarm;

  /// Null in tests that do not exercise the skip-what-is-granted path.
  final CheckNotificationPermissionUsecase? checkPermission;

  /// True when the developer menu opened onboarding to look at it. Then every
  /// step is shown even where the permission is already granted, because the
  /// point is seeing the screens, not getting through them.
  final bool replayForDemo;

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
    if (check == null && alarmHost == null) return;

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
    final alarmGranted = authorization == AlarmAuthorization.authorized;

    if (isClosed) return;

    if (replayForDemo) {
      emit(
        state.copyWith(
          isChecking: false,
          alarm: authorization,
          alarmSupported: alarmSupported,
          notificationsGranted: notificationsGranted,
        ),
      );
      return;
    }

    final everythingGranted =
        notificationsGranted && (!alarmSupported || alarmGranted);

    emit(
      state.copyWith(
        isChecking: false,
        alarm: authorization,
        alarmSupported: alarmSupported,
        notificationsGranted: notificationsGranted,
        criticalAlertsGranted: alarmGranted || !alarmSupported,
        // A granted step is not worth a screen. Land on the first one that
        // still needs an answer.
        activeSubstep: notificationsGranted && alarmSupported ? 1 : 0,
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
          emit(
            state.copyWith(
              step: NotificationPermissionStep.denied,
              canNavigate: false,
              clearError: true,
            ),
          );
        }
      },
      (failure) {
        emit(
          state.copyWith(
            step: NotificationPermissionStep.denied,
            errorMessage: failure.message,
            canNavigate: false,
          ),
        );
      },
    );
  }

  void _afterNotificationsGranted() {
    final alarmHost = alarm;
    if (alarmHost == null) {
      emit(
        state.copyWith(
          notificationsGranted: true,
          criticalAlertsGranted: true,
          alarmSupported: false,
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
      title: 'Crit Alarm is ready',
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
