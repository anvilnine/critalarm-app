import Foundation
import UserNotifications

#if canImport(AlarmKit)
import AlarmKit
#endif

/// Native-only alarm diagnostics. Reading the snapshot intentionally has no
/// side effects: the developer screen refreshes it every five seconds.
enum AlarmDebug {
    static func snapshot() async -> [String: Any] {
        let center = UNUserNotificationCenter.current()
        async let settings = center.notificationSettings()
        async let requests = center.pendingNotificationRequests()
        let pending = PendingIncidentStore.all()
        let rearming = IncidentRearm.debugEntries()
        let cache = IncidentContentCache.debugEntries()
        let marks = AckedIncidentStore.all()
        let localMarks = AckedIncidentStore.locallyAcknowledged()
        let now = Date()

        let incidentRows = pending.map { incidentId, entry -> [String: Any] in
            let rearmAt = rearming[incidentId]
            var row: [String: Any] = [
                "id": incidentId,
                "topic": entry.topic,
                "rearm_pending": rearmAt != nil,
                "acked_locally": localMarks.contains(incidentId),
                "phone_state": DebugStateRule.phoneState(
                    .init(
                        active: !marks.contains(incidentId),
                        acknowledged: marks.contains(incidentId),
                        inLocalAckedSet: localMarks.contains(incidentId),
                        live: alarmIsLive(incidentId: incidentId),
                        rearmPending: rearmAt != nil,
                        ringUntil: entry.ringUntil
                    ),
                    now: now
                ),
            ]
            if let ringUntil = entry.ringUntil { row["ring_until"] = epochSeconds(ringUntil) }
            if let rearmAt { row["rearm_fires_at"] = epochSeconds(rearmAt) }
            if let cached = cache[incidentId] {
                row["content_cached_at"] = cached.cachedAtMs / 1_000
                if let last = cached.lastMessageAt { row["content_last_message_at"] = last / 1_000 }
            }
            return row
        }

        let notificationRequests = await requests
        let knownIds = Set(pending.keys)
        let scheduled = notificationRequests.compactMap { request -> [String: Any]? in
            guard knownIds.contains(request.identifier) else { return nil }
            var row: [String: Any] = ["kind": "notification", "identifier": request.identifier]
            if let at = (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
                ?? (request.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate() {
                row["fires_at"] = epochSeconds(at)
            }
            return row
        } + rearming.map { ["kind": "rearm", "identifier": $0.key, "fires_at": epochSeconds($0.value)] }
            + alarmScheduleRows(incidentIds: knownIds)

        return [
            "incidents": incidentRows,
            "ack_queue": AckQueueStore.debugEntries(),
            "acked_set": AckedIncidentStore.debugEntries(),
            "push_events": PushEventLog.recent(),
            "scheduled": scheduled,
            "permissions": [
                "notifications": notificationPermission(await settings),
                "alarmkit": alarmAuthorization(),
                "battery_exempt": NSNull(),
            ],
            "ringing": pending.keys.contains { alarmIsLive(incidentId: $0) },
        ]
    }

    static func cancelAllRearms() async {
        for incidentId in IncidentRearm.debugEntries().keys {
            await IncidentRearm.cancel(incidentId: incidentId)
        }
        PushEventLog.record("debug_action", ["action": "cancel_all_rearms"])
    }

    static func clearContentCache() {
        IncidentContentCache.clear()
        PushEventLog.record("debug_action", ["action": "clear_content_cache"])
    }

    static func clearAckedSet() {
        AckedIncidentStore.clearLocalMarks()
        PushEventLog.record("debug_action", ["action": "clear_acked_set"])
    }

    private static func epochSeconds(_ date: Date) -> Int { Int(date.timeIntervalSince1970) }

    private static func notificationPermission(_ settings: UNNotificationSettings) -> String {
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return "authorized"
        case .denied: return "denied"
        case .notDetermined: return "not_determined"
        @unknown default: return "unsupported"
        }
    }

    private static func alarmAuthorization() -> String {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            switch AlarmManager.shared.authorizationState {
            case .authorized: return "authorized"
            case .denied: return "denied"
            case .notDetermined: return "not_determined"
            @unknown default: return "unsupported"
            }
        }
        #endif
        return "unsupported"
    }

    private static func alarmIsLive(incidentId: String) -> Bool {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            let id = IncidentAlarmScheduler.alarmId(for: incidentId)
            return (try? AlarmManager.shared.alarms)?.contains { $0.id == id && $0.state == .alerting } ?? false
        }
        #endif
        return false
    }

    private static func alarmScheduleRows(incidentIds: Set<String>) -> [[String: Any]] {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            let ids = Dictionary(uniqueKeysWithValues: incidentIds.map {
                (IncidentAlarmScheduler.alarmId(for: $0), $0)
            })
            return (try? AlarmManager.shared.alarms)?.compactMap { alarm in
                guard let incidentId = ids[alarm.id] else { return nil }
                var row: [String: Any] = [
                    "kind": "alarmkit",
                    "identifier": incidentId,
                    "state": String(describing: alarm.state),
                ]
                if case let .fixed(date)? = alarm.schedule {
                    row["fires_at"] = epochSeconds(date)
                }
                return row
            } ?? []
        }
        #endif
        return []
    }
}
