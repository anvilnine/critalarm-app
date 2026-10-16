import Foundation
import UserNotifications
#if canImport(AlarmKit)
import AlarmKit
#endif

/// Sets the phone's own next ring for an incident the user silenced.
///
/// [RearmRule] is the decision and reads nothing. This finds the five inputs,
/// then puts the ring where the OS can hold it:
///
/// - iOS 26 and later: another AlarmKit alarm under the same
///   `IncidentAlarmScheduler.alarmId(for:)`, set from the Stop intent. The
///   intent runs in the app's own process, so the alarm survives a force-quit,
///   which is the one exit the server repeat cannot reach.
/// - iOS 16 to 25: a Time-Sensitive local notification under the incident id,
///   with the same `alarm.caf` and the `INCIDENT` category. The server repeat
///   lands on the same `apns-collapse-id`, so the two stay one card.
enum IncidentRearm {
    static let category = "INCIDENT"
    private static let debugKey = "critalarm.pending_rearms"

    /// Silence plus a new ring for the same id. Answers the seconds until that
    /// ring, or nil when nothing was set.
    @discardableResult
    static func rearm(
        incidentId: String,
        now: Date = Date(),
        center: UNUserNotificationCenter? = .current()
    ) async -> Int? {
        let pending = PendingIncidentStore.read(incidentId: incidentId)
        let topic = pending?.topic
        let timers = TopicTimers.read(topic: topic)
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

        guard let at = RearmRule.nextRingAt(
            now: now,
            repeatIntervalS: timers?.repeatIntervalS ?? RearmRule.defaultRepeatIntervalS,
            ringUntil: pending?.ringUntil
        ) else {
            NSLog("CritAlarmAlarm: rearm_skipped reason=past_ring_until incident_id=%@", incidentId)
            return nil
        }

        let delay = at.timeIntervalSince(now)
        let seconds = Int(delay.rounded())

        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            let ok = await IncidentAlarmScheduler.schedule(
                incidentId: incidentId,
                topic: pending?.topic ?? "",
                server: pending?.server ?? "",
                title: pending?.title ?? "Crit Alarm",
                sound: pending?.sound,
                delay: delay,
                ringUntil: pending?.ringUntil
            )
            if ok {
                remember(incidentId: incidentId, firesAt: at)
                NSLog("CritAlarmAlarm: rearm_set incident_id=%@ in_s=%d", incidentId, seconds)
                return seconds
            }
            // AlarmKit refused, which is what a revoked authorization looks
            // like. Fall through to the notification.
        }
        #endif

        guard let center else { return nil }
        let content = UNMutableNotificationContent()
        content.title = pending?.title ?? "Crit Alarm"
        content.body = "Still ringing. Tap I'm up to end it."
        content.sound = UNNotificationSound(named: UNNotificationSoundName(
            OwnSoundLock.alarmSound(
                requested: pending?.sound,
                ownLocked: OwnSoundLock.isLocked(in: OwnSoundLock.groupDefaults),
                bundled: IncidentAlarmScheduler.soundName
            )
        ))
        content.categoryIdentifier = category
        content.userInfo = ["incident_id": incidentId]
        if #available(iOS 15.0, *) { content.interruptionLevel = .timeSensitive }
        let request = UNNotificationRequest(
            identifier: incidentId,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(delay, 1), repeats: false)
        )
        do {
            try await center.add(request)
            remember(incidentId: incidentId, firesAt: at)
            NSLog("CritAlarmAlarm: rearm_notification_set incident_id=%@ in_s=%d", incidentId, seconds)
            return seconds
        } catch {
            NSLog("CritAlarmAlarm: rearm_failed incident_id=%@ error=%@", incidentId, "\(error)")
            return nil
        }
    }

    /// Drops a pending re-arm, whichever of the two holds it. Safe to call
    /// when there is none.
    static func cancel(incidentId: String, center: UNUserNotificationCenter? = .current()) async {
        center?.removePendingNotificationRequests(withIdentifiers: [incidentId])
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            await IncidentAlarmScheduler.cancel(incidentId: incidentId)
        }
        #endif
        forget(incidentId: incidentId)
        NSLog("CritAlarmAlarm: rearm_cancelled incident_id=%@", incidentId)
    }

    static func debugEntries() -> [String: Date] {
        let values = UserDefaults.standard.dictionary(forKey: debugKey) as? [String: Double] ?? [:]
        return values.reduce(into: [:]) { result, entry in
            result[entry.key] = Date(timeIntervalSince1970: entry.value)
        }
    }

    private static func remember(incidentId: String, firesAt: Date) {
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

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: "group.app.critalarm") ?? .standard
    }

    static func decide(expected: Int?, current: Int, live: Bool) -> Outcome {
        guard let expected, expected == current else { return .refused }
        return live ? .stopped : .nothing
    }

    static func current(incidentId: String) -> Int {
        (defaults.dictionary(forKey: key)?[incidentId] as? Int) ?? 0
    }

    @discardableResult
    static func bump(incidentId: String) -> Int {
        var values = defaults.dictionary(forKey: key) as? [String: Int] ?? [:]
        let next = (values[incidentId] ?? 0) + 1
        values[incidentId] = next
        // The map only needs incidents that can still ring. Past a few
        // hundred, the others go; a forgotten one starts again from zero.
        if values.count > 300 {
            var kept = Dictionary(uniqueKeysWithValues: values.prefix(200).map { ($0.key, $0.value) })
            kept[incidentId] = next
            values = kept
        }
        defaults.set(values, forKey: key)
        return next
    }

    /// True when this phone rings for [incidentId] now or has a ring set for
    /// it: an AlarmKit alarm in any state, or a re-arm waiting (the
    /// notification form on older iPhones). Alarms that cannot be read count
    /// as set.
    static func ringIsSet(incidentId: String) -> Bool {
        if IncidentRearm.debugEntries()[incidentId] != nil { return true }
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
    /// accepted answer when nothing was ringing.
    @available(iOS 16.2, *)
    @MainActor
    static func applyIfCurrent(
        _ state: IncidentActivityState,
        incidentId: String,
        expected: Int?,
        applyWhenNothingSet: Bool = false
    ) async -> Outcome {
        await AlarmSerial.shared.run {
            let outcome = decide(
                expected: expected,
                current: current(incidentId: incidentId),
                live: ringIsSet(incidentId: incidentId)
            )
            switch outcome {
            case .refused:
                NSLog("CritAlarmAlarm: remote_state_refused reason=newer_ring incident_id=%@", incidentId)
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
