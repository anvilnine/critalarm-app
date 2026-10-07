import 'package:critalarm/features/in_app_notices/domain/missed_alarm_notice_rule.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_item.dart';
import 'package:flutter/foundation.dart';

enum InAppNoticeType {
  none,
  noServer,
  criticalHealth,
  batteryOptimization,
  proEnding,
  accountBackup,
  systemUpdate,
  missedAlarm,
  weeklyCheck,
}

@immutable
class InAppNoticeState {
  const InAppNoticeState({
    this.noticeType = InAppNoticeType.none,
    this.isDismissing = false,
    this.missingPermissions = const [],
    this.proEndsAt,
    this.missedAlarm,
  });

  final InAppNoticeType noticeType;
  final bool isDismissing;
  final List<DevicePermissionItem> missingPermissions;

  /// When Pro ends, while [noticeType] is [InAppNoticeType.proEnding].
  final DateTime? proEndsAt;

  /// What the missed alarm entry says, while [noticeType] is
  /// [InAppNoticeType.missedAlarm].
  final MissedAlarmNotice? missedAlarm;

  bool get isVisible => noticeType != InAppNoticeType.none;

  InAppNoticeState copyWith({
    InAppNoticeType? noticeType,
    bool? isDismissing,
    List<DevicePermissionItem>? missingPermissions,
    DateTime? proEndsAt,
    MissedAlarmNotice? missedAlarm,
  }) {
    return InAppNoticeState(
      noticeType: noticeType ?? this.noticeType,
      isDismissing: isDismissing ?? this.isDismissing,
      missingPermissions: missingPermissions ?? this.missingPermissions,
      proEndsAt: proEndsAt ?? this.proEndsAt,
      missedAlarm: missedAlarm ?? this.missedAlarm,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InAppNoticeState &&
          noticeType == other.noticeType &&
          isDismissing == other.isDismissing &&
          proEndsAt == other.proEndsAt &&
          missedAlarm == other.missedAlarm &&
          listEquals(missingPermissions, other.missingPermissions);

  @override
  int get hashCode => Object.hash(
    noticeType,
    isDismissing,
    proEndsAt,
    missedAlarm,
    Object.hashAll(missingPermissions),
  );
}
