import 'package:flutter/foundation.dart';

/// System permission types required for Crit Alarm to operate reliably.
enum DevicePermissionType {
  /// Notification permission. POST_NOTIFICATIONS on Android, the
  /// `UNUserNotificationCenter` authorization on iOS.
  notifications,

  /// Full-screen intent permission (USE_FULL_SCREEN_INTENT) for waking the
  /// screen. Android only.
  fullScreenIntent,

  /// Exemption from Android Doze / battery optimization. Android only.
  batteryOptimization,

  /// iOS only. With this off, iOS holds a page for the next Scheduled
  /// Summary instead of delivering it, which is the end of an alarm app.
  timeSensitive,

  /// iOS only. AlarmKit, the permission that lets a page ring through the
  /// silent switch and Do Not Disturb.
  alarms,
}

/// The permissions [platform] can actually be wrong about, in display order.
///
/// Asking Android whether Time Sensitive is on, or iOS about battery
/// optimisation, only produces a row the user can never fix. The web
/// dashboard has no alarm and no battery, so it lists notifications alone.
List<DevicePermissionType> devicePermissionTypesFor(
  TargetPlatform platform, {
  required bool isWeb,
}) {
  if (isWeb) return const [DevicePermissionType.notifications];
  return switch (platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => const [
      DevicePermissionType.notifications,
      DevicePermissionType.timeSensitive,
      DevicePermissionType.alarms,
    ],
    TargetPlatform.android => const [
      DevicePermissionType.notifications,
      DevicePermissionType.fullScreenIntent,
      DevicePermissionType.batteryOptimization,
    ],
    _ => const [DevicePermissionType.notifications],
  };
}
