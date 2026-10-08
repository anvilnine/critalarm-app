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

/// The one thing native code knows about wake-up challenges: whether a
/// topic owes one before its incident is closed.
///
/// Dart writes one flag per topic, and only when it is sure. Nothing here
/// works a plan out. The app copies the flagged topics into the app group
/// with the sound choices (`SoundLibrary.publishChoices`), because the
/// Live Activity is drawn in the widget extension and cannot read the app's
/// own defaults.
///
/// The flag is about the Done button on a card that is already
/// acknowledged. It is never read on the way to stopping a ring. A flag
/// that is missing, or that is not a boolean, is "nothing owed", so Done
/// closes the incident as it always has.
public enum ChallengeFlag {
    static let appGroup = "group.app.critalarm"

    /// Where Dart writes the flags: `topic_challenge_owed.<topic>` through
    /// `shared_preferences`, which adds the `flutter.` prefix.
    /// `ChallengeChoices.owedKeyPrefix` in
    /// lib/features/challenges/domain/challenge_choices.dart.
    static let appKeyPrefix = "flutter.topic_challenge_owed."

    /// The copy in the app group, written on every publish: the names of
    /// the topics that owe a challenge.
    static let groupKey = "challenge_owed_topics"

    static var groupDefaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    /// The topics flagged in the app's own defaults, sorted. Only a real
    /// `true` counts: a number or a string under the key does not.
    static func owedTopics(in defaults: UserDefaults) -> [String] {
        defaults.dictionaryRepresentation().compactMap { key, value -> String? in
            guard key.hasPrefix(appKeyPrefix), isTrue(value) else { return nil }
            let topic = String(key.dropFirst(appKeyPrefix.count))
            return topic.isEmpty ? nil : topic
        }.sorted()
    }

    private static func isTrue(_ value: Any) -> Bool {
        guard CFGetTypeID(value as CFTypeRef) == CFBooleanGetTypeID() else { return false }
        return (value as? Bool) == true
    }

    /// Copies the flags into the group. A topic that lost its flag is gone
    /// from the copy.
    static func publish(from defaults: UserDefaults, to shared: UserDefaults) {
        shared.set(owedTopics(in: defaults), forKey: groupKey)
    }

    /// Whether [topic] owes a challenge, as last published. False when
    /// nothing was published, and for a card with no topic.
    static func owes(topic: String, in shared: UserDefaults?) -> Bool {
        guard !topic.isEmpty, let topics = shared?.stringArray(forKey: groupKey) else {
            return false
        }
        return topics.contains(topic)
    }
}

/// What Done on an acknowledged card does.
public enum DoneButton: Equatable {
    /// Closes the incident from the card, with no app. What it always did.
    case closes

    /// Opens the app on the incident's acknowledged screen and closes
    /// nothing. The challenge is asked there, with its way out on screen.
    case opensApp

    static func forCard(topic: String, shared: UserDefaults?) -> DoneButton {
        ChallengeFlag.owes(topic: topic, in: shared) ? .opensApp : .closes
    }
}

/// Whether the app may run the close on behalf of a Done button it says
/// was pressed.
///
/// The app only says so because a link carried a marker, and
/// `critalarm://` links can be opened by any app or web page. So the marker
/// proves nothing. What this phone itself recorded does: the close goes
/// ahead only for an incident that is acknowledged here and quiet, which is
/// exactly the incident whose card carries Done.
///
/// It matters most here: the close ends the Live Activity before the
/// server answers, and for an incident nobody acknowledged that card is
/// where "I'm up" is.
public enum DoneHandOffRule {
    /// - [acked]: the incident is in `AckedIncidentStore`, set by "I'm up"
    ///   on this phone or by an acknowledge from elsewhere. Needed, and not
    ///   enough: only the app's own push handler drops the mark when the
    ///   incident opens again, so with the app force-quit it can be stale.
    /// - [alarmUnderWay]: an AlarmKit alarm exists for the incident,
    ///   alerting, counting down or re-armed.
    /// - [cardState]: the state on the incident's Live Activity, nil when
    ///   it has none. A silenced card and a reopened one say `open`.
    /// - [widgetState]: the state the widget snapshot holds for the
    ///   incident (`WidgetIncident.open` or `.acked`), nil when the
    ///   snapshot does not show it. The notification extension turns it
    ///   back to open on a reopen push, with no app running.
    ///
    /// A missing card is not enough. One of the two surfaces that draw
    /// Done has to say, now, that the incident is acknowledged: the Live
    /// Activity, or with no Live Activity the widget snapshot. And the
    /// snapshot saying open refuses whatever the card says.
    ///
    /// An id this phone has never seen is in no store, and is refused. A
    /// refusal costs little: the person closes from the app once online.
    static func mayClose(
        acked: Bool,
        alarmUnderWay: Bool,
        cardState: IncidentActivityState?,
        widgetState: String?
    ) -> Bool {
        guard acked, !alarmUnderWay else { return false }
        if widgetState == WidgetIncident.open { return false }
        if let cardState { return cardState == .acked }
        return widgetState == WidgetIncident.acked
    }

    /// The state the widget snapshot holds for [incidentId], or nil when
    /// no topic in it shows that incident.
    static func widgetState(incidentId: String, in snapshot: WidgetSnapshot?) -> String? {
        snapshot?.topics.first { $0.incident?.id == incidentId }?.incident?.state
    }
}

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
