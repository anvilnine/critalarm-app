import 'package:critalarm/features/permissions/domain/entities/device_permission_item.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_status.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:flutter/foundation.dart';

enum DevicePermissionsCubitStatus { initial, loading, success, failure }

/// State for the device permissions screen.
@immutable
class DevicePermissionsState {
  const DevicePermissionsState({
    this.status = DevicePermissionsCubitStatus.initial,
    this.permissions = defaultPermissions,
    this.errorMessage,
  });

  final DevicePermissionsCubitStatus status;
  final List<DevicePermissionItem> permissions;
  final String? errorMessage;

  static const defaultPermissions = [
    DevicePermissionItem(
      type: DevicePermissionType.notifications,
      title: 'Notifications',
      description: 'Allows Crit Alarm to deliver alert banners and play sound.',
      status: DevicePermissionStatus.notDetermined,
      canFix: true,
    ),
    DevicePermissionItem(
      type: DevicePermissionType.fullScreenIntent,
      title: 'Full-screen intent',
      description:
          'Allows critical alerts to turn on and display over the lock screen '
          'even when phone is sleeping.',
      status: DevicePermissionStatus.notDetermined,
      canFix: true,
    ),
    DevicePermissionItem(
      type: DevicePermissionType.batteryOptimization,
      title: 'Battery optimization exemption',
      description:
          'Prevents Android from killing background alarm sync and delayed '
          'delivery.',
      status: DevicePermissionStatus.notDetermined,
      canFix: true,
    ),
  ];

  bool get isLoading => status == DevicePermissionsCubitStatus.loading;
  bool get isSuccess => status == DevicePermissionsCubitStatus.success;
  bool get isFailure => status == DevicePermissionsCubitStatus.failure;

  bool get allGranted =>
      permissions.isNotEmpty &&
      permissions
          .where((p) => p.affectsReadiness)
          .every((p) => p.status == DevicePermissionStatus.granted);

  bool get hasIssues =>
      permissions.any((p) => p.status != DevicePermissionStatus.granted);

  bool get hasDenied =>
      permissions.any((p) => p.status == DevicePermissionStatus.denied);

  List<DevicePermissionItem> get items => permissions;

  DevicePermissionItem? permissionByType(DevicePermissionType type) {
    for (final p in permissions) {
      if (p.type == type) return p;
    }
    return null;
  }

  DevicePermissionsState copyWith({
    DevicePermissionsCubitStatus? status,
    List<DevicePermissionItem>? permissions,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DevicePermissionsState(
      status: status ?? this.status,
      permissions: permissions ?? this.permissions,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DevicePermissionsState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          listEquals(permissions, other.permissions) &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(
    status,
    Object.hashAll(permissions),
    errorMessage,
  );
}
