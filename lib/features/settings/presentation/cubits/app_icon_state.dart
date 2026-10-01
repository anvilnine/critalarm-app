import 'package:critalarm/core/app_icon/app_icon.dart';
import 'package:critalarm/core/app_icon/app_icon_rule.dart';

enum AppIconStatus {
  /// Asking the platform which icon is showing.
  loading,

  /// Showing the four icons.
  ready,

  /// This platform cannot change its icon. The row and the screen stay away.
  unavailable,
}

/// What the App icon picker is showing.
class AppIconState {
  const AppIconState({
    this.status = AppIconStatus.loading,
    this.current = AppIcon.standard,
    this.unlocked = false,
    this.saving,
    this.failed = false,
  });

  final AppIconStatus status;

  /// The icon on the home screen now.
  final AppIcon current;

  /// True when the Pro icons are open to this device. See [AppIconRule].
  final bool unlocked;

  /// The icon the platform is switching to, while it does.
  final AppIcon? saving;

  /// True when the last switch was refused. Cleared by the next one.
  final bool failed;

  bool isLocked(AppIcon icon) => AppIconRule.isLocked(icon, unlocked: unlocked);

  AppIconState copyWith({
    AppIconStatus? status,
    AppIcon? current,
    bool? unlocked,
    AppIcon? Function()? saving,
    bool? failed,
  }) => AppIconState(
    status: status ?? this.status,
    current: current ?? this.current,
    unlocked: unlocked ?? this.unlocked,
    saving: saving != null ? saving() : this.saving,
    failed: failed ?? this.failed,
  );
}
