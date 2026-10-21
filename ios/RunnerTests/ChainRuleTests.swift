import XCTest

@testable import Runner

final class ChainRuleTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_757_462_400)

    private func ringRecord(
        anchor: Date? = nil,
        offsetS: Int = 0,
        minutes: Double = 30,
        topicKnown: Bool = true
    ) -> ChainRule.Record {
        let anchor = anchor ?? now
        return ChainRule.ringRecord(
            anchor: anchor,
            offsetS: offsetS,
            repeatIntervalS: 30,
            ringUntil: anchor.addingTimeInterval(minutes * 60),
            topic: "prod",
            topicKnown: topicKnown
        )
    }

    private func deskRecord(ackedAt: Date? = nil) -> ChainRule.Record {
        ChainRule.deskRecord(
            ackedAt: ackedAt ?? now,
            deskTimerS: 600,
            maxRingS: 1800,
            repeatIntervalS: 30,
            topic: "prod",
            topicKnown: true
        )
    }

    // MARK: - chainTimes

    func testDefaultsGiveOneRingEveryThirtySecondsForThirtyMinutes() {
        let times = ChainRule.chainTimes(
            now: now, repeatIntervalS: 30, ringUntil: now.addingTimeInterval(1800)
        )
        // 30 s to 1770 s: the ring at 1800 s would be at ring_until itself.
        XCTAssertEqual(times.count, 59)
        XCTAssertEqual(times.first, now.addingTimeInterval(30))
        XCTAssertEqual(times.last, now.addingTimeInterval(1770))
        for (earlier, later) in zip(times, times.dropFirst()) {
            XCTAssertEqual(later.timeIntervalSince(earlier), 30)
        }
    }

    func testWindowShorterThanOneIntervalGivesNothing() {
        XCTAssertEqual(
            ChainRule.chainTimes(now: now, repeatIntervalS: 30, ringUntil: now.addingTimeInterval(20)),
            []
        )
    }

    func testRingUntilAlreadyPastGivesNothing() {
        XCTAssertEqual(
            ChainRule.chainTimes(now: now, repeatIntervalS: 30, ringUntil: now.addingTimeInterval(-5)),
            []
        )
    }

    func testNoRingUntilGivesNothing() {
        XCTAssertEqual(ChainRule.chainTimes(now: now, repeatIntervalS: 30, ringUntil: nil), [])
    }

    func testCustomInterval() {
        let times = ChainRule.chainTimes(
            now: now, repeatIntervalS: 120, ringUntil: now.addingTimeInterval(600)
        )
        XCTAssertEqual(times, [120, 240, 360, 480].map { now.addingTimeInterval($0) })
    }

    func testZeroIntervalFallsBackToTheDefault() {
        let times = ChainRule.chainTimes(
            now: now, repeatIntervalS: 0, ringUntil: now.addingTimeInterval(100)
        )
        XCTAssertEqual(times, [30, 60, 90].map { now.addingTimeInterval($0) })
    }

    func testCapStopsTheChain() {
        let times = ChainRule.chainTimes(
            now: now, repeatIntervalS: 30, ringUntil: now.addingTimeInterval(86_400), cap: 60
        )
        XCTAssertEqual(times.count, 60)
    }

    // MARK: - Slots and top-up

    func testSlotIndexesStayPutAsTimeMoves() {
        let record = ringRecord()
        let first = ChainRule.wanted(record, now: now, cap: 3)
        XCTAssertEqual(first.map(\.index), [0, 1, 2])
        // 95 s on, the slots at 30, 60 and 90 s are behind us.
        let later = ChainRule.wanted(record, now: now.addingTimeInterval(95), cap: 3)
        XCTAssertEqual(later.map(\.index), [3, 4, 5])
        XCTAssertEqual(later.first?.at, now.addingTimeInterval(120))
    }

    func testTopUpAddsOnlyWhatIsMissingAndNeverDoubles() {
        let wanted = ChainRule.wanted(ringRecord(), now: now, cap: 5)
        let missing = ChainRule.missing(wanted, heldIndexes: [0, 1, 3])
        XCTAssertEqual(missing.map(\.index), [2, 4])
        XCTAssertEqual(ChainRule.missing(wanted, heldIndexes: Set(0..<5)), [])
    }

    func testQuietHoursDropSlotsInsideTheWindowAndKeepTheRest() {
        let record = ringRecord(minutes: 3)
        let quietStart = now.addingTimeInterval(60)
        let quietEnd = now.addingTimeInterval(120)
        let slots = ChainRule.wanted(record, now: now, cap: 10) { at in
            at >= quietStart && at < quietEnd
        }
        XCTAssertEqual(slots.map(\.index), [0, 3, 4])
    }

    func testOffsetPutsTheFirstSlotHalfAnIntervalLater() {
        let record = ringRecord(offsetS: 15)
        XCTAssertEqual(ChainRule.wanted(record, now: now, cap: 1).first?.at, now.addingTimeInterval(45))
    }

    func testDeskChainStartsWhenTheDeskTimerEndsAndLastsOneRing() {
        let record = deskRecord()
        XCTAssertEqual(record.kind, .desk)
        let slots = ChainRule.wanted(record, now: now, cap: ChainRule.maxSlots)
        XCTAssertEqual(slots.first?.at, now.addingTimeInterval(600))
        XCTAssertEqual(slots.last?.at, now.addingTimeInterval(600 + 1770))
        XCTAssertEqual(slots.count, 60)
    }

    // MARK: - The 40 cap below iOS 26

    func testNotificationChainIsCappedAtForty() {
        XCTAssertEqual(ChainRule.notificationCap, 40)
        let room = ChainRule.notificationRoom(heldByOtherChains: 0)
        XCTAssertEqual(ChainRule.wanted(ringRecord(), now: now, cap: room).count, 40)
    }

    func testOtherChainsShareTheForty() {
        XCTAssertEqual(ChainRule.notificationRoom(heldByOtherChains: 25), 15)
        XCTAssertEqual(ChainRule.notificationRoom(heldByOtherChains: 40), 0)
        XCTAssertEqual(ChainRule.notificationRoom(heldByOtherChains: 55), 0)
        XCTAssertEqual(ChainRule.wanted(ringRecord(), now: now, cap: 0), [])
    }

    // MARK: - Ids

    func testSameInputSameId() {
        XCTAssertEqual(
            ChainRule.alarmId(incidentId: "inc_9a8b7c", kind: .ring, index: 4),
            ChainRule.alarmId(incidentId: "inc_9a8b7c", kind: .ring, index: 4)
        )
        XCTAssertEqual(
            ChainRule.notificationId(incidentId: "inc_9a8b7c", kind: .desk, index: 2),
            "critalarm.chain.inc_9a8b7c#desk#2"
        )
    }

    func testIdsDifferBySlotKindAndIncident() {
        let ids: Set<UUID> = [
            ChainRule.alarmId(incidentId: "inc_a", kind: .ring, index: 0),
            ChainRule.alarmId(incidentId: "inc_a", kind: .ring, index: 1),
            ChainRule.alarmId(incidentId: "inc_a", kind: .desk, index: 0),
            ChainRule.alarmId(incidentId: "inc_b", kind: .ring, index: 0),
            IncidentAlarmScheduler.alarmId(for: "inc_a"),
        ]
        XCTAssertEqual(ids.count, 5)
    }

    func testSlotIdsAreVersionFourUuids() {
        let id = ChainRule.alarmId(incidentId: "inc_a", kind: .ring, index: 7).uuidString
        let characters = Array(id)
        XCTAssertEqual(characters[14], "4")
        XCTAssertTrue("89AB".contains(characters[19]))
    }

    func testIdDerivationMatchesThePushAlarm() {
        XCTAssertEqual(ChainRule.uuid(from: "inc_a"), IncidentAlarmScheduler.alarmId(for: "inc_a"))
    }

    func testNotificationIdReadsBackItsIncident() {
        let id = ChainRule.notificationId(incidentId: "inc_9a8b7c", kind: .ring, index: 12)
        XCTAssertEqual(ChainRule.incidentId(ofNotification: id), "inc_9a8b7c")
        XCTAssertNil(ChainRule.incidentId(ofNotification: "inc_9a8b7c"))
        XCTAssertNil(ChainRule.incidentId(ofNotification: "reminder.weekly"))
        XCTAssertNil(ChainRule.incidentId(ofNotification: "critalarm.chain.#ring#1"))
    }

    // MARK: - Cancel paths

    func testEveryCancelPathHasItsScope() {
        let ringOnly: Set<ChainRule.CancelPath> = [.imUp, .ackSent, .remoteAcked]
        for path in ChainRule.CancelPath.allCases {
            let scope = ChainRule.scope(for: path)
            if ringOnly.contains(path) {
                XCTAssertEqual(scope, .ringOnly, path.rawValue)
            } else {
                XCTAssertEqual(scope, .all, path.rawValue)
            }
        }
    }

    func testEveryCancelPathRemovesTheRingChain() {
        for path in ChainRule.CancelPath.allCases {
            XCTAssertTrue(ChainRule.cancels(.ring, scope: ChainRule.scope(for: path)), path.rawValue)
        }
    }

    func testOnlyTheAcknowledgePathsKeepTheDeskChain() {
        let kept = ChainRule.CancelPath.allCases.filter {
            !ChainRule.cancels(.desk, scope: ChainRule.scope(for: $0))
        }
        XCTAssertEqual(Set(kept), [.imUp, .ackSent, .remoteAcked])
    }

    func testCancelFindsEverySlotIndex() {
        XCTAssertEqual(ChainRule.slotCount(ringRecord()), 59)
        XCTAssertEqual(ChainRule.slotCount(deskRecord()), 60)
        let empty = ringRecord(minutes: 0)
        XCTAssertEqual(ChainRule.slotCount(empty), 0)
    }

    // MARK: - May a chain stand

    func testRingChainStopsOnImUpAndAtRingUntil() {
        let record = ringRecord()
        func stands(acked: Bool = false, critical: Bool = true, at: Date? = nil) -> Bool {
            ChainRule.mayStand(
                record, incidentId: "inc_a", criticalOn: critical, ackedLocally: acked,
                serverRang: true, now: at ?? now
            )
        }
        XCTAssertTrue(stands())
        XCTAssertFalse(stands(acked: true))
        XCTAssertFalse(stands(critical: false))
        XCTAssertFalse(stands(at: now.addingTimeInterval(1800)))
    }

    func testDeskChainStandsWhileAcknowledged() {
        let record = deskRecord()
        XCTAssertTrue(ChainRule.mayStand(
            record, incidentId: "inc_a", criticalOn: true, ackedLocally: true,
            serverRang: true, now: now
        ))
        XCTAssertFalse(ChainRule.mayStand(
            record, incidentId: "inc_a", criticalOn: false, ackedLocally: true,
            serverRang: true, now: now
        ))
        XCTAssertFalse(ChainRule.mayStand(
            record, incidentId: "inc_demo", criticalOn: true, ackedLocally: true,
            serverRang: false, now: now
        ))
    }

    // MARK: - Start sweep

    func testStartSweepRemovesChainsOfInactiveIncidents() {
        let records: [String: ChainRule.Record] = [
            "inc_live": ringRecord(),
            "inc_closed": ringRecord(),
            "inc_acked": ringRecord(),
            "inc_desk": deskRecord(),
            "inc_past": ringRecord(anchor: now.addingTimeInterval(-3600)),
            "inc_off": ChainRule.ringRecord(
                anchor: now, offsetS: 0, repeatIntervalS: 30,
                ringUntil: now.addingTimeInterval(1800), topic: "staging", topicKnown: true
            ),
            "inc_deleted": ChainRule.ringRecord(
                anchor: now, offsetS: 0, repeatIntervalS: 30,
                ringUntil: now.addingTimeInterval(1800), topic: "gone", topicKnown: true
            ),
        ]
        let stale = ChainRule.staleChains(
            records,
            now: now,
            stillHeld: { $0 != "inc_closed" },
            criticalOn: { $0 != "staging" },
            ackedLocally: { $0 == "inc_acked" || $0 == "inc_desk" },
            topicKnown: { $0 != "gone" }
        )
        XCTAssertEqual(stale, ["inc_acked", "inc_closed", "inc_deleted", "inc_off", "inc_past"])
    }

    func testDeskChainOutlivesTheCardTheAppEnded() {
        XCTAssertFalse(ChainRule.isStale(
            deskRecord(), incidentId: "inc_a", stillHeld: false, criticalOn: true,
            ackedLocally: true, topicKnownNow: true, now: now
        ))
        XCTAssertTrue(ChainRule.isStale(
            deskRecord(), incidentId: "inc_a", stillHeld: false, criticalOn: true,
            ackedLocally: true, topicKnownNow: true, now: now.addingTimeInterval(600 + 1800)
        ))
    }

    func testSweepNamesWhy() {
        let record = ringRecord()
        func reason(
            held: Bool = true, critical: Bool = true, acked: Bool = false,
            known: Bool = true, at: Date? = nil
        ) -> ChainRule.CancelPath? {
            ChainRule.staleReason(
                record, incidentId: "inc_a", stillHeld: held, criticalOn: critical,
                ackedLocally: acked, topicKnownNow: known, now: at ?? now
            )
        }
        XCTAssertNil(reason())
        XCTAssertEqual(reason(held: false), .ended)
        XCTAssertEqual(reason(known: false), .topicDeleted)
        XCTAssertEqual(reason(critical: false), .criticalOff)
        XCTAssertEqual(reason(acked: true), .imUp)
        XCTAssertEqual(reason(at: now.addingTimeInterval(1800)), .ringUntilPassed)
    }

    func testTopicNeverListedIsNotADeletedTopic() {
        let record = ringRecord(topicKnown: false)
        XCTAssertFalse(ChainRule.isStale(
            record, incidentId: "inc_a", stillHeld: true, criticalOn: true,
            ackedLocally: false, topicKnownNow: false, now: now
        ))
    }

    func testOrphanNotificationsGoAndOthersStay() {
        let identifiers = [
            ChainRule.notificationId(incidentId: "inc_live", kind: .ring, index: 0),
            ChainRule.notificationId(incidentId: "inc_gone", kind: .ring, index: 3),
            ChainRule.notificationId(incidentId: "inc_gone", kind: .desk, index: 0),
            "inc_live",
            "reminder.weekly",
        ]
        XCTAssertEqual(
            ChainRule.orphanNotifications(identifiers, chains: ["inc_live"]),
            [
                ChainRule.notificationId(incidentId: "inc_gone", kind: .ring, index: 3),
                ChainRule.notificationId(incidentId: "inc_gone", kind: .desk, index: 0),
            ]
        )
    }

    // MARK: - Pushes

    func testOpenAndReopenAlwaysResetTheChain() {
        for kind in [IncidentPush.Kind.open, .reopen] {
            for held in [true, false] {
                XCTAssertEqual(
                    ChainRule.pushPlan(kind: kind, ringChainHeld: held, alarmKit: true, repeatIntervalS: 30),
                    .init(setsOwnAlarm: true, chain: .reset(offsetS: 0))
                )
            }
        }
    }

    func testRepeatOnAHeldChainRingsThroughTheChainWithAlarmKit() {
        XCTAssertEqual(
            ChainRule.pushPlan(kind: .repeat, ringChainHeld: true, alarmKit: true, repeatIntervalS: 30),
            .init(setsOwnAlarm: false, chain: .topUp)
        )
        XCTAssertEqual(
            ChainRule.pushPlan(kind: .repeat, ringChainHeld: false, alarmKit: true, repeatIntervalS: 30),
            .init(setsOwnAlarm: true, chain: .reset(offsetS: 0))
        )
    }

    func testBelowIOS26EveryRingingPushMovesTheChainHalfAnIntervalOn() {
        for kind in [IncidentPush.Kind.open, .repeat, .reopen] {
            XCTAssertEqual(
                ChainRule.pushPlan(kind: kind, ringChainHeld: true, alarmKit: false, repeatIntervalS: 30),
                .init(setsOwnAlarm: true, chain: .reset(offsetS: 15))
            )
        }
    }

    func testAPushThatDoesNotRingLeavesTheChain() {
        XCTAssertEqual(
            ChainRule.pushPlan(kind: .p4, ringChainHeld: true, alarmKit: true, repeatIntervalS: 30),
            .init(setsOwnAlarm: true, chain: .none)
        )
    }

    // MARK: - Store

    func testStoreRoundTripAndClear() throws {
        let suite = "ChainRuleTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let ring = ringRecord()
        let desk = deskRecord()
        IncidentChainStore.write(ring, incidentId: "inc_a", in: defaults)
        IncidentChainStore.write(desk, incidentId: "inc_b", in: defaults)
        XCTAssertEqual(IncidentChainStore.read(incidentId: "inc_a", in: defaults), ring)
        XCTAssertEqual(IncidentChainStore.all(in: defaults), ["inc_a": ring, "inc_b": desk])
        XCTAssertTrue(IncidentChainStore.holdsRing(incidentId: "inc_a", in: defaults))
        XCTAssertFalse(IncidentChainStore.holdsRing(incidentId: "inc_b", in: defaults))

        IncidentChainStore.clear(incidentId: "inc_a", in: defaults)
        XCTAssertNil(IncidentChainStore.read(incidentId: "inc_a", in: defaults))
        XCTAssertEqual(IncidentChainStore.all(in: defaults), ["inc_b": desk])
    }
}
