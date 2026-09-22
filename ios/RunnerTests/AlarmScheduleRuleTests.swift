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
}
