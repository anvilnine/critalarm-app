import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_item.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_status.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';

/// Repository interface to inspect and manage device permissions.
abstract interface class DevicePermissionsRepository {
  /// Checks and returns status of all required device permissions.
  Future<AppResult<List<DevicePermissionItem>>> getPermissions();

  /// Checks the status of a specific [DevicePermissionType].
  Future<AppResult<DevicePermissionStatus>> checkPermission(
    DevicePermissionType type,
  );

  /// Opens the system settings screen for a specific [DevicePermissionType].
  Future<AppResult<bool>> openPermissionSettings(DevicePermissionType type);
}
