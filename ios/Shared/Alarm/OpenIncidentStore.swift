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
/// An alarm push always gets through. A second topic's first push carries an
/// incident id this phone has never seen, because Dart writes the open list
/// only after it has the incident, so the open list must never decide whether
/// an alarm rings. The one alarm push that is dropped is a repeat for an
/// incident already answered here.
///
/// Everything else (a reminder, a notification with no incident behind it) is
/// a quiet banner normally, and nothing at all while an alarm is under way.
enum ForegroundPresentation {
    static let alarm: UNNotificationPresentationOptions = [.banner, .list, .sound]
    static let quiet: UNNotificationPresentationOptions = [.banner, .list]

    static func options(
        isReminder: Bool,
        incidentId: String?,
        focusOn: Bool,
        ackedIds: Set<String>
    ) -> UNNotificationPresentationOptions {
        guard !isReminder, let incidentId else { return focusOn ? [] : quiet }
        return ackedIds.contains(incidentId) ? [] : alarm
    }
}
