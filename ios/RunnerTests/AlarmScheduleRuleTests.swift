import XCTest

/// The rule `AppDelegate.application(_:didReceiveRemoteNotification:)` runs
/// before it schedules an AlarmKit alarm, over plain values.
///
/// A `repeat` for an incident the user already stopped here must not ring
/// again. `open` and `reopen` always ring: a reopen is a new stage, and the
/// desk timer depends on it.
final class AlarmScheduleRuleTests: XCTestCase {
    private let acked: Set<String> = ["inc_1"]

    func testARepeatForAnAckedIncidentIsSkipped() {
        XCTAssertFalse(
            AlarmScheduleRule.shouldSchedule(kind: .repeat, incidentId: "inc_1", acked: acked)
        )
    }

    func testAnOpenForAnAckedIncidentStillRings() {
        XCTAssertTrue(
            AlarmScheduleRule.shouldSchedule(kind: .open, incidentId: "inc_1", acked: acked)
        )
    }

    func testAReopenForAnAckedIncidentStillRings() {
        XCTAssertTrue(
            AlarmScheduleRule.shouldSchedule(kind: .reopen, incidentId: "inc_1", acked: acked)
        )
    }

    func testARepeatForAnUnknownIncidentRings() {
        XCTAssertTrue(
            AlarmScheduleRule.shouldSchedule(kind: .repeat, incidentId: "inc_2", acked: acked)
        )
    }

    func testOnlyAReopenClearsTheMark() {
        XCTAssertTrue(AlarmScheduleRule.clearsAck(kind: .reopen))
        XCTAssertFalse(AlarmScheduleRule.clearsAck(kind: .repeat))
        XCTAssertFalse(AlarmScheduleRule.clearsAck(kind: .open))
    }

    // What a running app is told about a push: the incident it rang for, or
    // nothing. A screen waiting for one alarm reads this as "it rang".

    private func push(_ kind: String, id: String? = "inc_9", priority: Int? = nil) -> IncidentPush? {
        var payload: [AnyHashable: Any] = ["kind": kind, "server": "https://alerts.example.com"]
        if let id { payload["incident_id"] = id }
        if let priority { payload["priority"] = priority }
        return IncidentPush(payload: payload)
    }

    func testAPriorityFiveAlarmKindNamesItsIncident() {
        for kind in ["open", "repeat", "reopen"] {
            XCTAssertEqual(
                AlarmScheduleRule.ringingIncidentId(push: push(kind), acked: [], heldByQuietHours: false),
                "inc_9",
                kind
            )
        }
    }

    func testAStateChangePushNamesNothing() {
        for kind in ["ack", "close", "expire"] {
            XCTAssertNil(
                AlarmScheduleRule.ringingIncidentId(push: push(kind), acked: [], heldByQuietHours: false),
                kind
            )
        }
    }

    func testAForwardNamesNothing() {
        XCTAssertNil(
            AlarmScheduleRule.ringingIncidentId(push: push("p4"), acked: [], heldByQuietHours: false)
        )
    }

    func testALowerPriorityNamesNothing() {
        XCTAssertNil(
            AlarmScheduleRule.ringingIncidentId(
                push: push("open", priority: 4), acked: [], heldByQuietHours: false
            )
        )
    }

    func testARingHeldByQuietHoursNamesNothing() {
        XCTAssertNil(
            AlarmScheduleRule.ringingIncidentId(push: push("open"), acked: [], heldByQuietHours: true)
        )
    }

    func testARepeatForAnIncidentStoppedHereNamesNothing() {
        XCTAssertNil(
            AlarmScheduleRule.ringingIncidentId(
                push: push("repeat", id: "inc_1"), acked: acked, heldByQuietHours: false
            )
        )
    }
}
