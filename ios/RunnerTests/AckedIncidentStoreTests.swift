import XCTest

/// The "acked here" set, over its own `UserDefaults` suite so no test touches
/// the app group.
final class AckedIncidentStoreTests: XCTestCase {
    private let store = UserDefaults(suiteName: "acked-incident-store-tests")!

    override func setUp() {
        super.setUp()
        store.removeObject(forKey: AckedIncidentStore.key)
        store.removeObject(forKey: AckedIncidentStore.localKey)
    }

    func testMarkThenContains() {
        XCTAssertFalse(AckedIncidentStore.contains(incidentId: "inc_1", in: store))

        AckedIncidentStore.mark(incidentId: "inc_1", in: store)

        XCTAssertTrue(AckedIncidentStore.contains(incidentId: "inc_1", in: store))
        XCTAssertFalse(AckedIncidentStore.contains(incidentId: "inc_2", in: store))
    }

    func testClearForgetsOneIncidentOnly() {
        AckedIncidentStore.mark(incidentId: "inc_1", in: store)
        AckedIncidentStore.mark(incidentId: "inc_2", in: store)

        AckedIncidentStore.clear(incidentId: "inc_1", in: store)

        XCTAssertFalse(AckedIncidentStore.contains(incidentId: "inc_1", in: store))
        XCTAssertTrue(AckedIncidentStore.contains(incidentId: "inc_2", in: store))
    }

    func testPruneDropsOldAndKeepsNew() {
        let now = Date(timeIntervalSince1970: 10_000)
        AckedIncidentStore.mark(incidentId: "old", at: now.addingTimeInterval(-3_000), in: store)
        AckedIncidentStore.mark(incidentId: "new", at: now.addingTimeInterval(-100), in: store)

        AckedIncidentStore.prune(olderThan: 2_400, now: now, in: store)

        XCTAssertFalse(AckedIncidentStore.contains(incidentId: "old", in: store))
        XCTAssertTrue(AckedIncidentStore.contains(incidentId: "new", in: store))
    }

    func testAllListsEveryMarkedIncident() {
        AckedIncidentStore.mark(incidentId: "inc_1", in: store)
        AckedIncidentStore.mark(incidentId: "inc_2", in: store)

        XCTAssertEqual(AckedIncidentStore.all(in: store), ["inc_1", "inc_2"])
    }

    func testRemoteAcknowledgementDoesNotAppearAsLocallyAcknowledged() {
        AckedIncidentStore.markRemotelyAcknowledged(incidentId: "inc_remote", in: store)

        XCTAssertTrue(AckedIncidentStore.contains(incidentId: "inc_remote", in: store))
        XCTAssertFalse(AckedIncidentStore.locallyAcknowledged(in: store).contains("inc_remote"))
    }

    func testLocalAcknowledgementIsIncludedInDebugMarks() {
        AckedIncidentStore.mark(incidentId: "inc_local", in: store)

        XCTAssertEqual(AckedIncidentStore.locallyAcknowledged(in: store), ["inc_local"])
        XCTAssertEqual(AckedIncidentStore.debugEntries(in: store).count, 1)
    }

    func testClearingDebugMarksKeepsTheRepeatSuppressionMark() {
        AckedIncidentStore.mark(incidentId: "inc_local", in: store)

        AckedIncidentStore.clearLocalMarks(in: store)

        XCTAssertTrue(AckedIncidentStore.contains(incidentId: "inc_local", in: store))
        XCTAssertFalse(AckedIncidentStore.locallyAcknowledged(in: store).contains("inc_local"))
    }

    /// The Dart topic timer cache writes `repeat|max_ring|desk_timer` seconds
    /// under `flutter.topic_timers.<topic>`. The window is the last two added.
    func testPruneWindowReadsTheTopicTimers() {
        XCTAssertEqual(AckedIncidentStore.pruneWindow(topicTimers: "30|900|300"), 1_200)
    }

    func testPruneWindowFallsBackWhenNothingIsStored() {
        XCTAssertEqual(AckedIncidentStore.pruneWindow(topicTimers: nil), 2_400)
        XCTAssertEqual(AckedIncidentStore.pruneWindow(topicTimers: "garbage"), 2_400)
    }

    func testNoSuiteReadsAsEmptyAndWritesNothing() {
        AckedIncidentStore.mark(incidentId: "inc_1", in: nil)
        XCTAssertFalse(AckedIncidentStore.contains(incidentId: "inc_1", in: nil))
        XCTAssertEqual(AckedIncidentStore.all(in: nil), [])
    }
}
