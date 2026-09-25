import XCTest

/// The rules the home and lock screen widgets draw with.
final class WidgetDisplayTests: XCTestCase {
    private func incident(_ state: String) -> WidgetIncident {
        WidgetIncident(
            id: "inc_\(state)", state: state, title: "Database down",
            openedAt: 1_759_046_100, ackedAt: state == WidgetIncident.acked ? 1_759_046_200 : nil
        )
    }

    private func snapshot(topics count: Int) -> WidgetSnapshot {
        WidgetSnapshot(
            updatedAt: 1_759_046_400, connected: true, openCount: 0,
            topics: (0 ..< count).map {
                WidgetTopic(name: "topic-\($0)", critical: false, count: 0, incident: nil)
            }
        )
    }

    func testRowLimitPerFamily() {
        XCTAssertEqual(WidgetDisplay.rowLimit(family: "systemSmall"), 1)
        XCTAssertEqual(WidgetDisplay.rowLimit(family: "systemMedium"), 3)
        XCTAssertEqual(WidgetDisplay.rowLimit(family: "systemLarge"), 7)
        XCTAssertEqual(WidgetDisplay.rowLimit(family: "accessoryCircular"), 1)
    }

    func testRowsKeepDisplayOrderAndCountWhatIsLeftOver() {
        let cut = WidgetDisplay.rows(snapshot(topics: 10), limit: 7)
        XCTAssertEqual(cut.rows.map(\.name), (0 ..< 7).map { "topic-\($0)" })
        XCTAssertEqual(cut.more, 3)
    }

    func testRowsWithRoomToSpareHaveNothingMore() {
        let cut = WidgetDisplay.rows(snapshot(topics: 2), limit: 3)
        XCTAssertEqual(cut.rows.count, 2)
        XCTAssertEqual(cut.more, 0)
    }

    func testRowsOfAnEmptySnapshot() {
        let cut = WidgetDisplay.rows(snapshot(topics: 0), limit: 7)
        XCTAssertTrue(cut.rows.isEmpty)
        XCTAssertEqual(cut.more, 0)
    }

    func testRowsWithAZeroLimitCountEverythingAsMore() {
        let cut = WidgetDisplay.rows(snapshot(topics: 4), limit: 0)
        XCTAssertTrue(cut.rows.isEmpty)
        XCTAssertEqual(cut.more, 4)
    }

    func testStateWords() {
        XCTAssertEqual(WidgetDisplay.stateWord(incident(WidgetIncident.open)), "Ringing")
        XCTAssertEqual(WidgetDisplay.stateWord(incident(WidgetIncident.acked)), "Awake")
        XCTAssertEqual(WidgetDisplay.stateWord(nil), "Quiet")
    }

    func testButtonTitles() {
        XCTAssertEqual(WidgetDisplay.buttonTitle(incident(WidgetIncident.open)), "I'm up")
        XCTAssertEqual(WidgetDisplay.buttonTitle(incident(WidgetIncident.acked)), "Done")
        XCTAssertNil(WidgetDisplay.buttonTitle(nil))
    }

    func testTheCountFaceFollowsTheWorstState() {
        let acked = WidgetTopic(name: "db", critical: false, count: 1, incident: incident(WidgetIncident.acked))
        let open = WidgetTopic(name: "prod", critical: false, count: 1, incident: incident(WidgetIncident.open))
        let quiet = WidgetTopic(name: "web", critical: false, count: 0, incident: nil)
        func count(_ topics: [WidgetTopic]) -> WidgetSnapshot {
            WidgetSnapshot(updatedAt: 1_759_046_400, connected: true, openCount: topics.count, topics: topics)
        }

        // Ringing anywhere wins, even below an acked row.
        XCTAssertEqual(WidgetDisplay.worstIncident(count([acked, quiet, open]))?.state, WidgetIncident.open)
        XCTAssertEqual(WidgetDisplay.worstIncident(count([quiet, acked]))?.state, WidgetIncident.acked)
        XCTAssertNil(WidgetDisplay.worstIncident(count([quiet])))
        XCTAssertNil(WidgetDisplay.worstIncident(snapshot(topics: 0)))
    }
}
