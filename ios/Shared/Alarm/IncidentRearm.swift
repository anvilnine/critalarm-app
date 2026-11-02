import Foundation
import UserNotifications
#if canImport(AlarmKit)
import AlarmKit
#endif

/// Keeps the phone ringing for an incident the user silenced.
///
/// The first ring of an incident sets its whole chain (`IncidentChain`), so
/// the next ring is already held by the system when Stop is tapped. Stop
/// still comes through here: it tops the chain up, which matters when
/// AlarmKit's limit kept it short, and starts one when none is set (an
/// incident that rang before this phone kept chains, or a push the app
/// never saw). [RearmRule] is the decision for the ring chain and reads
/// nothing. A desk timer chain set by "I'm up" is topped up on its own rule.
///
/// - iOS 26 and later: AlarmKit alarms. Stop runs in the app's own process,
///   so the chain survives a force-quit, which is the one exit the server
///   repeat cannot reach.
/// - iOS 16 to 25: Time-Sensitive local notifications with the same sound
///   and the `INCIDENT` category.
enum IncidentRearm {
    static let category = "INCIDENT"
    private static let debugKey = "critalarm.pending_rearms"

    /// Silence, then make sure the next ring is set. Answers the seconds
    /// until that ring, or nil when nothing is set.
    @discardableResult
    static func rearm(
        incidentId: String,
        now: Date = Date(),
        center: UNUserNotificationCenter? = .current()
    ) async -> Int? {
        if IncidentChainStore.read(incidentId: incidentId)?.kind == .desk {
            return await IncidentChain.topUp(incidentId: incidentId, now: now, center: center)
        }

        let pending = PendingIncidentStore.read(incidentId: incidentId)
        let topic = pending?.topic
        let quietHours = QuietHours.read(from: QuietHours.groupDefaults)

        let allowed = RearmRule.canRearm(
            incidentId: incidentId,
            // Only an incident the alarm path already rang reaches here, and
            // that path runs on open, repeat and reopen alone.
            kind: .repeat,
            criticalOn: TopicTimers.criticalOn(topic: topic),
            ackedLocally: AckedIncidentStore.contains(incidentId: incidentId),
            ringUntil: pending?.ringUntil,
            now: now,
            quietHoursHold: quietHours.holdsRing(
                minuteOfDay: QuietHours.minuteOf(now),
                priority: QuietHours.criticalPriority
            )
        )
        guard allowed else {
            NSLog("CritAlarmAlarm: rearm_skipped incident_id=%@", incidentId)
            return nil
        }

        if IncidentChainStore.holdsRing(incidentId: incidentId),
           let seconds = await IncidentChain.topUp(incidentId: incidentId, now: now, center: center) {
            NSLog("CritAlarmAlarm: rearm_chain_held incident_id=%@ in_s=%d", incidentId, seconds)
            return seconds
        }
        // No chain, or nothing left in it: start one from now.
        let seconds = await IncidentChain.armRing(incidentId: incidentId, anchor: now, center: center)
        if let seconds {
            NSLog("CritAlarmAlarm: rearm_set incident_id=%@ in_s=%d", incidentId, seconds)
        } else {
            NSLog("CritAlarmAlarm: rearm_failed incident_id=%@", incidentId)
        }
        return seconds
    }

    /// [rearm] as one step on [AlarmSerial], the queue push arming and every
    /// guarded stop go through, so it never lands between a guarded stop's
    /// check and its cancel. Every re-arm outside the serial step itself
    /// goes through here: Stop, the in-app silence and a dismissed banner.
    @MainActor
    @discardableResult
    static func rearmInOrder(
        incidentId: String,
        center: UNUserNotificationCenter? = .current()
    ) async -> Int? {
        await AlarmSerial.shared.run {
            await rearm(incidentId: incidentId, center: center)
        }
    }

    /// Drops every ring this phone set for itself for [incidentId]: the
    /// push alarm, the chain, and a single re-arm left by an older build.
    /// [path] says why, and `ChainRule.scope(for:)` whether a desk timer
    /// chain stays. Safe to call when there is nothing set.
    static func cancel(
        incidentId: String,
        for path: ChainRule.CancelPath = .ended,
        center: UNUserNotificationCenter? = .current()
    ) async {
        center?.removePendingNotificationRequests(withIdentifiers: [incidentId])
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            await IncidentAlarmScheduler.cancel(incidentId: incidentId)
        }
        #endif
        await IncidentChain.cancel(
            incidentId: incidentId, scope: ChainRule.scope(for: path), center: center
        )
        if IncidentChainStore.read(incidentId: incidentId) == nil {
            forget(incidentId: incidentId)
        }
        NSLog("CritAlarmAlarm: rearm_cancelled incident_id=%@ path=%@", incidentId, path.rawValue)
    }

    /// "I'm up" on this phone: the ring chain goes and the desk timer chain
    /// is set. Works with no network; the server hears from the ack queue.
    static func acknowledged(
        incidentId: String,
        at now: Date = Date(),
        center: UNUserNotificationCenter? = .current()
    ) async {
        await cancel(incidentId: incidentId, for: .imUp, center: center)
        await IncidentChain.armDesk(incidentId: incidentId, ackedAt: now, center: center)
    }

    static func debugEntries() -> [String: Date] {
        let values = UserDefaults.standard.dictionary(forKey: debugKey) as? [String: Double] ?? [:]
        return values.reduce(into: [:]) { result, entry in
            result[entry.key] = Date(timeIntervalSince1970: entry.value)
        }
    }

    static func remember(incidentId: String, firesAt: Date) {
        var values = UserDefaults.standard.dictionary(forKey: debugKey) as? [String: Double] ?? [:]
        values[incidentId] = firesAt.timeIntervalSince1970
        UserDefaults.standard.set(values, forKey: debugKey)
    }

    private static func forget(incidentId: String) {
        var values = UserDefaults.standard.dictionary(forKey: debugKey) as? [String: Double] ?? [:]
        values.removeValue(forKey: incidentId)
        UserDefaults.standard.set(values, forKey: debugKey)
    }
}

/// The per-topic timers and the critical switch, as Dart cached them.
///
/// Both come from `GET /v1/topics` and neither is on the push (api.md §5.1),
/// so the re-arm has no other way to learn them without a network call. Dart
/// writes them through shared_preferences, which on iOS is
/// `UserDefaults.standard` with a `flutter.` prefix
/// (`lib/core/notifications/topic_timer_cache.dart`).
struct TopicTimers {
    let repeatIntervalS: Int
    let maxRingS: Int
    let deskTimerS: Int

    static func read(topic: String?, defaults: UserDefaults = .standard) -> TopicTimers? {
        guard let topic, !topic.isEmpty else { return nil }
        return parse(defaults.string(forKey: "flutter.topic_timers.\(topic)"))
    }

    /// The cached value is `repeat_interval_s|max_ring_s|desk_timer_s`.
    static func parse(_ raw: String?) -> TopicTimers? {
        guard let raw else { return nil }
        let parts = raw.split(separator: "|").map { Int($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 3,
              let repeatInterval = parts[0], let maxRing = parts[1], let deskTimer = parts[2],
              repeatInterval > 0, maxRing > 0, deskTimer > 0
        else { return nil }
        return TopicTimers(repeatIntervalS: repeatInterval, maxRingS: maxRing, deskTimerS: deskTimer)
    }

    /// Whether the topic still rings.
    ///
    /// An incident whose topic this device has never listed reads as on: the
    /// push that rang it was a priority-5 alarm push, which the server only
    /// sends for a critical topic, and the server is still repeating anyway.
    static func criticalOn(topic: String?, defaults: UserDefaults = .standard) -> Bool {
        guard let topic, !topic.isEmpty else { return true }
        let key = "flutter.topic_critical.\(topic)"
        guard defaults.object(forKey: key) != nil else { return true }
        return defaults.bool(forKey: key)
    }
}

/// The ring generation of an incident on this phone.
///
/// A reopen moves `opened_at` (api.md §5.1), and an answer about an earlier
/// stage must never end the ring of a later one: that silences a phone for
/// an incident nobody handled. Pushes carry no `opened_at`, so the phone
/// counts instead. Every push that arms a ring moves the incident's
/// generation on by one (`bump`, called from the one push arming path in
/// `AppDelegate`). Stop's own re-arm does not. A check reads the generation
/// before its question goes out and hands it back with the answer; the
/// answer counts only if the generation has not moved. No clock is read.
///
/// The read and the cancel run as one step on [AlarmSerial], the same
/// queue push arming goes through, so a push cannot arm a ring between them.
/// Kept in the app group, because Stop can run in the widget extension.
enum RingGeneration {
    enum Outcome: String {
        /// The answer was for the ring going now, and a ring was stopped.
        case stopped
        /// The answer was for the ring going now, and nothing was set.
        case nothing
        /// A push armed a ring since the question went out, or no
        /// generation came with it. Nothing changed.
        case refused
    }

    private static let key = "critalarm.ring_generation"
    private static let floorKey = "critalarm.ring_generation_floor"

    /// How many incidents the map holds before it drops some, and how many
    /// it keeps when it does.
    private static let limit = 300
    private static let keep = 200

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: "group.app.critalarm") ?? .standard
    }

    static func decide(expected: Int?, current: Int, live: Bool, keepLive: Bool = false) -> Outcome {
        guard let expected, expected == current else { return .refused }
        // An answer that may end a card but never a ring: a 404 on launch
        // says the server forgot the incident, not that anyone handled it.
        if live, keepLive { return .refused }
        return live ? .stopped : .nothing
    }

    static func current(incidentId: String) -> Int {
        current(
            in: defaults.dictionary(forKey: key) as? [String: Int] ?? [:],
            floor: defaults.integer(forKey: floorKey),
            incidentId: incidentId
        )
    }

    /// An incident the map no longer holds reads as the floor: the highest
    /// generation ever dropped. A value only goes up, so an answer held from
    /// an earlier stage never matches a later ring. Restarting a dropped
    /// incident from zero let it.
    static func current(in values: [String: Int], floor: Int, incidentId: String) -> Int {
        values[incidentId] ?? floor
    }

    @discardableResult
    static func bump(incidentId: String) -> Int {
        let state = bumped(
            defaults.dictionary(forKey: key) as? [String: Int] ?? [:],
            floor: defaults.integer(forKey: floorKey),
            incidentId: incidentId
        )
        // The floor first. A read between the two writes then sees either
        // the old map or a floor at least as high as anything dropped.
        defaults.set(state.floor, forKey: floorKey)
        defaults.set(state.values, forKey: key)
        return state.next
    }

    /// One push for [incidentId]: its generation moves on by one from what
    /// it reads now. The map only needs incidents that can still ring, so
    /// past [limit] it keeps the [keep] highest and the one just bumped, and
    /// the floor rises to the highest it dropped.
    static func bumped(
        _ values: [String: Int],
        floor: Int,
        incidentId: String
    ) -> (values: [String: Int], floor: Int, next: Int) {
        var values = values
        let next = current(in: values, floor: floor, incidentId: incidentId) + 1
        values[incidentId] = next
        guard values.count > limit else { return (values, floor, next) }
        let ranked = values.filter { $0.key != incidentId }.sorted { $0.value > $1.value }
        var kept = Dictionary(uniqueKeysWithValues: ranked.prefix(keep).map { ($0.key, $0.value) })
        kept[incidentId] = next
        let dropped = ranked.dropFirst(keep).map(\.value).max() ?? floor
        return (kept, max(floor, dropped), next)
    }

    /// True when this phone rings for [incidentId] now or has a ring set for
    /// it: an AlarmKit alarm in any state, or a re-arm waiting (the
    /// notification form on older iPhones), or a chain of rings. Alarms that
    /// cannot be read count as set.
    static func ringIsSet(incidentId: String) -> Bool {
        if IncidentRearm.debugEntries()[incidentId] != nil { return true }
        if IncidentChainStore.read(incidentId: incidentId) != nil { return true }
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            let alarmId = IncidentAlarmScheduler.alarmId(for: incidentId)
            return (try? AlarmManager.shared.alarms)?.contains { $0.id == alarmId } ?? true
        }
        #endif
        return false
    }

    /// Applies a state the server named, asked under generation [expected],
    /// as one serial step: read, decide, cancel. [applyWhenNothingSet] lets
    /// the Live Activity path still update the card and the widgets for an
    /// accepted answer when nothing was ringing. [keepLive] refuses an
    /// answer that would stop a ring that is set (launch reconcile's 404).
    @available(iOS 16.2, *)
    @MainActor
    static func applyIfCurrent(
        _ state: IncidentActivityState,
        incidentId: String,
        expected: Int?,
        applyWhenNothingSet: Bool = false,
        keepLive: Bool = false
    ) async -> Outcome {
        await AlarmSerial.shared.run {
            let outcome = decide(
                expected: expected,
                current: current(incidentId: incidentId),
                live: ringIsSet(incidentId: incidentId),
                keepLive: keepLive
            )
            switch outcome {
            case .refused:
                NSLog(
                    "CritAlarmAlarm: remote_state_refused incident_id=%@ keep_live=%d",
                    incidentId, keepLive ? 1 : 0
                )
            case .nothing:
                if applyWhenNothingSet {
                    await IncidentActivityCoordinator.shared.applyRemoteState(state, incidentId: incidentId)
                }
            case .stopped:
                await IncidentActivityCoordinator.shared.applyRemoteState(state, incidentId: incidentId)
            }
            return outcome
        }
    }
}

/// One step at a time for everything that sets or stops an incident ring:
/// push arming, Stop's re-arm and every guarded stop. A step waits for the
/// one before it to finish, awaits included, so a stop that checked the
/// generation always cancels before a newer ring is armed.
@MainActor
final class AlarmSerial {
    static let shared = AlarmSerial()

    private var tail: Task<Void, Never>?

    func run<T>(_ step: @escaping @MainActor () async -> T) async -> T {
        let previous = tail
        let task = Task { @MainActor () -> T in
            await previous?.value
            return await step()
        }
        tail = Task { @MainActor in _ = await task.value }
        return await task.value
    }
}
