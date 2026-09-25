import 'package:critalarm/core/api/network_failure_message.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/entities/notification_permission_status.dart';
import 'package:critalarm/features/onboarding/domain/usecases/check_notification_permission_usecase.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/features/permissions/domain/usecases/get_device_permissions_usecase.dart';
import 'package:critalarm/features/permissions/domain/usecases/open_permission_settings_usecase.dart';
import 'package:critalarm/features/permissions/presentation/cubits/device_permissions_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Cubit managing loading, fixing, and refreshing device permissions.
class DevicePermissionsCubit extends Cubit<DevicePermissionsState> {
  DevicePermissionsCubit(
    this._getPermissions,
    this._openPermissionSettings, {
    this.checkNotifications,
  }) : super(const DevicePermissionsState());

  final GetDevicePermissionsUsecase _getPermissions;
  final OpenPermissionSettingsUsecase _openPermissionSettings;

  /// Null in tests that never tap "Turn on" for notifications.
  final CheckNotificationPermissionUsecase? checkNotifications;

  /// Loads the latest status for all device permissions.
  Future<void> loadPermissions() async {
    emit(state.copyWith(status: DevicePermissionsCubitStatus.loading));
    final result = await _getPermissions(const NoParams());
    result.fold(
      (permissions) {
        emit(
          state.copyWith(
            status: DevicePermissionsCubitStatus.success,
            permissions: permissions,
            clearError: true,
          ),
        );
      },
      (failure) {
        emit(
          state.copyWith(
            status: DevicePermissionsCubitStatus.failure,
            errorMessage: failureMessage(failure),
          ),
        );
      },
    );
  }

  /// Deep-links to system settings for the specified permission type.
  Future<void> openSettings(DevicePermissionType type) async {
    await _openPermissionSettings(type);
  }

  /// True when the app can still show the system prompt for [type], because
  /// the user has never been asked. Then the in-app prompt screen does the
  /// asking. Once asked, only the system settings screen can change it.
  Future<bool> neverAsked(DevicePermissionType type) async {
    switch (type) {
      case DevicePermissionType.alarms:
        return state.permissionByType(type)?.status.isNotDetermined ?? false;
      case DevicePermissionType.notifications:
        final result = await checkNotifications?.call(const NoParams());
        return result?.getOrNull() ==
            NotificationPermissionStatus.notDetermined;
      case DevicePermissionType.fullScreenIntent:
      case DevicePermissionType.batteryOptimization:
      case DevicePermissionType.timeSensitive:
        return false;
    }
  }

  /// Refreshes all permissions.
  Future<void> refresh() => loadPermissions();
}
