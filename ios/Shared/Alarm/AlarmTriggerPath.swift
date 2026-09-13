import Foundation

/// Which of the two iOS trigger paths in the spec (Part A, iOS) actually
/// schedules the alarm.
///
/// The answer comes from `docs/specs/remote-alarm-ios-spike.md`. Change it
/// here and in `lib/core/alarm/alarm_trigger_path.dart` together; the Dart
/// test reads the spike file and fails if the two drift apart.
public enum AlarmTriggerPath: String {
    /// Path 1. The alert push carries `mutable-content: 1`, and
    /// `NotificationService` schedules the alarm from inside the extension.
    case notificationServiceExtension = "nse"

    /// Path 2. The push carries `content-available: 1`, the app is woken in the
    /// background, and `AppDelegate` schedules the alarm from the main process.
    case appBackgroundPush = "app-background-push"

    /// Set from the spike verdict. See the file named above.
    public static let chosen: AlarmTriggerPath = .appBackgroundPush
}
