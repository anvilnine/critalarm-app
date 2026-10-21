import CryptoKit
import Foundation

/// The phone's own rings for one incident, worked out with nothing read.
///
/// On the first ring of an incident the phone sets every later ring itself,
/// one `repeat_interval_s` apart, up to `ring_until`. The system holds them,
/// so the phone keeps ringing with no network and with the app force-quit.
/// After "I'm up" a second chain covers the desk timer: it starts when the
/// desk timer runs out and lasts one `max_ring_s`. Only "I'm up" ends the
/// first chain, and only "At my desk" (or the challenge) ends the second.
///
/// Everything here is a pure answer. `IncidentChain` reads the inputs and
/// makes the platform calls.
enum ChainRule {
    /// Which of the two chains a record holds.
    enum Kind: String, Codable {
        /// From the first ring to `ring_until`. Ends on "I'm up".
        case ring
        /// From the end of the desk timer for one `max_ring_s`. Ends on
        /// "At my desk" or the wake-up challenge.
        case desk
    }

    /// One ring in a chain. [index] counts from the chain's first ring, so
    /// the same ring always gets the same id however often the chain is
    /// topped up.
    struct Slot: Equatable {
        let index: Int
        let at: Date
    }

    /// What the phone remembers about a chain it set. Kept in the app group,
    /// so the Stop and "I'm up" intents can reach it from any process.
    struct Record: Equatable, Codable {
        let kind: Kind
        /// When slot 0 rings.
        let firstAt: Date
        let repeatIntervalS: Int
        /// No slot rings at or after this.
        let end: Date
        let topic: String
        /// Whether the topic was in the cached topic list when the chain
        /// was set. A topic that was known and is gone now was deleted.
        let topicKnown: Bool
    }

    /// How many alarms one chain keeps set at a time on iOS 26 and later.
    /// AlarmKit has a limit (`AlarmError.maximumLimitReached`) and Apple
    /// does not say what it is. A chain that hits it keeps what it got, and
    /// Stop, a push and the next launch each top it up.
    static let alarmKitWindow = 60

    /// Pending notifications every chain may hold together below iOS 26.
    /// iOS keeps 64 per app, shared with the reminders.
    static let notificationCap = 40

    /// Prefix of every chain notification's identifier.
    static let notificationPrefix = "critalarm.chain."

    /// The longest chain ever walked, so a far `ring_until` costs nothing.
    static let maxSlots = 10_000

    // MARK: - Times

    /// Every ring from [now] to [ringUntil], one interval apart, the first
    /// one interval from now. Empty with no `ring_until`, which is the
    /// onboarding demo and nothing else.
    static func chainTimes(
        now: Date,
        repeatIntervalS: Int,
        ringUntil: Date?,
        cap: Int = alarmKitWindow
    ) -> [Date] {
        guard let ringUntil else { return [] }
        let seconds = interval(repeatIntervalS)
        return slots(
            firstAt: now.addingTimeInterval(TimeInterval(seconds)),
            repeatIntervalS: seconds,
            end: ringUntil,
            after: now,
            cap: cap
        ).map(\.at)
    }

    /// The slots of a chain that still lie ahead: after [after], before
    /// [end], none that quiet hours hold, at most [cap] of them.
    static func slots(
        firstAt: Date,
        repeatIntervalS: Int,
        end: Date,
        after: Date,
        cap: Int,
        held: (Date) -> Bool = { _ in false }
    ) -> [Slot] {
        guard cap > 0 else { return [] }
        let seconds = TimeInterval(interval(repeatIntervalS))
        var start = 0
        if after > firstAt {
            start = Int((after.timeIntervalSince(firstAt) / seconds).rounded(.down))
        }
        var found: [Slot] = []
        var index = start
        while index < maxSlots, found.count < cap {
            let at = firstAt.addingTimeInterval(TimeInterval(index) * seconds)
            if at >= end { break }
            if at > after, !held(at) { found.append(Slot(index: index, at: at)) }
            index += 1
        }
        return found
    }

    /// The ring chain a push or a Stop sets. Slot 0 rings one interval
    /// after [anchor], plus [offsetS].
    static func ringRecord(
        anchor: Date,
        offsetS: Int,
        repeatIntervalS: Int,
        ringUntil: Date,
        topic: String,
        topicKnown: Bool
    ) -> Record {
        let seconds = interval(repeatIntervalS)
        return Record(
            kind: .ring,
            firstAt: anchor.addingTimeInterval(TimeInterval(seconds + max(0, offsetS))),
            repeatIntervalS: seconds,
            end: ringUntil,
            topic: topic,
            topicKnown: topicKnown
        )
    }

    /// The desk timer chain "I'm up" sets: from the end of the desk timer,
    /// for as long as a reopened incident would ring.
    static func deskRecord(
        ackedAt: Date,
        deskTimerS: Int,
        maxRingS: Int,
        repeatIntervalS: Int,
        topic: String,
        topicKnown: Bool
    ) -> Record {
        let start = ackedAt.addingTimeInterval(TimeInterval(max(1, deskTimerS)))
        return Record(
            kind: .desk,
            firstAt: start,
            repeatIntervalS: interval(repeatIntervalS),
            end: start.addingTimeInterval(TimeInterval(max(1, maxRingS))),
            topic: topic,
            topicKnown: topicKnown
        )
    }

    /// The slots [record] should hold now.
    static func wanted(
        _ record: Record,
        now: Date,
        cap: Int,
        held: (Date) -> Bool = { _ in false }
    ) -> [Slot] {
        slots(
            firstAt: record.firstAt,
            repeatIntervalS: record.repeatIntervalS,
            end: record.end,
            after: now,
            cap: cap,
            held: held
        )
    }

    /// The wanted slots the system does not hold yet. A top-up sets these
    /// and nothing else, so a chain is never doubled.
    static func missing(_ wanted: [Slot], heldIndexes: Set<Int>) -> [Slot] {
        wanted.filter { !heldIndexes.contains($0.index) }
    }

    /// Room left for one chain's notifications below iOS 26.
    static func notificationRoom(heldByOtherChains: Int, cap: Int = notificationCap) -> Int {
        max(0, cap - heldByOtherChains)
    }

    private static func interval(_ seconds: Int) -> Int {
        seconds > 0 ? seconds : RearmRule.defaultRepeatIntervalS
    }

    // MARK: - Ids

    /// The same incident, chain and slot always answer the same key.
    static func slotKey(incidentId: String, kind: Kind, index: Int) -> String {
        "\(incidentId)#\(kind.rawValue)#\(index)"
    }

    /// The identifier of a slot's notification below iOS 26.
    static func notificationId(incidentId: String, kind: Kind, index: Int) -> String {
        notificationPrefix + slotKey(incidentId: incidentId, kind: kind, index: index)
    }

    /// The incident a chain notification belongs to, or nil for any other
    /// notification.
    static func incidentId(ofNotification identifier: String) -> String? {
        guard identifier.hasPrefix(notificationPrefix) else { return nil }
        let key = identifier.dropFirst(notificationPrefix.count)
        let parts = key.split(separator: "#", omittingEmptySubsequences: false)
        guard parts.count >= 3, let last = parts.last, Int(last) != nil else { return nil }
        let id = parts.dropLast(2).joined(separator: "#")
        return id.isEmpty ? nil : id
    }

    /// The AlarmKit id of a slot. Derived from the slot key the same way
    /// the push alarm's id is derived from the incident id, so no table is
    /// needed to find or cancel it.
    static func alarmId(incidentId: String, kind: Kind, index: Int) -> UUID {
        uuid(from: slotKey(incidentId: incidentId, kind: kind, index: index))
    }

    /// A version-4 UUID from the first 16 bytes of the key's SHA-256. Same
    /// as `IncidentAlarmScheduler.alarmId(for:)`.
    static func uuid(from key: String) -> UUID {
        var digest = Array(SHA256.hash(data: Data(key.utf8)).prefix(16))
        digest[6] = (digest[6] & 0x0F) | 0x40
        digest[8] = (digest[8] & 0x3F) | 0x80
        return UUID(uuid: (
            digest[0], digest[1], digest[2], digest[3],
            digest[4], digest[5], digest[6], digest[7],
            digest[8], digest[9], digest[10], digest[11],
            digest[12], digest[13], digest[14], digest[15]
        ))
    }

    // MARK: - When a chain may stand

    /// Whether [record] may keep ringing. Each slot also passes quiet hours
    /// on its own, so this does not ask about them.
    ///
    /// - The ring chain follows `RearmRule`: a real incident, Critical on,
    ///   not acknowledged here, before `ring_until`.
    /// - The desk chain stands although the incident is acknowledged, which
    ///   is what it is for. It still needs Critical on, an incident a
    ///   server alarm push brought, and its end not passed.
    static func mayStand(
        _ record: Record,
        incidentId: String,
        criticalOn: Bool,
        ackedLocally: Bool,
        serverRang: Bool,
        now: Date
    ) -> Bool {
        if incidentId.isEmpty || !criticalOn || !serverRang { return false }
        if now >= record.end { return false }
        switch record.kind {
        case .ring: return !ackedLocally
        case .desk: return true
        }
    }

    /// Whether the start sweep (or a topic change) drops [record]. Adds to
    /// [mayStand]: the phone no longer holds the incident of a ring chain
    /// (closed or ended here), or the topic was deleted.
    static func isStale(
        _ record: Record,
        incidentId: String,
        stillHeld: Bool,
        criticalOn: Bool,
        ackedLocally: Bool,
        topicKnownNow: Bool,
        now: Date
    ) -> Bool {
        staleReason(
            record, incidentId: incidentId, stillHeld: stillHeld, criticalOn: criticalOn,
            ackedLocally: ackedLocally, topicKnownNow: topicKnownNow, now: now
        ) != nil
    }

    /// The incidents whose chains the start sweep drops, sorted.
    static func staleChains(
        _ records: [String: Record],
        now: Date,
        stillHeld: (String) -> Bool,
        criticalOn: (String) -> Bool,
        ackedLocally: (String) -> Bool,
        topicKnown: (String) -> Bool
    ) -> [String] {
        records.filter { incidentId, record in
            isStale(
                record,
                incidentId: incidentId,
                stillHeld: stillHeld(incidentId),
                criticalOn: criticalOn(record.topic),
                ackedLocally: ackedLocally(incidentId),
                topicKnownNow: topicKnown(record.topic),
                now: now
            )
        }.keys.sorted()
    }

    /// Chain notifications whose incident has no chain any more: a slot
    /// that leaked past its cancel. Any other notification is left alone.
    static func orphanNotifications(_ identifiers: [String], chains: Set<String>) -> [String] {
        identifiers.filter { identifier in
            guard let owner = incidentId(ofNotification: identifier) else { return false }
            return !chains.contains(owner)
        }
    }

    /// How many slot indexes a chain can have, so a cancel can find every
    /// alarm it may have set.
    static func slotCount(_ record: Record) -> Int {
        let span = record.end.timeIntervalSince(record.firstAt)
        guard span > 0 else { return 0 }
        let count = Int((span / TimeInterval(interval(record.repeatIntervalS))).rounded(.up))
        return min(maxSlots, count)
    }

    // MARK: - Cancel

    /// How much of an incident's chains a cancel removes.
    enum CancelScope {
        /// Everything: "At my desk", the challenge, a close or an expiry
        /// from anywhere, Critical off, the topic deleted, sign-out, reset.
        case all
        /// The ring chain only: "I'm up" here, or the server saying the
        /// incident is acknowledged. A desk chain this phone set stays.
        case ringOnly
    }

    /// Every way a chain is cancelled, so each has one answer.
    enum CancelPath: String, CaseIterable {
        /// "I'm up" on this phone: the alarm, the card or the app.
        case imUp
        /// The ack queue reached the server, often long after "I'm up".
        case ackSent
        /// The server says acknowledged: another phone, or this one heard
        /// back. A desk chain only this phone's "I'm up" sets stays.
        case remoteAcked
        /// "At my desk" on the card, or a close in the app, which is also
        /// where a passed wake-up challenge closes.
        case atMyDesk
        /// Closed or expired, heard from the server or another device.
        case ended
        /// `ring_until` (or the desk chain's end) passed.
        case ringUntilPassed
        /// Critical switched off on the topic.
        case criticalOff
        /// The topic is gone from the cached list.
        case topicDeleted
        /// Sign-out, account delete, reset or disconnect.
        case signOutOrReset
        /// The start sweep found the incident no longer active.
        case staleAtStart
    }

    static func scope(for path: CancelPath) -> CancelScope {
        switch path {
        case .imUp, .ackSent, .remoteAcked:
            return .ringOnly
        case .atMyDesk, .ended, .ringUntilPassed, .criticalOff, .topicDeleted,
             .signOutOrReset, .staleAtStart:
            return .all
        }
    }

    /// Why the sweep drops [record], or nil when it stands.
    static func staleReason(
        _ record: Record,
        incidentId: String,
        stillHeld: Bool,
        criticalOn: Bool,
        ackedLocally: Bool,
        topicKnownNow: Bool,
        now: Date
    ) -> CancelPath? {
        // The app ends the card of an incident acknowledged in the app, and
        // that drops the incident's entry, so only a ring chain needs one.
        // A desk chain ends on its own cancel paths and its end time.
        if !stillHeld && record.kind == .ring { return .ended }
        if record.topicKnown && !topicKnownNow { return .topicDeleted }
        if !criticalOn { return .criticalOff }
        if now >= record.end { return .ringUntilPassed }
        if record.kind == .ring && ackedLocally { return .imUp }
        if incidentId.isEmpty { return .staleAtStart }
        return nil
    }

    static func cancels(_ kind: Kind, scope: CancelScope) -> Bool {
        switch scope {
        case .all: return true
        case .ringOnly: return kind == .ring
        }
    }

    // MARK: - Pushes

    /// What a push that rings does with the chain.
    enum ChainStep: Equatable {
        /// Nothing: the push does not ring.
        case none
        /// Keep the chain and set any slot it is missing.
        case topUp
        /// Replace the chain with one anchored at the push, slot 0 one
        /// interval plus [offsetS] later. Never added to the old one.
        case reset(offsetS: Int)
    }

    struct PushPlan: Equatable {
        /// Whether the push sets its own alarm a few seconds out.
        let setsOwnAlarm: Bool
        let chain: ChainStep
    }

    /// One push, one plan.
    ///
    /// - An open or a reopen starts a stage, so its chain starts again.
    /// - With AlarmKit, a repeat on a chain that is set rings through the
    ///   chain's own slot, which is due at about the same second. Setting
    ///   the push's alarm as well would ring twice.
    /// - Below iOS 26 the push is its own notification and always sounds.
    ///   Each one moves the chain to half an interval after the next
    ///   expected push, so while pushes arrive no slot is ever reached, and
    ///   once they stop the phone rings on its own.
    static func pushPlan(
        kind: IncidentPush.Kind,
        ringChainHeld: Bool,
        alarmKit: Bool,
        repeatIntervalS: Int
    ) -> PushPlan {
        guard RearmRule.ringingKinds.contains(kind) else {
            return PushPlan(setsOwnAlarm: true, chain: .none)
        }
        let offset = alarmKit ? 0 : interval(repeatIntervalS) / 2
        if alarmKit, kind == .repeat, ringChainHeld {
            return PushPlan(setsOwnAlarm: false, chain: .topUp)
        }
        return PushPlan(setsOwnAlarm: true, chain: .reset(offsetS: offset))
    }
}
