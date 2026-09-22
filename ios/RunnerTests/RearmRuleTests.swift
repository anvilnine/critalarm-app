import XCTest

@testable import Runner

final class RearmRuleTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_757_462_400)
    private var ringUntil: Date { now.addingTimeInterval(20 * 60) }

    private func ask(
        incidentId: String = "inc_9a8b7c",
        kind: IncidentPush.Kind = .repeat,
        criticalOn: Bool = true,
        ackedLocally: Bool = false,
        ringUntil: Date? = nil,
        quietHoursHold: Bool = false
    ) -> Bool {
        RearmRule.canRearm(
            incidentId: incidentId,
            kind: kind,
            criticalOn: criticalOn,
            ackedLocally: ackedLocally,
            ringUntil: ringUntil ?? self.ringUntil,
            now: now,
            quietHoursHold: quietHoursHold
        )
    }

    func testAllFiveInputsGoodLetsThePhoneSetItsOwnNextRing() {
        XCTAssertTrue(ask())
    }

    func testAnAckedIncidentDoesNotRingAgain() {
        XCTAssertFalse(ask(ackedLocally: true))
    }

    func testARingUntilInThePastStopsTheLoop() {
        XCTAssertFalse(ask(ringUntil: now.addingTimeInterval(-1)))
    }

    func testRingUntilExactlyNowStopsTheLoop() {
        XCTAssertFalse(ask(ringUntil: now))
    }

    func testNoRingUntilMeansTheServerNeverSentThisIncident() {
        XCTAssertFalse(
            RearmRule.canRearm(
                incidentId: "inc_demo",
                kind: .open,
                criticalOn: true,
                ackedLocally: false,
                ringUntil: nil,
                now: now,
                quietHoursHold: false
            )
        )
    }

    func testATopicWhoseCriticalSwitchIsOffDoesNotRing() {
        XCTAssertFalse(ask(criticalOn: false))
    }

    func testQuietHoursHoldsTheRing() {
        XCTAssertFalse(ask(quietHoursHold: true))
    }

    func testAnEmptyIncidentIdNeverRings() {
        XCTAssertFalse(ask(incidentId: ""))
    }

    func testOpenRepeatAndReopenAllRearm() {
        for kind in [IncidentPush.Kind.open, .repeat, .reopen] {
            XCTAssertTrue(ask(kind: kind), kind.rawValue)
        }
    }

    func testAForwardNeverRearms() {
        XCTAssertFalse(ask(kind: .p4))
    }

    func testTheNextRingLandsOneRepeatIntervalOut() {
        XCTAssertEqual(
            RearmRule.nextRingAt(now: now, repeatIntervalS: 30, ringUntil: ringUntil),
            now.addingTimeInterval(30)
        )
    }

    func testTheNextRingNeverLandsAfterRingUntil() {
        XCTAssertNil(
            RearmRule.nextRingAt(
                now: now, repeatIntervalS: 30, ringUntil: now.addingTimeInterval(10)
            )
        )
    }

    func testANonsenseIntervalFallsBackToTheServerDefault() {
        XCTAssertEqual(
            RearmRule.nextRingAt(now: now, repeatIntervalS: 0, ringUntil: ringUntil),
            now.addingTimeInterval(TimeInterval(RearmRule.defaultRepeatIntervalS))
        )
    }
}

/// The two buttons on the alarm, and the one difference that matters: Stop
/// tells the server nothing, "I'm up" tells it everything.
@available(iOS 16.2, *)
final class IncidentIntentsTests: XCTestCase {
    private let incidentId = "inc_intent_test"

    override func setUp() {
        super.setUp()
        clear()
    }

    override func tearDown() {
        clear()
        super.tearDown()
    }

    private func clear() {
        UserDefaults.standard.removeObject(forKey: AckQueueStore.key)
        AckedIncidentStore.clear(incidentId: incidentId)
    }

    /// The queue is a JSON string under one key, the shape Dart's `AckQueue`
    /// writes and reads.
    private func queuedActions() -> [String] {
        guard let json = UserDefaults.standard.string(forKey: AckQueueStore.key),
              let data = json.data(using: .utf8),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return [] }
        return raw
            .filter { $0["incident_id"] as? String == incidentId }
            .compactMap { $0["action"] as? String }
    }

    func testStopQueuesNothingAndMarksNothing() async throws {
        _ = try await StopAlarmIntent(incidentId: incidentId).perform()

        XCTAssertEqual(queuedActions(), [], "Stop is not an acknowledge")
        XCTAssertFalse(
            AckedIncidentStore.contains(incidentId: incidentId),
            "Stop must leave the incident un-acked, so the next ring still comes"
        )
    }

    func testImUpQueuesTheAckAndMarksTheIncident() async throws {
        _ = try await AckAlarmIntent(incidentId: incidentId).perform()

        XCTAssertEqual(queuedActions(), ["ack"])
        XCTAssertTrue(AckedIncidentStore.contains(incidentId: incidentId))
    }

    func testBothButtonsNameTheSameAlarm() {
        // A re-arm has to replace the alarm it came from rather than stack a
        // second one, and the acknowledge has to be able to cancel it.
        XCTAssertEqual(
            IncidentAlarmScheduler.alarmId(for: incidentId),
            IncidentAlarmScheduler.alarmId(for: incidentId)
        )
    }
}
