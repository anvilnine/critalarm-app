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
    NotificationPermissionStep initialStep = NotificationPermissionStep.initial,
  }) : super(NotificationPermissionsState(step: initialStep));

  final RequestNotificationPermissionUsecase _requestPermission;
  final OpenNotificationSettingsUsecase _openSettings;

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
    result.fold(
      (status) {
        if (status == NotificationPermissionStatus.granted) {
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
