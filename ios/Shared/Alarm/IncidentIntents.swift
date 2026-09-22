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
/// Stop on the ringing alarm is stage 1, "I'm up". Done on the card is
/// stage 2, "At my desk": the alarm is already quiet by then, and this is
/// what stops the desk timer reopening the incident.

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
        // Marked before anything goes on the wire, so the next repeat push
        // does not ring even if the ack takes minutes to land.
        AckedIncidentStore.mark(incidentId: incidentId)
        NSLog("CritAlarmAlarm: alarm_stopped incident_id=%@", incidentId)
        await IncidentActivityCoordinator.shared.alarmStopped(incidentId: incidentId)
        // One native try. On success the queue entry is gone; otherwise Dart
        // sends it with its own backoff.
        await NativeAckSender.send(action: "ack", incidentId: incidentId)
        return .result()
    }
}

@available(iOS 16.2, *)
struct CloseIncidentIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Done"
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
        NSLog("CritAlarmActivity: incident_closed incident_id=%@", incidentId)
        await IncidentActivityCoordinator.shared.closed(incidentId: incidentId)
        await NativeAckSender.send(action: "close", incidentId: incidentId)
        return .result()
    }
}
