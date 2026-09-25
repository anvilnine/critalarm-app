import 'package:critalarm/features/permissions/domain/entities/device_permission_item.dart';
import 'package:flutter/foundation.dart';

enum HomePromptType {
  none,
  noServer,
  criticalHealth,
  proEnding,
  accountBackup,
}

@immutable
class HomePromptState {
  const HomePromptState({
    this.promptType = HomePromptType.none,
    this.isDismissing = false,
    this.missingPermissions = const [],
    this.proEndsAt,
  });

  final HomePromptType promptType;
  final bool isDismissing;
  final List<DevicePermissionItem> missingPermissions;

  /// When Pro ends, while [promptType] is [HomePromptType.proEnding].
  final DateTime? proEndsAt;

  bool get isVisible => promptType != HomePromptType.none;

  HomePromptState copyWith({
    HomePromptType? promptType,
    bool? isDismissing,
    List<DevicePermissionItem>? missingPermissions,
    DateTime? proEndsAt,
  }) {
    return HomePromptState(
      promptType: promptType ?? this.promptType,
      isDismissing: isDismissing ?? this.isDismissing,
      missingPermissions: missingPermissions ?? this.missingPermissions,
      proEndsAt: proEndsAt ?? this.proEndsAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomePromptState &&
          promptType == other.promptType &&
          isDismissing == other.isDismissing &&
          proEndsAt == other.proEndsAt &&
          listEquals(missingPermissions, other.missingPermissions);

  @override
  int get hashCode => Object.hash(
    promptType,
    isDismissing,
    proEndsAt,
    Object.hashAll(missingPermissions),
  );
}
