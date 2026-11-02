import AppKit
import FlutterMacOS
import UserNotifications

/// The Mac half of `app.critalarm/settings`: what the notification settings
/// say, and the System Settings panes to fix them in. The same calls as the
/// iPhone's `handleSettingsCall` in `ios/Runner/AppDelegate.swift`.
enum SettingsChannel {
  private static var channel: FlutterMethodChannel?

  /// Notifications > Crit Alarm in System Settings (macOS 13 and later).
  static let notificationSettingsURL =
    "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=app.critalarm"

  /// Privacy & Security, where the microphone and file access switches are.
  /// A Mac has no per-app settings page, so this is the closest to it.
  static let privacySettingsURL =
    "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Microphone"

  static func attach(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "app.critalarm/settings", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "checkNotificationPermission":
        readSettings(result) { settings in
          settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
        }
      case "checkTimeSensitive":
        readSettings(result) { settings in
          switch settings.timeSensitiveSetting {
          case .enabled: return true
          case .disabled: return false
          default: return true
          }
        }
      case "checkScheduledSummary":
        readSettings(result) { $0.scheduledDeliverySetting == .enabled }
      case "checkFullScreenIntent", "checkBatteryOptimization":
        // Android switches. Nothing to check on a Mac, so nothing is wrong.
        result(true)
      case "openNotificationSettings":
        open(notificationSettingsURL, result)
      case "openFullScreenIntentSettings", "openBatteryOptimizationSettings",
           "openAppSettings":
        open(privacySettingsURL, result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
  }

  private static func readSettings(
    _ result: @escaping FlutterResult,
    _ read: @escaping (UNNotificationSettings) -> Bool
  ) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      let value = read(settings)
      DispatchQueue.main.async { result(value) }
    }
  }

  private static func open(_ link: String, _ result: @escaping FlutterResult) {
    guard let url = URL(string: link) else {
      result(false)
      return
    }
    DispatchQueue.main.async { result(NSWorkspace.shared.open(url)) }
  }
}
