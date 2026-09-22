import Foundation

#if canImport(AlarmKit)
import AlarmKit
#endif

#if canImport(ActivityKit)
import ActivityKit
#endif

/// What an incident looks like on a lock-screen surface.
///
/// Both surfaces carry the same three identity fields, because both have to be
/// matched back to one incident: AlarmKit's own alarm activity (through
/// `IncidentAlarmMetadata`) and our acknowledge card (through
/// `CritAlarmIncidentAttributes`). api.md §5.1 is where `incident_id` and
/// `server` come from; `topic` comes from the fetched incident (§3.2).
public enum IncidentActivityState: String, Codable, Hashable, Sendable {
    case open
    case acked
    case closed
    case expired
}

#if canImport(AlarmKit)
/// Rides along on the AlarmKit alarm so the Stop button knows which incident
/// it is stopping.
@available(iOS 26.0, *)
public struct IncidentAlarmMetadata: AlarmMetadata {
    public let incidentId: String
    public let topic: String
    public let server: String

    public init(incidentId: String, topic: String, server: String) {
        self.incidentId = incidentId
        self.topic = topic
        self.server = server
    }
}
#endif

#if canImport(ActivityKit)
/// The acknowledge card. Started by the relay with `apns-push-type:
/// liveactivity`, or locally during onboarding so the Allow prompt happens
/// before any remote start.
@available(iOS 16.1, *)
public struct CritAlarmIncidentAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var state: IncidentActivityState
        public var title: String
        public var openedAt: Date

        /// Set only by this device, never by the server.
        ///
        /// The user pressed Stop, so the alarm is quiet and the phone has set
        /// its own next ring this many seconds out. api.md §5.3 fixes the
        /// server's content-state at the three fields above, and this one is
        /// optional, so a push that carries only those three still decodes and
        /// clears it.
        public var ringsAgainInSeconds: Int?

        public init(
            state: IncidentActivityState,
            title: String,
            openedAt: Date,
            ringsAgainInSeconds: Int? = nil
        ) {
            self.state = state
            self.title = title
            self.openedAt = openedAt
            self.ringsAgainInSeconds = ringsAgainInSeconds
        }

        // The relay writes snake_case, matching every other payload in api.md.
        enum CodingKeys: String, CodingKey {
            case state
            case title
            case openedAt = "opened_at"
            case ringsAgainInSeconds = "rings_again_in_seconds"
        }
    }

    public let incidentId: String
    public let topic: String
    public let server: String

    public init(incidentId: String, topic: String, server: String) {
        self.incidentId = incidentId
        self.topic = topic
        self.server = server
    }

    enum CodingKeys: String, CodingKey {
        case incidentId = "incident_id"
        case topic
        case server
    }
}
#endif
