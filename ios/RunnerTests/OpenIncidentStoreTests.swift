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
                focusOn: false,
                ackedIds: []
            ),
            [.banner, .list, .sound]
        )
        XCTAssertEqual(
            ForegroundPresentation.options(
                isReminder: true,
                incidentId: nil,
                focusOn: false,
                ackedIds: []
            ),
            [.banner, .list]
        )
    }

    func testNothingButAnAlarmShowsWhileAnAlarmIsUnderWay() {
        // A reminder, and a notification with no incident behind it.
        XCTAssertEqual(
            ForegroundPresentation.options(
                isReminder: true,
                incidentId: nil,
                focusOn: true,
                ackedIds: []
            ),
            []
        )
        XCTAssertEqual(
            ForegroundPresentation.options(
                isReminder: false,
                incidentId: nil,
                focusOn: true,
                ackedIds: []
            ),
            []
        )
    }

    func testTheAlarmItselfStillRings() {
        XCTAssertEqual(
            ForegroundPresentation.options(
                isReminder: false,
                incidentId: "inc_1",
                focusOn: true,
                ackedIds: []
            ),
            [.banner, .list, .sound]
        )
    }

    /// A second topic's first push. Dart writes the open list only once it
    /// has the incident, so this id is new to the phone and the open list
    /// must not be what decides.
    func testAnAlarmPushForAnUnknownIncidentStillRings() {
        XCTAssertEqual(
            ForegroundPresentation.options(
                isReminder: false,
                incidentId: "inc_9",
                focusOn: true,
                ackedIds: ["inc_1"]
            ),
            [.banner, .list, .sound]
        )
    }

    /// A repeat that crosses the ack. The user answered this one already.
    func testAnAlarmPushForAnAckedIncidentIsDropped() {
        XCTAssertEqual(
            ForegroundPresentation.options(
                isReminder: false,
                incidentId: "inc_1",
                focusOn: true,
                ackedIds: ["inc_1"]
            ),
            []
        )
        XCTAssertEqual(
            ForegroundPresentation.options(
                isReminder: false,
                incidentId: "inc_1",
                focusOn: false,
                ackedIds: ["inc_1"]
            ),
            []
        )
    }
}
