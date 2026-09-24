import XCTest

@available(iOS 16.2, *)
final class LiveCardTextTests: XCTestCase {
    private typealias ContentState = CritAlarmIncidentAttributes.ContentState

    // api.md §5.3 content-state, exactly as the server sends it.
    private let serverJSON = #"{"state":"acked","title":"Database down","opened_at":1757740800}"#

    func testServerContentStateStillDecodes() throws {
        let decoded = try JSONDecoder().decode(ContentState.self, from: Data(serverJSON.utf8))
        XCTAssertEqual(decoded.state, .acked)
        XCTAssertEqual(decoded.title, "Database down")
        XCTAssertNil(decoded.ackedAt)
        XCTAssertNil(decoded.ringsAgainInSeconds)
    }

    func testAckedAtDecodesWhenPresent() throws {
        let json = #"{"state":"acked","title":"Database down","opened_at":1757740800,"acked_at":1757740860}"#
        let decoded = try JSONDecoder().decode(ContentState.self, from: Data(json.utf8))
        XCTAssertNotNil(decoded.ackedAt)
    }

    func testLocalStateRoundTrips() throws {
        let ackedAt = Date(timeIntervalSince1970: 1_757_740_860)
        let state = ContentState(
            state: .acked, title: "Database down",
            openedAt: Date(timeIntervalSince1970: 1_757_740_800), ackedAt: ackedAt
        )
        let data = try JSONEncoder().encode(state)
        XCTAssertEqual(try JSONDecoder().decode(ContentState.self, from: data), state)
        let keys = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any]).keys
        XCTAssertTrue(keys.contains("acked_at"))
    }

    func testStaleDateIsFourHoursAfterTheAck() {
        let ackedAt = Date(timeIntervalSince1970: 1_000)
        XCTAssertEqual(LiveCardText.staleDate(ackedAt: ackedAt), Date(timeIntervalSince1970: 1_000 + 14_400))
    }

    func testPillLabels() {
        XCTAssertEqual(LiveCardText.pillLabel(state: .open, isStale: false), "Ringing")
        XCTAssertEqual(LiveCardText.pillLabel(state: .acked, isStale: false), "Awake")
        XCTAssertEqual(LiveCardText.pillLabel(state: .acked, isStale: true), "Still open")
        XCTAssertEqual(LiveCardText.pillLabel(state: .closed, isStale: true), "Closed")
        XCTAssertEqual(LiveCardText.pillLabel(state: .expired, isStale: false), "Missed")
    }

    func testAckedLineUsesTwentyFourHourTimeInTheGivenZone() {
        let ackedAt = Date(timeIntervalSince1970: 3 * 3600 + 12 * 60)
        let utc = TimeZone(identifier: "UTC")!
        let manila = TimeZone(identifier: "Asia/Manila")!
        XCTAssertEqual(LiveCardText.ackedLine(ackedAt, timeZone: utc), "Acknowledged at 03:12")
        XCTAssertEqual(LiveCardText.ackedLine(ackedAt, timeZone: manila), "Acknowledged at 11:12")
    }

    func testTimerCountsFromTheAckOnlyWhenKnown() {
        let opened = Date(timeIntervalSince1970: 100)
        let acked = Date(timeIntervalSince1970: 200)
        XCTAssertEqual(LiveCardText.timerStart(state: .acked, openedAt: opened, ackedAt: acked), acked)
        XCTAssertEqual(LiveCardText.timerStart(state: .acked, openedAt: opened, ackedAt: nil), opened)
        XCTAssertEqual(LiveCardText.timerStart(state: .open, openedAt: opened, ackedAt: acked), opened)
    }

    func testButtons() {
        XCTAssertEqual(LiveCardText.button(state: .acked, silenced: false), .done)
        XCTAssertEqual(LiveCardText.button(state: .open, silenced: true), .imUp)
        XCTAssertNil(LiveCardText.button(state: .open, silenced: false))
        XCTAssertNil(LiveCardText.button(state: .closed, silenced: false))
    }
}
