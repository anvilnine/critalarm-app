import UserNotifications
import XCTest

/// The open incident list Dart writes, and the rule `willPresent` reads off
/// it. Over their own `UserDefaults` suites so no test touches the app group.
final class OpenIncidentStoreTests: XCTestCase {
    private let open = UserDefaults(suiteName: "open-incident-store-tests")!
    private let acked = UserDefaults(suiteName: "open-incident-store-tests-acked")!

    override func setUp() {
        super.setUp()
        open.removeObject(forKey: OpenIncidentStore.key)
        acked.removeObject(forKey: AckedIncidentStore.key)
    }

    func testWriteThenRead() {
        OpenIncidentStore.write(incidentIds: ["inc_1", "inc_2"], in: open)

        XCTAssertEqual(OpenIncidentStore.all(in: open), ["inc_1", "inc_2"])
    }

    func testAnAckedIncidentIsNotFocused() {
        OpenIncidentStore.write(incidentIds: ["inc_1", "inc_2"], in: open)
        AckedIncidentStore.mark(incidentId: "inc_1", in: acked)

        XCTAssertEqual(OpenIncidentStore.focusedIds(in: open, acked: acked), ["inc_2"])
    }

    func testNothingStoredReadsAsEmpty() {
        XCTAssertEqual(OpenIncidentStore.all(in: open), [])
        XCTAssertEqual(OpenIncidentStore.focusedIds(in: open, acked: acked), [])
    }

    func testNoSuiteReadsAsEmpty() {
        OpenIncidentStore.write(incidentIds: ["inc_1"], in: nil)
        XCTAssertEqual(OpenIncidentStore.all(in: nil), [])
    }

    // MARK: the willPresent rule

    func testQuietPhoneShowsEverythingAsBefore() {
        XCTAssertEqual(
            ForegroundPresentation.options(
                isReminder: false,
                incidentId: "inc_1",
                focusedIds: []
            ),
            [.banner, .list, .sound]
        )
        XCTAssertEqual(
            ForegroundPresentation.options(
                isReminder: true,
                incidentId: nil,
                focusedIds: []
            ),
            [.banner, .list]
        )
    }

    func testNothingShowsWhileAnAlarmIsUnderWay() {
        // A reminder, a push for another topic, and a push for an incident
        // this phone already answered.
        XCTAssertEqual(
            ForegroundPresentation.options(
                isReminder: true,
                incidentId: nil,
                focusedIds: ["inc_1"]
            ),
            []
        )
        XCTAssertEqual(
            ForegroundPresentation.options(
                isReminder: false,
                incidentId: nil,
                focusedIds: ["inc_1"]
            ),
            []
        )
        XCTAssertEqual(
            ForegroundPresentation.options(
                isReminder: false,
                incidentId: "inc_9",
                focusedIds: ["inc_1"]
            ),
            []
        )
    }

    func testTheAlarmItselfStillRings() {
        XCTAssertEqual(
            ForegroundPresentation.options(
                isReminder: false,
                incidentId: "inc_1",
                focusedIds: ["inc_1", "inc_2"]
            ),
            [.banner, .list, .sound]
        )
    }
}
