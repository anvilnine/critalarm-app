import Foundation
import UserNotifications
#if canImport(AlarmKit)
import AlarmKit
#endif

/// The chains this phone set, one per incident, in the app group.
///
/// The Stop and "I'm up" intents can run in the widget extension as well as
/// the app, and both need to find the chain, so it is not kept in the app's
/// own defaults.
enum IncidentChainStore {
    static let key = "critalarm.incident_chains"

    static var groupDefaults: UserDefaults? { UserDefaults(suiteName: "group.app.critalarm") }

    static func all(in defaults: UserDefaults? = groupDefaults) -> [String: ChainRule.Record] {
        let raw = defaults?.dictionary(forKey: key) as? [String: Data] ?? [:]
        let decoder = JSONDecoder()
        return raw.reduce(into: [:]) { result, entry in
            if let record = try? decoder.decode(ChainRule.Record.self, from: entry.value) {
                result[entry.key] = record
            }
        }
    }

    static func read(incidentId: String, in defaults: UserDefaults? = groupDefaults) -> ChainRule.Record? {
        guard let data = (defaults?.dictionary(forKey: key) as? [String: Data])?[incidentId] else {
            return nil
        }
        return try? JSONDecoder().decode(ChainRule.Record.self, from: data)
    }

    static func write(
        _ record: ChainRule.Record,
        incidentId: String,
        in defaults: UserDefaults? = groupDefaults
    ) {
        guard let defaults, let data = try? JSONEncoder().encode(record) else { return }
        var raw = defaults.dictionary(forKey: key) as? [String: Data] ?? [:]
        raw[incidentId] = data
        defaults.set(raw, forKey: key)
    }

    static func clear(incidentId: String, in defaults: UserDefaults? = groupDefaults) {
        guard let defaults else { return }
        var raw = defaults.dictionary(forKey: key) as? [String: Data] ?? [:]
        guard raw.removeValue(forKey: incidentId) != nil else { return }
        defaults.set(raw, forKey: key)
    }

    /// True while the incident has its ring chain (not the desk chain).
    static func holdsRing(incidentId: String, in defaults: UserDefaults? = groupDefaults) -> Bool {
        read(incidentId: incidentId, in: defaults)?.kind == .ring
    }
}

/// Sets, tops up and cancels an incident's chain. [ChainRule] decides; this
/// reads the inputs and makes the system calls.
///
/// - iOS 26 and later: one AlarmKit alarm per slot, on a fixed date, with
///   the same look, sound and buttons as the push alarm.
/// - iOS 16 to 25, or AlarmKit not allowed: one Time-Sensitive local
///   notification per slot, every chain together held to 40.
enum IncidentChain {
    /// Whether slots go to AlarmKit. A phone where AlarmKit is not allowed
    /// gets the notification chain, as the single re-arm did.
    static var usesAlarmKit: Bool {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            return AlarmManager.shared.authorizationState == .authorized
        }
        #endif
        return false
    }

    /// Sets a new ring chain for [incidentId], replacing any chain it had.
    /// Answers the seconds until its first slot, or nil when none was set.
    @discardableResult
    static func armRing(
        incidentId: String,
        anchor: Date = Date(),
        offsetS: Int = 0,
        center: UNUserNotificationCenter? = .current()
    ) async -> Int? {
        let pending = PendingIncidentStore.read(incidentId: incidentId)
        let topic = pending?.topic ?? ""
        let timers = TopicTimers.read(topic: topic)
        guard let ringUntil = pending?.ringUntil,
              RearmRule.canRearm(
                  incidentId: incidentId,
                  kind: .repeat,
                  criticalOn: TopicTimers.criticalOn(topic: topic),
                  ackedLocally: AckedIncidentStore.contains(incidentId: incidentId),
                  ringUntil: ringUntil,
                  now: anchor,
                  // Each slot asks quiet hours on its own.
                  quietHoursHold: false
              )
        else {
            NSLog("CritAlarmAlarm: chain_skipped kind=ring incident_id=%@", incidentId)
            return nil
        }
        let record = ChainRule.ringRecord(
            anchor: anchor,
            offsetS: offsetS,
            repeatIntervalS: timers?.repeatIntervalS ?? RearmRule.defaultRepeatIntervalS,
            ringUntil: ringUntil,
            topic: topic,
            topicKnown: timers != nil
        )
        // Replace, never add.
        await cancel(incidentId: incidentId, scope: .all, center: center)
        IncidentChainStore.write(record, incidentId: incidentId)
        return await fill(incidentId: incidentId, record: record, now: anchor, center: center)
    }

    /// Sets the desk timer chain after "I'm up". Leaves a desk chain that is
    /// already set alone, so a second acknowledge does not move it.
    static func armDesk(
        incidentId: String,
        ackedAt: Date = Date(),
        center: UNUserNotificationCenter? = .current()
    ) async {
        if IncidentChainStore.read(incidentId: incidentId)?.kind == .desk { return }
        let pending = PendingIncidentStore.read(incidentId: incidentId)
        let topic = pending?.topic ?? ""
        let timers = TopicTimers.read(topic: topic)
        let record = ChainRule.deskRecord(
            ackedAt: ackedAt,
            deskTimerS: timers?.deskTimerS ?? defaultDeskTimerS,
            maxRingS: timers?.maxRingS ?? defaultMaxRingS,
            repeatIntervalS: timers?.repeatIntervalS ?? RearmRule.defaultRepeatIntervalS,
            topic: topic,
            topicKnown: timers != nil
        )
        guard ChainRule.mayStand(
            record,
            incidentId: incidentId,
            criticalOn: TopicTimers.criticalOn(topic: topic),
            ackedLocally: true,
            serverRang: pending?.ringUntil != nil,
            now: ackedAt
        ) else {
            NSLog("CritAlarmAlarm: chain_skipped kind=desk incident_id=%@", incidentId)
            return
        }
        await cancel(incidentId: incidentId, scope: .all, center: center)
        IncidentChainStore.write(record, incidentId: incidentId)
        _ = await fill(incidentId: incidentId, record: record, now: ackedAt, center: center)
    }

    /// Sets any slot the chain is missing. Answers the seconds until its
    /// next slot, or nil when it has none or may no longer stand, in which
    /// case it is cancelled.
    @discardableResult
    static func topUp(
        incidentId: String,
        now: Date = Date(),
        center: UNUserNotificationCenter? = .current()
    ) async -> Int? {
        guard let record = IncidentChainStore.read(incidentId: incidentId) else { return nil }
        let pending = PendingIncidentStore.read(incidentId: incidentId)
        guard ChainRule.mayStand(
            record,
            incidentId: incidentId,
            criticalOn: TopicTimers.criticalOn(topic: record.topic),
            ackedLocally: AckedIncidentStore.contains(incidentId: incidentId),
            // A desk chain was checked when "I'm up" set it. Ending the card
            // may have dropped the incident's entry since.
            serverRang: record.kind == .desk || pending?.ringUntil != nil,
            now: now
        ) else {
            await cancel(incidentId: incidentId, scope: .all, center: center)
            return nil
        }
        return await fill(incidentId: incidentId, record: record, now: now, center: center)
    }

    /// Removes [incidentId]'s chain, all of it or only the ring chain.
    /// Safe to call when there is none.
    static func cancel(
        incidentId: String,
        scope: ChainRule.CancelScope = .all,
        center: UNUserNotificationCenter? = .current()
    ) async {
        guard let record = IncidentChainStore.read(incidentId: incidentId),
              ChainRule.cancels(record.kind, scope: scope)
        else { return }
        IncidentChainStore.clear(incidentId: incidentId)
        await removeSlots(incidentId: incidentId, record: record, center: center)
        NSLog(
            "CritAlarmAlarm: chain_cancelled kind=%@ incident_id=%@",
            record.kind.rawValue, incidentId
        )
    }

    /// Every chain on the phone. Sign-out, reset and the developer screen.
    static func cancelAll(center: UNUserNotificationCenter? = .current()) async {
        for incidentId in IncidentChainStore.all().keys {
            await cancel(incidentId: incidentId, scope: .all, center: center)
        }
        guard let center else { return }
        let left = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { ChainRule.incidentId(ofNotification: $0) != nil }
        if !left.isEmpty { center.removePendingNotificationRequests(withIdentifiers: left) }
    }

    /// Drops every chain whose incident is not active any more. With
    /// [topUp] (app start) it also tops up the rest and removes chain
    /// notifications nothing owns, which heals a leaked slot. Without it
    /// (the cached topics changed) it only drops, and sets nothing.
    static func sweep(
        now: Date = Date(),
        topUp: Bool = true,
        center: UNUserNotificationCenter? = .current()
    ) async {
        let records = IncidentChainStore.all()
        if records.isEmpty && !topUp { return }
        let pendingIds = Set(PendingIncidentStore.all().keys)
        let stale = ChainRule.staleChains(
            records,
            now: now,
            stillHeld: { pendingIds.contains($0) },
            criticalOn: { TopicTimers.criticalOn(topic: $0) },
            ackedLocally: { AckedIncidentStore.contains(incidentId: $0) },
            topicKnown: { TopicTimers.read(topic: $0) != nil }
        )
        for incidentId in stale {
            NSLog("CritAlarmAlarm: chain_swept incident_id=%@", incidentId)
            await cancel(incidentId: incidentId, scope: .all, center: center)
        }
        guard topUp else { return }
        for incidentId in records.keys.sorted() where !stale.contains(incidentId) {
            await self.topUp(incidentId: incidentId, now: now, center: center)
        }
        guard let center else { return }
        let orphans = ChainRule.orphanNotifications(
            await center.pendingNotificationRequests().map(\.identifier),
            chains: Set(IncidentChainStore.all().keys)
        )
        if !orphans.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: orphans)
            NSLog("CritAlarmAlarm: chain_orphans_removed count=%d", orphans.count)
        }
    }

    // MARK: - Platform calls

    /// What a topic is created with (api.md §3.1), for a topic this phone
    /// has not cached.
    static let defaultDeskTimerS = 600
    static let defaultMaxRingS = 1800

    /// Sets the missing slots of [record] and answers the seconds until the
    /// next slot that is set.
    private static func fill(
        incidentId: String,
        record: ChainRule.Record,
        now: Date,
        center: UNUserNotificationCenter?
    ) async -> Int? {
        let quietHours = QuietHours.read(from: QuietHours.groupDefaults)
        let held: (Date) -> Bool = {
            quietHours.holdsRing(
                minuteOfDay: QuietHours.minuteOf($0),
                priority: QuietHours.criticalPriority
            )
        }
        let pending = PendingIncidentStore.read(incidentId: incidentId)
        var set: [ChainRule.Slot] = []
        var added = 0

        #if canImport(AlarmKit)
        if #available(iOS 26.0, *), usesAlarmKit {
            let wanted = ChainRule.wanted(record, now: now, cap: ChainRule.alarmKitWindow, held: held)
            let present = Set((try? AlarmManager.shared.alarms)?.map(\.id) ?? [])
            let heldIndexes = Set(wanted.filter {
                present.contains(ChainRule.alarmId(incidentId: incidentId, kind: record.kind, index: $0.index))
            }.map(\.index))
            set = wanted.filter { heldIndexes.contains($0.index) }
            for slot in ChainRule.missing(wanted, heldIndexes: heldIndexes) {
                do {
                    try await scheduleAlarmSlot(
                        incidentId: incidentId, kind: record.kind, slot: slot, pending: pending
                    )
                    set.append(slot)
                    added += 1
                } catch AlarmManager.AlarmError.maximumLimitReached {
                    // Keep what fits. Stop, a push and the next launch top up.
                    NSLog(
                        "CritAlarmAlarm: chain_limit_reached incident_id=%@ held=%d",
                        incidentId, set.count
                    )
                    break
                } catch {
                    NSLog(
                        "CritAlarmAlarm: chain_slot_failed incident_id=%@ index=%d error=%@",
                        incidentId, slot.index, "\(error)"
                    )
                    break
                }
            }
            return finish(incidentId: incidentId, record: record, set: set, added: added, now: now)
        }
        #endif

        guard let center else { return nil }
        let requests = await center.pendingNotificationRequests().map(\.identifier)
        let others = requests.filter {
            guard let owner = ChainRule.incidentId(ofNotification: $0) else { return false }
            return owner != incidentId
        }.count
        let wanted = ChainRule.wanted(
            record,
            now: now,
            cap: ChainRule.notificationRoom(heldByOtherChains: others),
            held: held
        )
        let mine = Set(requests)
        let heldIndexes = Set(wanted.filter {
            mine.contains(ChainRule.notificationId(incidentId: incidentId, kind: record.kind, index: $0.index))
        }.map(\.index))
        set = wanted.filter { heldIndexes.contains($0.index) }
        for slot in ChainRule.missing(wanted, heldIndexes: heldIndexes) {
            do {
                try await center.add(notificationSlot(
                    incidentId: incidentId, kind: record.kind, slot: slot, pending: pending, now: now
                ))
                set.append(slot)
                added += 1
            } catch {
                NSLog(
                    "CritAlarmAlarm: chain_slot_failed incident_id=%@ index=%d error=%@",
                    incidentId, slot.index, "\(error)"
                )
                break
            }
        }
        return finish(incidentId: incidentId, record: record, set: set, added: added, now: now)
    }

    private static func finish(
        incidentId: String,
        record: ChainRule.Record,
        set: [ChainRule.Slot],
        added: Int,
        now: Date
    ) -> Int? {
        guard let next = set.map(\.at).min() else {
            NSLog("CritAlarmAlarm: chain_empty kind=%@ incident_id=%@", record.kind.rawValue, incidentId)
            return nil
        }
        IncidentRearm.remember(incidentId: incidentId, firesAt: next)
        let seconds = Int(next.timeIntervalSince(now).rounded())
        NSLog(
            "CritAlarmAlarm: chain_set kind=%@ incident_id=%@ held=%d added=%d next_in_s=%d",
            record.kind.rawValue, incidentId, set.count, added, seconds
        )
        return seconds
    }

    #if canImport(AlarmKit)
    @available(iOS 26.0, *)
    private static func scheduleAlarmSlot(
        incidentId: String,
        kind: ChainRule.Kind,
        slot: ChainRule.Slot,
        pending: PendingIncidentStore.Entry?
    ) async throws {
        let attributes = IncidentAlarmScheduler.alarmAttributes(
            incidentId: incidentId,
            topic: pending?.topic ?? "",
            server: pending?.server ?? "",
            title: pending?.title ?? "Crit Alarm"
        )
        let sound = OwnSoundLock.alarmSound(
            requested: pending?.sound,
            ownLocked: OwnSoundLock.isLocked(in: OwnSoundLock.groupDefaults),
            bundled: IncidentAlarmScheduler.soundName
        )
        // A fixed date, not a countdown: a countdown shows a card for every
        // slot, and the chain holds dozens.
        let configuration = AlarmManager.AlarmConfiguration.alarm(
            schedule: .fixed(slot.at),
            attributes: attributes,
            stopIntent: StopAlarmIntent(incidentId: incidentId),
            secondaryIntent: OpenIncidentIntent(incidentId: incidentId),
            sound: .named(sound)
        )
        _ = try await AlarmManager.shared.schedule(
            id: ChainRule.alarmId(incidentId: incidentId, kind: kind, index: slot.index),
            configuration: configuration
        )
    }
    #endif

    private static func notificationSlot(
        incidentId: String,
        kind: ChainRule.Kind,
        slot: ChainRule.Slot,
        pending: PendingIncidentStore.Entry?,
        now: Date
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = pending?.title ?? "Crit Alarm"
        content.body = NativeL10n.text(.alarmStillRinging)
        content.sound = UNNotificationSound(named: UNNotificationSoundName(
            OwnSoundLock.alarmSound(
                requested: pending?.sound,
                ownLocked: OwnSoundLock.isLocked(in: OwnSoundLock.groupDefaults),
                bundled: IncidentAlarmScheduler.soundName
            )
        ))
        content.categoryIdentifier = IncidentRearm.category
        content.userInfo = ["incident_id": incidentId]
        if #available(iOS 15.0, *) { content.interruptionLevel = .timeSensitive }
        return UNNotificationRequest(
            identifier: ChainRule.notificationId(incidentId: incidentId, kind: kind, index: slot.index),
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: max(slot.at.timeIntervalSince(now), 1),
                repeats: false
            )
        )
    }

    private static func removeSlots(
        incidentId: String,
        record: ChainRule.Record,
        center: UNUserNotificationCenter?
    ) async {
        if let center {
            let prefix = ChainRule.notificationPrefix + "\(incidentId)#\(record.kind.rawValue)#"
            let ids = await center.pendingNotificationRequests()
                .map(\.identifier)
                .filter { $0.hasPrefix(prefix) }
            if !ids.isEmpty { center.removePendingNotificationRequests(withIdentifiers: ids) }
        }
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            let present = Set((try? AlarmManager.shared.alarms)?.map(\.id) ?? [])
            for index in 0..<ChainRule.slotCount(record) {
                let id = ChainRule.alarmId(incidentId: incidentId, kind: record.kind, index: index)
                if present.contains(id) { try? AlarmManager.shared.cancel(id: id) }
            }
        }
        #endif
    }
}
