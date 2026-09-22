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
        content.sound = UNNotificationSound(named: UNNotificationSoundName(pending?.sound ?? IncidentAlarmScheduler.soundName))
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
        NSLog("CritAlarmAlarm: rearm_cancelled incident_id=%@", incidentId)
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
