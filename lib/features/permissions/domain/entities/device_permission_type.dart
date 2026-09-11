/// System permission types required for Crit Alarm to operate reliably.
enum DevicePermissionType {
  /// Android notification permission (POST_NOTIFICATIONS).
  notifications,

  /// Full-screen intent permission (USE_FULL_SCREEN_INTENT) for waking the
  /// screen.
  fullScreenIntent,

  /// Exemption from Android Doze / battery optimization.
  batteryOptimization,
}
