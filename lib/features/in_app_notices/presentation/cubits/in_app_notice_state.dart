import 'package:critalarm/features/permissions/domain/entities/device_permission_item.dart';
import 'package:flutter/foundation.dart';

enum InAppNoticeType {
  none,
  noServer,
  criticalHealth,
  proEnding,
  accountBackup,
}

@immutable
class InAppNoticeState {
  const InAppNoticeState({
    this.noticeType = InAppNoticeType.none,
    this.isDismissing = false,
    this.missingPermissions = const [],
    this.proEndsAt,
  });

  final InAppNoticeType noticeType;
  final bool isDismissing;
  final List<DevicePermissionItem> missingPermissions;

  /// When Pro ends, while [noticeType] is [InAppNoticeType.proEnding].
  final DateTime? proEndsAt;

  bool get isVisible => noticeType != InAppNoticeType.none;

  InAppNoticeState copyWith({
    InAppNoticeType? noticeType,
    bool? isDismissing,
    List<DevicePermissionItem>? missingPermissions,
    DateTime? proEndsAt,
  }) {
    return InAppNoticeState(
      noticeType: noticeType ?? this.noticeType,
      isDismissing: isDismissing ?? this.isDismissing,
      missingPermissions: missingPermissions ?? this.missingPermissions,
      proEndsAt: proEndsAt ?? this.proEndsAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InAppNoticeState &&
          noticeType == other.noticeType &&
          isDismissing == other.isDismissing &&
          proEndsAt == other.proEndsAt &&
          listEquals(missingPermissions, other.missingPermissions);

  @override
  int get hashCode => Object.hash(
    noticeType,
    isDismissing,
    proEndsAt,
    Object.hashAll(missingPermissions),
  );
}
