import Foundation

#if canImport(ActivityKit)
import ActivityKit
#endif

/// Owns every Live Activity this app starts, ends or is handed by the relay.
///
/// Three jobs:
///
/// 1. **Tokens.** The push-to-start token (one per app, iOS 17.2+) and the
///    per-activity update token both go to the relay. Capturing them is a
///    native job; sending them is Dart's, through `LiveActivityTokenRegistry`,
///    so the relay call reuses the one API client. Tokens captured before Dart
///    is up wait in `pendingTokens`.
///
/// 2. **The single-activity rule.** While AlarmKit is ringing for an incident
///    it shows its own Live Activity. Starting ours on top would put two cards
///    for one incident on the lock screen. So ours starts only once the alarm
///    is gone, which is on Stop, and the acknowledge surface takes over.
///
/// 3. **Cancel on close.** A push that says the incident is closed or expired
///    ends the card, and so does a launch that finds it already closed on the
///    server.
@available(iOS 16.2, *)
@MainActor
public final class IncidentActivityCoordinator {
    public static let shared = IncidentActivityCoordinator()

    /// What the relay calls each token. Sent as `kind` on
    /// `POST /relay/v1/devices/{id}/tokens`.
    public enum TokenKind: String {
        /// One per install. Lets the relay start an activity with no app running.
        case pushToStart = "la_start"
        /// One per activity. Lets the relay update or end that one card.
        case update = "la_update"
    }

    /// Where tokens wait when Dart is not listening yet, and where the
    /// diagnostics screen reads "not ready" from.
    public static let pendingTokensKey = "flutter.pending_activity_tokens"
    public static let pushToStartReadyKey = "flutter.live_activity_push_to_start_ready"

    /// Set by `IncidentAlarmScheduler` while an AlarmKit alarm exists for an
    /// incident. Nothing else may start a card for those.
    private var alarmingIncidents: Set<String> = []

    /// Told about a new token so it can send it now instead of next launch.
    public var onTokenCaptured: ((TokenKind, String, String?, String?) -> Void)?

    private var streamsStarted = false
    private var perActivityWatchers: [String: Task<Void, Never>] = [:]

    /// One per activity, watching its content state rather than its push
    /// token. Keyed the same way, cancelled in the same place.
    private var contentWatchers: [String: Task<Void, Never>] = [:]

    private init() {}

    // MARK: - Tokens

    /// Starts on every launch. Reads the push-to-start stream and watches for
    /// activities the relay started while the app was away.
    public func start() {
        guard !streamsStarted else { return }
        streamsStarted = true

        #if canImport(ActivityKit)
        if #available(iOS 17.2, *) {
            Task { await self.watchPushToStartToken() }
        } else {
            NSLog("CritAlarmActivity: push_to_start_unsupported os=%@", ProcessInfo.processInfo.operatingSystemVersionString)
            setPushToStartReady(false)
        }
        Task { await self.watchActivities() }
        #endif
    }

    #if canImport(ActivityKit)
    @available(iOS 17.2, *)
    private func watchPushToStartToken() async {
        // Seen in the field on iOS 26.5: the stream can stay quiet for a whole
        // session. Diagnostics says "not ready" until the first one lands and
        // the next launch asks again.
        setPushToStartReady(false)
        for await data in Activity<CritAlarmIncidentAttributes>.pushToStartTokenUpdates {
            let hex = data.map { String(format: "%02x", $0) }.joined()
            guard !hex.isEmpty else {
                NSLog("CritAlarmActivity: push_to_start_token_nil")
                setPushToStartReady(false)
                continue
            }
            NSLog("CritAlarmActivity: push_to_start_token length=%d", hex.count)
            #if DEBUG
            // Needed to aim a Live Activity start push at this handset, the
            // same reason the APNs token is printed. Debug only.
            NSLog("CritAlarmActivity: push_to_start_token=%@", hex)
            #endif
            setPushToStartReady(true)
            capture(.pushToStart, token: hex, incidentId: nil)
        }
    }

    /// Every activity, however it started: ours locally, or the relay's
    /// `event: start`. Each one's update token goes up tagged with its
    /// incident.
    private func watchActivities() async {
        for activity in Activity<CritAlarmIncidentAttributes>.activities {
            watchUpdateToken(of: activity)
        }
        for await activity in Activity<CritAlarmIncidentAttributes>.activityUpdates {
            watchUpdateToken(of: activity)
        }
    }

    private func watchUpdateToken(of activity: Activity<CritAlarmIncidentAttributes>) {
        guard perActivityWatchers[activity.id] == nil else { return }
        let incidentId = activity.attributes.incidentId
        watchContentState(of: activity)
        perActivityWatchers[activity.id] = Task { [weak self] in
            for await data in activity.pushTokenUpdates {
                let hex = data.map { String(format: "%02x", $0) }.joined()
                guard !hex.isEmpty else { continue }
                NSLog(
                    "CritAlarmActivity: activity_update_token incident_id=%@ length=%d",
                    incidentId, hex.count
                )
                #if DEBUG
                NSLog("CritAlarmActivity: activity_update_token=%@", hex)
                #endif
                await self?.capture(.update, token: hex, incidentId: incidentId, activityId: activity.id)
            }
            await self?.forgetWatcher(activity.id)
        }
    }

    /// The relay's `ack`, `close` and `expire` reach this device as a Live
    /// Activity update (api.md §5.3), which lands straight in the widget
    /// process. This is how the app hears about them, so it can cancel the
    /// AlarmKit alarm and the pending re-arm for an incident somebody else
    /// already answered.
    private func watchContentState(of activity: Activity<CritAlarmIncidentAttributes>) {
        guard contentWatchers[activity.id] == nil else { return }
        let incidentId = activity.attributes.incidentId
        contentWatchers[activity.id] = Task { [weak self] in
            for await content in activity.contentUpdates {
                await self?.applyRemoteState(content.state.state, incidentId: incidentId)
            }
        }
    }

    private func forgetWatcher(_ id: String) {
        contentWatchers[id]?.cancel()
        contentWatchers[id] = nil
        perActivityWatchers[id]?.cancel()
        perActivityWatchers[id] = nil
    }
    #endif

    private func capture(_ kind: TokenKind, token: String, incidentId: String?, activityId: String? = nil) {
        var entry: [String: Any] = ["kind": kind.rawValue, "token": token]
        if let incidentId { entry["incident_id"] = incidentId }
        if let activityId { entry["activity_id"] = activityId }
        appendPending(entry)
        onTokenCaptured?(kind, token, incidentId, activityId)
    }

    /// Everything captured so far, handed to Dart once and cleared.
    public func takePendingTokens() -> [[String: Any]] {
        let defaults = UserDefaults.standard
        guard let raw = defaults.string(forKey: Self.pendingTokensKey),
              let data = raw.data(using: .utf8),
              let decoded = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return [] }
        defaults.removeObject(forKey: Self.pendingTokensKey)
        return decoded
    }

    private func appendPending(_ entry: [String: Any]) {
        let defaults = UserDefaults.standard
        var entries: [[String: Any]] = []
        if let raw = defaults.string(forKey: Self.pendingTokensKey),
           let data = raw.data(using: .utf8),
           let decoded = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            entries = decoded
        }
        // One entry per (kind, activity). A rotated token replaces the old one.
        entries.removeAll {
            ($0["kind"] as? String) == (entry["kind"] as? String)
                && ($0["activity_id"] as? String) == (entry["activity_id"] as? String)
        }
        entries.append(entry)
        guard let data = try? JSONSerialization.data(withJSONObject: entries),
              let json = String(data: data, encoding: .utf8) else { return }
        defaults.set(json, forKey: Self.pendingTokensKey)
    }

    private func setPushToStartReady(_ ready: Bool) {
        UserDefaults.standard.set(ready, forKey: Self.pushToStartReadyKey)
    }

    // MARK: - The single-activity rule

    /// Called by the scheduler when an AlarmKit alarm is scheduled for an
    /// incident, and again when it goes away.
    public func setAlarmActive(_ active: Bool, incidentId: String) {
        if active {
            alarmingIncidents.insert(incidentId)
        } else {
            alarmingIncidents.remove(incidentId)
        }
    }

    /// Drops every incident whose alarm AlarmKit no longer lists. Fed by
    /// `AlarmManager.alarmUpdates`, so an alarm the user stopped somewhere
    /// else stops blocking our card.
    public func syncAlarms(liveAlarmIds: Set<UUID>) {
        alarmingIncidents = alarmingIncidents.filter {
            liveAlarmIds.contains(IncidentAlarmScheduler.alarmId(for: $0))
        }
    }

    /// The rule in one place, so the test can call it without ActivityKit.
    /// AlarmKit shows its own card while it rings; a second one for the same
    /// incident would be a duplicate.
    public func mayStartActivity(incidentId: String) -> Bool {
        !alarmingIncidents.contains(incidentId)
    }

    // MARK: - Starting and ending

    /// Onboarding calls this once so the Allow prompt happens before the relay
    /// ever tries a remote start. Update tokens are not issued until Allow.
    @discardableResult
    public func startLocalActivity(
        incidentId: String,
        topic: String,
        server: String,
        title: String,
        state: IncidentActivityState = .open,
        openedAt: Date = Date()
    ) -> Bool {
        #if canImport(ActivityKit)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            NSLog("CritAlarmActivity: activity_start_skipped reason=not_enabled")
            return false
        }
        guard mayStartActivity(incidentId: incidentId) else {
            NSLog("CritAlarmActivity: activity_start_skipped reason=alarm_active incident_id=%@", incidentId)
            return false
        }
        if activity(for: incidentId) != nil {
            NSLog("CritAlarmActivity: activity_start_skipped reason=already_showing incident_id=%@", incidentId)
            return false
        }
        let attributes = CritAlarmIncidentAttributes(
            incidentId: incidentId, topic: topic, server: server
        )
        let content = CritAlarmIncidentAttributes.ContentState(
            state: state, title: title, openedAt: openedAt
        )
        do {
            _ = try Activity.request(
                attributes: attributes,
                content: .init(state: content, staleDate: nil),
                pushType: .token
            )
            NSLog("CritAlarmActivity: activity_started incident_id=%@ state=%@", incidentId, state.rawValue)
            return true
        } catch {
            NSLog("CritAlarmActivity: activity_start_failed incident_id=%@ error=%@", incidentId, "\(error)")
            return false
        }
        #else
        return false
        #endif
    }

    /// Stop on the alarm. The noise is over, the incident is not.
    ///
    /// AlarmKit's own card is going away, so ours takes over. It stays in
    /// `open`, because nobody acknowledged anything, and it carries the one
    /// button that ends the loop.
    public func alarmSilenced(incidentId: String) {
        setAlarmActive(false, incidentId: incidentId)
        #if canImport(ActivityKit)
        let pending = PendingIncidentStore.read(incidentId: incidentId)
        startLocalActivity(
            incidentId: incidentId,
            topic: pending?.topic ?? "",
            server: pending?.server ?? "",
            title: pending?.title ?? "Crit Alarm",
            state: .open,
            openedAt: pending?.openedAt ?? Date()
        )
        #endif
    }

    /// Puts "Rings again in N s" on the card the user just silenced.
    public func setRingsAgainIn(_ seconds: Int, incidentId: String) async {
        #if canImport(ActivityKit)
        guard let activity = activity(for: incidentId) else { return }
        var content = activity.content.state
        content.ringsAgainInSeconds = seconds
        await activity.update(.init(state: content, staleDate: nil))
        NSLog(
            "CritAlarmActivity: activity_silenced incident_id=%@ rings_again_in_s=%d",
            incidentId, seconds
        )
        #endif
    }

    /// The server said the incident was acknowledged, closed or expired, and
    /// on iOS that arrives as a Live Activity update (api.md §5.3).
    ///
    /// Whatever is ringing here stops, and so does the ring this phone had set
    /// for itself. Android hears the same three as data-only pushes (§5.2).
    public func applyRemoteState(
        _ state: IncidentActivityState,
        incidentId: String
    ) async {
        guard state != .open else { return }
        NSLog(
            "CritAlarmActivity: remote_state_applied incident_id=%@ state=%@",
            incidentId, state.rawValue
        )
        // Marked first, so a repeat push that crosses this does not ring.
        AckedIncidentStore.markRemotelyAcknowledged(incidentId: incidentId)
        WidgetSnapshotStore.patch(state == .acked ? .acked(incidentId, at: Date()) : .ended(incidentId))
        await IncidentRearm.cancel(incidentId: incidentId)
        setAlarmActive(false, incidentId: incidentId)
        if state != .acked {
            end(incidentId: incidentId, finalState: state)
        }
    }

    /// "I'm up" on the alarm. AlarmKit's own card is going away, so ours takes
    /// over as the acknowledge surface.
    public func alarmStopped(incidentId: String) {
        setAlarmActive(false, incidentId: incidentId)
        #if canImport(ActivityKit)
        let pending = PendingIncidentStore.read(incidentId: incidentId)
        startLocalActivity(
            incidentId: incidentId,
            topic: pending?.topic ?? "",
            server: pending?.server ?? "",
            title: pending?.title ?? "Incident acknowledged",
            state: .acked,
            openedAt: pending?.openedAt ?? Date()
        )
        #endif
    }

    /// Done on the card. Stage 2 is sent; the card has nothing left to show.
    public func closed(incidentId: String) {
        end(incidentId: incidentId, finalState: .closed)
    }

    /// A push, or a launch reconciling against the server, said this incident
    /// is done.
    public func end(incidentId: String, finalState: IncidentActivityState) {
        #if canImport(ActivityKit)
        guard let activity = activity(for: incidentId) else { return }
        let content = CritAlarmIncidentAttributes.ContentState(
            state: finalState,
            title: activity.content.state.title,
            openedAt: activity.content.state.openedAt
        )
        Task {
            await activity.end(.init(state: content, staleDate: nil), dismissalPolicy: .immediate)
            NSLog("CritAlarmActivity: activity_ended incident_id=%@ state=%@", incidentId, finalState.rawValue)
        }
        PendingIncidentStore.clear(incidentId: incidentId)
        #endif
    }

    /// Incident ids with a card on screen right now.
    public func showingIncidentIds() -> [String] {
        #if canImport(ActivityKit)
        return Activity<CritAlarmIncidentAttributes>.activities.map(\.attributes.incidentId)
        #else
        return []
        #endif
    }

    #if canImport(ActivityKit)
    private func activity(for incidentId: String) -> Activity<CritAlarmIncidentAttributes>? {
        Activity<CritAlarmIncidentAttributes>.activities
            .first { $0.attributes.incidentId == incidentId }
    }
    #endif
}

/// What the alarm knew about an incident, kept so the card started on Stop can
/// show the same title instead of a placeholder.
enum PendingIncidentStore {
    struct Entry {
        let topic: String
        let server: String
        let title: String
        let openedAt: Date

        /// `ring_until` off the push (api.md §5.1). The last second this phone
        /// may ring for the incident on its own. Nil when no push carried one,
        /// which is the onboarding demo and nothing else.
        let ringUntil: Date?

        /// The sound the alarm rang with, so a re-arm rings the same one.
        let sound: String?
    }

    static let key = "critalarm.pending_incidents"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: "group.app.critalarm") ?? .standard
    }

    static func write(
        incidentId: String,
        topic: String,
        server: String,
        title: String,
        openedAt: Date,
        ringUntil: Date? = nil,
        sound: String? = nil
    ) {
        var all = readAll()
        var entry: [String: Any] = [
            "topic": topic,
            "server": server,
            "title": title,
            "opened_at": openedAt.timeIntervalSince1970,
        ]
        // Kept from the last push that carried them. A re-arm reads them with
        // no network call, and a schedule that learned neither must not wipe
        // what an earlier one knew.
        if let ringUntil {
            entry["ring_until"] = ringUntil.timeIntervalSince1970
        } else if let existing = all[incidentId]?["ring_until"] {
            entry["ring_until"] = existing
        }
        if let sound {
            entry["sound"] = sound
        } else if let existing = all[incidentId]?["sound"] {
            entry["sound"] = existing
        }
        all[incidentId] = entry
        save(all)
    }

    static func read(incidentId: String) -> Entry? {
        guard let raw = readAll()[incidentId] else { return nil }
        return Entry(
            topic: raw["topic"] as? String ?? "",
            server: raw["server"] as? String ?? "",
            title: raw["title"] as? String ?? "",
            openedAt: Date(timeIntervalSince1970: raw["opened_at"] as? TimeInterval ?? 0),
            ringUntil: (raw["ring_until"] as? TimeInterval).flatMap {
                $0 > 0 ? Date(timeIntervalSince1970: $0) : nil
            },
            sound: (raw["sound"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        )
    }

    static func clear(incidentId: String) {
        var all = readAll()
        all.removeValue(forKey: incidentId)
        save(all)
    }

    static func all() -> [String: Entry] {
        Dictionary(uniqueKeysWithValues: readAll().keys.compactMap { id in
            read(incidentId: id).map { (id, $0) }
        })
    }

    private static func readAll() -> [String: [String: Any]] {
        defaults.dictionary(forKey: key) as? [String: [String: Any]] ?? [:]
    }

    private static func save(_ all: [String: [String: Any]]) {
        defaults.set(all, forKey: key)
    }
}
