import 'package:critalarm/core/api/network_failure_message.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/features/permissions/domain/usecases/get_device_permissions_usecase.dart';
import 'package:critalarm/features/permissions/domain/usecases/open_permission_settings_usecase.dart';
import 'package:critalarm/features/permissions/presentation/cubits/device_permissions_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Cubit managing loading, fixing, and refreshing device permissions.
class DevicePermissionsCubit extends Cubit<DevicePermissionsState> {
  DevicePermissionsCubit(
    this._getPermissions,
    this._openPermissionSettings,
  ) : super(const DevicePermissionsState());

  final GetDevicePermissionsUsecase _getPermissions;
  final OpenPermissionSettingsUsecase _openPermissionSettings;

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

  /// Refreshes all permissions.
  Future<void> refresh() => loadPermissions();
}
