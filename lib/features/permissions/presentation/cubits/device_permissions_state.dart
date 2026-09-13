import 'package:critalarm/features/permissions/domain/entities/device_permission_item.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_status.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';

enum DevicePermissionsCubitStatus { initial, loading, success, failure }

/// State for the device permissions screen.
@immutable
class DevicePermissionsState {
  const DevicePermissionsState({
    this.status = DevicePermissionsCubitStatus.initial,
    List<DevicePermissionItem>? permissions,
    this.errorMessage,
    // Backing field is private while constructor parameter is public.
    // ignore: prefer_initializing_formals
  }) : _permissions = permissions;

  final DevicePermissionsCubitStatus status;
  final List<DevicePermissionItem>? _permissions;
  final String? errorMessage;

  static List<DevicePermissionItem> get defaultPermissions => [
    DevicePermissionItem(
      type: DevicePermissionType.notifications,
      title: LocaleKeys.device_permissions_item_notifications_title.tr(),
      description: LocaleKeys.device_permissions_item_notifications_description
          .tr(),
      status: DevicePermissionStatus.notDetermined,
      canFix: true,
    ),
    DevicePermissionItem(
      type: DevicePermissionType.fullScreenIntent,
      title: LocaleKeys.device_permissions_item_full_screen_intent_title.tr(),
      description: LocaleKeys
          .device_permissions_item_full_screen_intent_description
          .tr(),
      status: DevicePermissionStatus.notDetermined,
      canFix: true,
    ),
    DevicePermissionItem(
      type: DevicePermissionType.batteryOptimization,
      title: LocaleKeys.device_permissions_item_battery_optimization_title.tr(),
      description: LocaleKeys
          .device_permissions_item_battery_optimization_description
          .tr(),
      status: DevicePermissionStatus.notDetermined,
      canFix: true,
    ),
  ];

  List<DevicePermissionItem> get permissions =>
      _permissions ?? defaultPermissions;

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
