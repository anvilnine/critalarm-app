import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/entities/notification_permission_status.dart';
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
    NotificationPermissionStep initialStep = NotificationPermissionStep.initial,
  }) : super(NotificationPermissionsState(step: initialStep));

  final RequestNotificationPermissionUsecase _requestPermission;
  final OpenNotificationSettingsUsecase _openSettings;

  /// Null off iOS, and in tests that only care about the notification step.
  final AlarmHost? alarm;

  /// The incident id the onboarding card uses. Not a real incident: it exists
  /// so the Allow prompt for Live Activities happens here rather than the
  /// first time the relay tries a remote start.
  static const onboardingIncidentId = 'inc_onboarding';

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
    result.fold(
      (status) {
        if (status == NotificationPermissionStatus.granted) {
          if (alarm == null) {
            // Platform does not require a second prompt (or test mode).
            emit(
              state.copyWith(
                notificationsGranted: true,
                criticalAlertsGranted: true,
                step: NotificationPermissionStep.granted,
                canNavigate: true,
                clearError: true,
              ),
            );
          } else {
            // Move to Step 2: Critical Alerts / Silent mode bypass
            emit(
              state.copyWith(
                notificationsGranted: true,
                activeSubstep: 1,
                step: NotificationPermissionStep.initial,
                clearError: true,
              ),
            );
          }
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

  /// Step 2: Requests critical alert authorization (AlarmKit / Live Activities on iOS).
  Future<void> requestCriticalAlerts() async {
    final alarmHost = alarm;
    if (alarmHost == null) {
      emit(
        state.copyWith(
          criticalAlertsGranted: true,
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

    if (authorization == AlarmAuthorization.authorized ||
        authorization == AlarmAuthorization.unsupported) {
      emit(
        state.copyWith(
          alarm: authorization,
          liveActivityStarted: started,
          criticalAlertsGranted: true,
          step: NotificationPermissionStep.granted,
          canNavigate: true,
          clearError: true,
        ),
      );
    } else {
      emit(
        state.copyWith(
          alarm: authorization,
          liveActivityStarted: started,
          step: NotificationPermissionStep.denied,
          canNavigate: false,
          clearError: true,
        ),
      );
    }
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
