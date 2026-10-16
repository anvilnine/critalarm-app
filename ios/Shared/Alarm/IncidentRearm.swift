import Foundation
import UserNotifications

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

/// The stage mark for an incident's ring on this phone.
///
/// A reopen moves `opened_at` (api.md §5.1), and an answer about an earlier
/// stage must never end the ring of a later one: that silences a phone for
/// an incident nobody handled. Pushes carry no `opened_at`, so the phone keeps
/// its own marks, on its own clock:
///
/// - `armedAt`: when any push last armed a ring for the incident. An answer
///   to a question asked before this may be about the old stage.
/// - `stageStartedAt`: when an `open` or `reopen` push armed one. A Live
///   Activity update names the stage it is about by `opened_at`, which is
///   compared against this.
///
/// Kept in the app group, because Stop can run in the widget extension.
enum RingStage {
    private static let armedKey = "critalarm.ring_armed_at"
    private static let stageKey = "critalarm.ring_stage_started_at"

    /// How far before this phone's stage mark a stage may have opened on the
    /// server and still be the same stage: push delivery plus clock drift. A
    /// reopen comes a whole desk timer after the stage before it.
    static let liveActivityMargin: TimeInterval = 120

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: "group.app.critalarm") ?? .standard
    }

    /// True when an answer may end the ring: it carries the moment its
    /// question went out, and no push armed a ring at or after that moment.
    /// No mark on record means no push came since this build.
    static func mayApply(checkedAt: Date?, armedAt: Date?) -> Bool {
        guard let checkedAt else { return false }
        guard let armedAt else { return true }
        return armedAt < checkedAt
    }

    /// True when a Live Activity update about the stage that opened at
    /// [updateOpenedAt] can be about the stage ringing here.
    static func updateEndsRingingStage(updateOpenedAt: Date, stageStartedAt: Date?) -> Bool {
        guard let stageStartedAt else { return true }
        return updateOpenedAt >= stageStartedAt.addingTimeInterval(-liveActivityMargin)
    }

    static func markArmed(incidentId: String, startsStage: Bool, at now: Date = Date()) {
        write(key: armedKey, incidentId: incidentId, date: now)
        if startsStage || stageStartedAt(incidentId: incidentId) == nil {
            write(key: stageKey, incidentId: incidentId, date: now)
        }
    }

    static func armedAt(incidentId: String) -> Date? { read(key: armedKey, incidentId: incidentId) }

    static func stageStartedAt(incidentId: String) -> Date? {
        read(key: stageKey, incidentId: incidentId)
    }

    private static func read(key: String, incidentId: String) -> Date? {
        (defaults.dictionary(forKey: key)?[incidentId] as? Double).map(Date.init(timeIntervalSince1970:))
    }

    private static func write(key: String, incidentId: String, date: Date) {
        var values = defaults.dictionary(forKey: key) as? [String: Double] ?? [:]
        values[incidentId] = date.timeIntervalSince1970
        // Two days covers any ring window; older marks go so the map stays small.
        let cutoff = date.addingTimeInterval(-2 * 24 * 3600).timeIntervalSince1970
        values = values.filter { $0.value >= cutoff }
        defaults.set(values, forKey: key)
    }
}
