import 'package:critalarm/features/permissions/domain/entities/device_permission_status.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:flutter/foundation.dart';

/// Entity describing an individual system permission required by Crit Alarm.
@immutable
class DevicePermissionItem {
  const DevicePermissionItem({
    required this.type,
    required this.title,
    required this.description,
    required this.status,
    required this.canFix,
    this.affectsReadiness = true,
  });

  final DevicePermissionType type;
  final String title;
  final String description;
  final DevicePermissionStatus status;
  final bool canFix;
  final bool affectsReadiness;

  DevicePermissionItem copyWith({
    DevicePermissionType? type,
    String? title,
    String? description,
    DevicePermissionStatus? status,
    bool? canFix,
    bool? affectsReadiness,
  }) {
    return DevicePermissionItem(
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      canFix: canFix ?? this.canFix,
      affectsReadiness: affectsReadiness ?? this.affectsReadiness,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DevicePermissionItem &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          title == other.title &&
          description == other.description &&
          status == other.status &&
          canFix == other.canFix &&
          affectsReadiness == other.affectsReadiness;

  @override
  int get hashCode =>
      Object.hash(type, title, description, status, canFix, affectsReadiness);
}
