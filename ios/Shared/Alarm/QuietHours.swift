import Foundation

/// The quiet hours window, and the one decision it drives: does this page ring.
///
/// `lib/core/alarm/quiet_hours.dart` is the other half. Two different pieces of
/// code decide to ring, the app on the background-push path and the
/// notification extension on the other one, so each has to reach the same
/// answer on its own. Change the rules in both together.
///
/// Dart owns the values. It writes them to its own preferences and hands the
/// same four across the `app.critalarm/alarm` channel, and `AppDelegate` puts
/// them in the App Group with `write(_:to:)`. The extension runs in its own
/// process with its own container, so the group is the only place it can read
/// them from.
///
/// Two places read it back. `AppDelegate.didReceiveRemoteNotification` is the
/// one that holds a ring on a phone today, because that handler is what
/// schedules the alarm on the chosen path. `NotificationService` reads it for
/// the path `AlarmTriggerPath` is not currently set to.
struct QuietHours {
    static let appGroup = "group.app.critalarm"

    static let enabledKey = "quiet_hours_enabled"
    static let startKey = "quiet_hours_start_minutes"
    static let endKey = "quiet_hours_end_minutes"
    static let criticalRingsKey = "quiet_hours_critical_rings"

    /// A page at this priority or above is critical.
    ///
    /// api.md 1.7: a priority-5 message on a critical topic is what opens,
    /// joins or reopens an incident, so 5 is the pager case. There is no
    /// separate critical flag on the push, and Dart reads the same number off
    /// `IncidentPush.priority`.
    static let criticalPriority = 5

    static let minutesPerDay = 24 * 60

    let isEnabled: Bool

    /// Minutes from local midnight. 22:00 is 1320.
    let startMinutes: Int

    /// Minutes from local midnight. 07:00 is 420.
    let endMinutes: Int

    /// The switch that makes quiet hours mean something for a pager. On, a
    /// critical page rings whatever the clock says.
    let criticalRingsThrough: Bool

    /// What a device with nothing saved yet runs. The same four values are the
    /// fallback in `QuietHours.defaults` in Dart, so the app and the extension
    /// agree before the first save has happened.
    static let defaults = QuietHours(
        isEnabled: true,
        startMinutes: 22 * 60,
        endMinutes: 7 * 60,
        criticalRingsThrough: true
    )

    static var groupDefaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    static func read(from defaults: UserDefaults?) -> QuietHours {
        guard let defaults, defaults.object(forKey: enabledKey) != nil else {
            return .defaults
        }
        return QuietHours(
            isEnabled: defaults.bool(forKey: enabledKey),
            startMinutes: defaults.integer(forKey: startKey),
            endMinutes: defaults.integer(forKey: endKey),
            criticalRingsThrough: defaults.bool(forKey: criticalRingsKey)
        )
    }

    static func write(_ window: QuietHours, to defaults: UserDefaults?) {
        guard let defaults else { return }
        defaults.set(window.isEnabled, forKey: enabledKey)
        defaults.set(window.startMinutes, forKey: startKey)
        defaults.set(window.endMinutes, forKey: endKey)
        defaults.set(window.criticalRingsThrough, forKey: criticalRingsKey)
    }

    /// Minutes from local midnight for `date`.
    static func minuteOf(_ date: Date, calendar: Calendar = .current) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    /// True when `minute` falls inside the window.
    ///
    /// A window that wraps past midnight is the normal case: 22:00 to 07:00 is
    /// start 1320 and end 420, and both 23:30 and 02:00 are inside it. The
    /// start minute is inside, the end minute is outside.
    ///
    /// Start equal to end is an empty window, not a whole day. A day of
    /// silence is what the quiet hours switch being off already does, and a
    /// slip of the picker should not be able to mute the pager around the
    /// clock.
    func contains(minuteOfDay minute: Int) -> Bool {
        if startMinutes == endMinutes { return false }
        if startMinutes < endMinutes {
            return minute >= startMinutes && minute < endMinutes
        }
        return minute >= startMinutes || minute < endMinutes
    }

    /// True when the ring for a page of `priority` is held at `minute`.
    ///
    /// Only the ring. The notification still goes out with the text it was
    /// going to have; the caller skips the schedule call and nothing else.
    func holdsRing(minuteOfDay minute: Int, priority: Int) -> Bool {
        guard isEnabled else { return false }
        if priority >= QuietHours.criticalPriority, criticalRingsThrough {
            return false
        }
        return contains(minuteOfDay: minute)
    }
}
