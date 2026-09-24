import Foundation

/// The words and times on the acknowledge card, kept out of SwiftUI so the
/// tests can check them.
///
/// The card is a display surface only. Nothing here rings, posts a
/// notification or touches AlarmKit.
enum LiveCardText {
    /// How long an acknowledged card stays as it is before it asks whether
    /// the incident is fixed.
    static let staleAfter: TimeInterval = 4 * 3600

    static let staleLine = "Still open. Tap Done if it's fixed."

    /// The button a card carries, if any.
    enum Button: Equatable {
        case imUp
        case done
    }

    /// When a card acknowledged at [ackedAt] turns into the "still open" view.
    static func staleDate(ackedAt: Date) -> Date {
        ackedAt.addingTimeInterval(staleAfter)
    }

    static func pillLabel(state: IncidentActivityState, isStale: Bool) -> String {
        switch state {
        case .open: return isStale ? "Still open" : "Ringing"
        case .acked: return isStale ? "Still open" : "Awake"
        case .closed: return "Closed"
        case .expired: return "Missed"
        }
    }

    /// "Acknowledged at 03:12", in the phone's own time zone.
    static func ackedLine(_ ackedAt: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        return "Acknowledged at \(formatter.string(from: ackedAt))"
    }

    /// Where the running clock starts. An acknowledged card counts from the
    /// acknowledge when this phone knows it, and from the open otherwise.
    static func timerStart(state: IncidentActivityState, openedAt: Date, ackedAt: Date?) -> Date {
        state == .acked ? (ackedAt ?? openedAt) : openedAt
    }

    /// Done once acknowledged. I'm up only on a card the user silenced,
    /// because that is the one way out of the ring loop. A ringing card has
    /// no button: AlarmKit's own card carries them while it rings.
    static func button(state: IncidentActivityState, silenced: Bool) -> Button? {
        switch state {
        case .acked: return .done
        case .open: return silenced ? .imUp : nil
        case .closed, .expired: return nil
        }
    }
}
