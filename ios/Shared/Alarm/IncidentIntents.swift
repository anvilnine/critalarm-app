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
/// "I'm up" on the ringing alarm is stage 1. Done on the card is stage 2,
/// "At my desk": the alarm is already quiet by then, and this is what stops
/// the desk timer reopening the incident.
///
/// Stop is on neither line. It silences the alarm and sets the phone's own
/// next ring for the same incident, and the server never hears about it.

@available(iOS 16.2, *)
struct StopAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop"
    static var description = IntentDescription("Silences the alarm. It rings again shortly.")

    /// Never true. The alarm has to stop from the lock screen.
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Incident")
    var incidentId: String

    init() {}

    init(incidentId: String) {
        self.incidentId = incidentId
    }

    func perform() async throws -> some IntentResult {
        // Nothing is queued and nothing is marked. Stop is not an acknowledge:
        // the incident stays open, the server keeps repeating, and this sets
        // the phone's own next ring on top of that. A LiveActivityIntent runs
        // in the app's own process, so the re-armed alarm survives a
        // force-quit, which is the one exit the server repeat cannot reach.
        NSLog("CritAlarmAlarm: alarm_silenced incident_id=%@", incidentId)
        await IncidentActivityCoordinator.shared.alarmSilenced(incidentId: incidentId)
        let seconds = await IncidentRearm.rearm(incidentId: incidentId)
        if let seconds {
            await IncidentActivityCoordinator.shared.setRingsAgainIn(
                seconds, incidentId: incidentId
            )
        }
        return .result()
    }
}

/// "I'm up" on the alarm: opens Crit Alarm to the active incident
/// without stopping or acknowledging the alarm in the background.
@available(iOS 16.2, *)
struct OpenIncidentIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Open Incident"
    static var description = IntentDescription("Opens Crit Alarm to the active incident.")

    static var openAppWhenRun: Bool = true

    @Parameter(title: "Incident")
    var incidentId: String

    init() {}

    init(incidentId: String) {
        self.incidentId = incidentId
    }

    func perform() async throws -> some IntentResult {
        NSLog("CritAlarmAlarm: open_incident_intent incident_id=%@", incidentId)
        await IncidentActivityCoordinator.shared.openIncident(incidentId: incidentId)
        return .result()
    }
}

/// "I'm up". The acknowledge, and the only way out of the ring loop.
@available(iOS 16.2, *)
struct AckAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "I'm up"
    static var description = IntentDescription("Ends the alarm and tells the server you are up.")

    /// Never true. The alarm has to end from the lock screen.
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
        WidgetSnapshotStore.patch(.acked(incidentId, at: Date()))
        // A home screen widget button may run this in the widget extension
        // instead of the app. The log says which, for the device check.
        NSLog(
            "CritAlarmAlarm: alarm_acked incident_id=%@ process=%@",
            incidentId, Bundle.main.bundleIdentifier ?? "unknown"
        )
        // Any ring this phone set for itself goes with the acknowledge. This
        // also cancels the AlarmKit alarm that is alerting right now.
        await IncidentRearm.cancel(incidentId: incidentId)
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
        NSLog(
            "CritAlarmActivity: incident_closed incident_id=%@ process=%@",
            incidentId, Bundle.main.bundleIdentifier ?? "unknown"
        )
        await IncidentActivityCoordinator.shared.closed(incidentId: incidentId)
        // The widget drops the incident only once the server says it is over,
        // the same as Android. A 409 or a failed try leaves the row; Dart sends
        // the queued close later and its next snapshot write settles it.
        let status = await NativeAckSender.sendForStatus(action: "close", incidentId: incidentId)
        if NativeAckSender.endsTheIncident(status: status) {
            WidgetSnapshotStore.patch(.ended(incidentId))
        }
        return .result()
    }
}
