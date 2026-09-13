import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/entities/notification_permission_status.dart';
import 'package:critalarm/features/onboarding/domain/usecases/open_notification_settings_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/request_notification_permission_usecase.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/notification_permissions_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Cubit managing the Screen 1 Notification Permissions step.
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

  /// Requests notification (POST_NOTIFICATIONS) and full screen intent
  /// (USE_FULL_SCREEN_INTENT) permissions.
  Future<void> requestPermissions() async {
    emit(
      state.copyWith(
        step: NotificationPermissionStep.requesting,
        clearError: true,
        canNavigate: false,
      ),
    );

    final result = await _requestPermission(const NoParams());
    var granted = false;
    result.fold(
      (status) {
        if (status == NotificationPermissionStatus.granted) {
          granted = true;
          emit(
            state.copyWith(
              step: NotificationPermissionStep.granted,
              canNavigate: true,
              clearError: true,
            ),
          );
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

    if (granted) await requestAlarmAndActivity();
  }

  /// The two iOS prompts that follow the notification one.
  ///
  /// AlarmKit is what lets a critical topic ring through silent mode and a
  /// Focus. The local Live Activity is only there to make the system ask
  /// Allow, because no update token is issued until the user has.
  Future<void> requestAlarmAndActivity() async {
    final alarm = this.alarm;
    if (alarm == null) return;

    final authorization = await alarm.requestAuthorization();
    emit(state.copyWith(alarm: authorization));

    final started = await alarm.startLocalActivity(
      incidentId: onboardingIncidentId,
      topic: 'setup',
      server: '',
      title: 'Crit Alarm is ready',
      state: 'acked',
    );
    emit(state.copyWith(liveActivityStarted: started));
  }

  /// Reads the alarm state back without prompting, for the status row.
  Future<void> refreshAlarmAuthorization() async {
    final alarm = this.alarm;
    if (alarm == null) return;
    emit(state.copyWith(alarm: await alarm.authorizationStatus()));
  }

  /// Opens the system app notification settings.
  Future<void> openSettings() async {
    await _openSettings(const NoParams());
  }

  /// Allows the user to proceed to Screen 2 even if permissions are denied.
  void continueAnyway() {
    emit(state.copyWith(canNavigate: true));
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
