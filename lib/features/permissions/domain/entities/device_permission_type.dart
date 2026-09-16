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
