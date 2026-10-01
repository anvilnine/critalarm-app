import 'package:critalarm/core/app_icon/app_icon.dart';

/// Who may use which app icon.
///
/// "Unlocked" means the Pro icons are open to this device: it is on Pro, or
/// it talks to a self-hosted server, which has no plans and so never locks
/// anything. The same rule decides whether widgets are locked.
abstract final class AppIconRule {
  /// True when [icon] cannot be picked right now. A tap on it opens the
  /// paywall instead.
  static bool isLocked(AppIcon icon, {required bool unlocked}) =>
      icon.isPro && !unlocked;

  /// The icon to switch to because [current] is no longer allowed, or null
  /// when [current] can stay.
  ///
  /// A Pro icon stays only while Pro does. When Pro ends the app goes back to
  /// the default icon, so a crown or shades on a home screen always means an
  /// active plan.
  static AppIcon? revertTo(AppIcon current, {required bool unlocked}) =>
      isLocked(current, unlocked: unlocked) ? AppIcon.standard : null;
}
