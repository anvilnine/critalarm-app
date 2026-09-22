import Foundation
import UserNotifications

/// The incidents this phone has open right now.
///
/// Dart writes the list over the alarm channel every time `AlarmFocus`
/// changes (`lib/core/alarm/alarm_focus.dart`). It lives in the app group
/// next to `AckedIncidentStore` so the notification extension can read it
/// too, and because the delegate runs before Dart does on a cold launch.
///
/// Stored as a plain `[String]`, newest last, the way Dart sends it.
enum OpenIncidentStore {
    static let key = "open_incidents_v1"

    static var groupDefaults: UserDefaults? { UserDefaults(suiteName: AckedIncidentStore.appGroup) }

    static func write(
        incidentIds: [String],
        in defaults: UserDefaults? = groupDefaults
    ) {
        guard let defaults else { return }
        defaults.set(incidentIds, forKey: key)
    }

    static func all(in defaults: UserDefaults? = groupDefaults) -> [String] {
        guard let defaults else { return [] }
        return defaults.stringArray(forKey: key) ?? []
    }

    /// The open incidents this phone has not acknowledged. That is what
    /// "an alarm is under way" means: Stop and a swipe leave the incident
    /// open, only "I'm up" takes it off this list.
    static func focusedIds(
        in defaults: UserDefaults? = groupDefaults,
        acked: UserDefaults? = AckedIncidentStore.groupDefaults
    ) -> Set<String> {
        let ackedIds = AckedIncidentStore.all(in: acked)
        return Set(all(in: defaults)).subtracting(ackedIds)
    }
}

/// What the app shows for a notification that lands while it is open.
///
/// While an alarm is under way nothing else gets a banner or a sound: a
/// reminder, a message from another topic and a push for an incident that
/// is already answered all come back empty. Only the alarm the user has to
/// deal with is allowed through.
enum ForegroundPresentation {
    static let alarm: UNNotificationPresentationOptions = [.banner, .list, .sound]
    static let quiet: UNNotificationPresentationOptions = [.banner, .list]

    static func options(
        isReminder: Bool,
        incidentId: String?,
        focusedIds: Set<String>
    ) -> UNNotificationPresentationOptions {
        if focusedIds.isEmpty {
            return isReminder ? quiet : alarm
        }
        guard let incidentId, focusedIds.contains(incidentId) else { return [] }
        return alarm
    }
}
