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
            + chainRows(requests: notificationRequests.map(\.identifier))
            + probeRows()

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
        await IncidentChain.cancelAll()
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

    /// One row per chain: its kind, how many slots the system holds for it
    /// and when the next one rings.
    private static func chainRows(requests: [String]) -> [[String: Any]] {
        var present = Set<UUID>()
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            present = Set((try? AlarmManager.shared.alarms)?.map(\.id) ?? [])
        }
        #endif
        let pendingIds = Set(requests)
        let now = Date()
        return IncidentChainStore.all().sorted { $0.key < $1.key }.map { incidentId, record in
            let upcoming = ChainRule.wanted(record, now: now, cap: ChainRule.maxSlots)
            let held = upcoming.filter {
                present.contains(ChainRule.alarmId(incidentId: incidentId, kind: record.kind, index: $0.index))
                    || pendingIds.contains(
                        ChainRule.notificationId(incidentId: incidentId, kind: record.kind, index: $0.index)
                    )
            }
            var row: [String: Any] = [
                "kind": "chain_\(record.kind.rawValue)",
                "identifier": "\(incidentId) held=\(held.count) of=\(upcoming.count)",
            ]
            if let next = held.first { row["fires_at"] = epochSeconds(next.at) }
            return row
        }
    }

    /// Where the last capacity probe left its answer.
    private static let probeKey = "critalarm.alarm_capacity_probe"

    private static func probeRows() -> [[String: Any]] {
        guard let line = UserDefaults.standard.string(forKey: probeKey) else { return [] }
        return [["kind": "alarmkit_probe", "identifier": line]]
    }

    #if DEBUG
    /// Asks AlarmKit how many alarms it holds for this app: sets [count] on
    /// fixed dates an hour out, half a minute apart, lists them back, then
    /// cancels every one. Apple names a limit (`maximumLimitReached`) and
    /// not its size. Nothing rings: every alarm is gone before its time.
    static func probeAlarmCapacity(count: Int = 60) async -> [String: Any] {
        var answer: [String: Any] = ["asked": count]
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            guard AlarmManager.shared.authorizationState == .authorized else {
                answer["error"] = "alarmkit_not_authorized"
                return record(answer)
            }
            let start = Date().addingTimeInterval(3600)
            let ids = (0..<count).map { ChainRule.uuid(from: "capacity-probe#\($0)") }
            let dates = (0..<count).map { start.addingTimeInterval(TimeInterval($0 * 30)) }
            var scheduled = 0
            for (index, id) in ids.enumerated() {
                let configuration = AlarmManager.AlarmConfiguration.alarm(
                    schedule: .fixed(dates[index]),
                    attributes: IncidentAlarmScheduler.alarmAttributes(
                        incidentId: "capacity-probe", topic: "", server: "", title: "Crit Alarm"
                    ),
                    sound: .named(IncidentAlarmScheduler.soundName)
                )
                do {
                    _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
                    scheduled += 1
                } catch {
                    answer["first_error_at"] = index
                    answer["first_error"] = "\(error)"
                    break
                }
            }
            let listed = (try? AlarmManager.shared.alarms) ?? []
            let mine = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
            let held = listed.filter { mine[$0.id] != nil }
            // Whether a fixed date keeps its seconds, which a 30 s chain needs.
            let exact = held.filter { alarm in
                guard case let .fixed(date)? = alarm.schedule, let index = mine[alarm.id] else { return false }
                return abs(date.timeIntervalSince(dates[index])) < 1
            }
            answer["scheduled"] = scheduled
            answer["listed"] = held.count
            answer["listed_total"] = listed.count
            answer["dates_exact"] = exact.count
            for id in ids { try? AlarmManager.shared.cancel(id: id) }
            answer["left_after_cancel"] = ((try? AlarmManager.shared.alarms) ?? [])
                .filter { mine[$0.id] != nil }.count
            return record(answer)
        }
        #endif
        answer["error"] = "alarmkit_unavailable"
        return record(answer)
    }

    private static func record(_ answer: [String: Any]) -> [String: Any] {
        let line = answer.keys.sorted().map { "\($0)=\(answer[$0] ?? "")" }.joined(separator: " ")
        UserDefaults.standard.set(line, forKey: probeKey)
        NSLog("CritAlarmAlarm: alarm_capacity_probe %@", line)
        PushEventLog.record("debug_action", ["action": "probe_alarm_capacity"])
        return answer
    }
    #endif

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
