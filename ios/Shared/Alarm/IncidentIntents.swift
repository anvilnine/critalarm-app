import AppIntents
import Foundation

/// The two buttons that move an incident along without opening the app.
///
/// Both are `LiveActivityIntent`, which the system runs inside the app's own
/// process. That is what lets them write to the same `flutter.ack_queue_v1`
/// list the Dart `AckQueue` drains, so a Stop tapped with no engine running is
/// still sent on the next launch.
///
/// api.md §3.2 is the state machine they drive:
///   open --ack--> acked --close--> closed
/// Stop on the ringing alarm is stage 1. Acknowledge on the card is stage 2.

@available(iOS 16.2, *)
struct StopAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop"
    static var description = IntentDescription("Stops the alarm and tells the server you are up.")

    /// Never true. The alarm has to stop from the lock screen.
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Incident")
    var incidentId: String

    init() {}

    init(incidentId: String) {
        self.incidentId = incidentId
    }

    func perform() async throws -> some IntentResult {
        AckQueueStore.enqueue(action: "ack", incidentId: incidentId)
        NSLog("CritAlarmAlarm: alarm_stopped incident_id=%@", incidentId)
        await IncidentActivityCoordinator.shared.alarmStopped(incidentId: incidentId)
        return .result()
    }
}

@available(iOS 16.2, *)
struct AcknowledgeIncidentIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Acknowledge"
    static var description = IntentDescription("Closes the incident. Opens nothing.")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Incident")
    var incidentId: String

    init() {}

    init(incidentId: String) {
        self.incidentId = incidentId
    }

    func perform() async throws -> some IntentResult {
        AckQueueStore.enqueue(action: "close", incidentId: incidentId)
        NSLog("CritAlarmActivity: incident_acknowledged incident_id=%@", incidentId)
        await IncidentActivityCoordinator.shared.acknowledged(incidentId: incidentId)
        return .result()
    }
}
