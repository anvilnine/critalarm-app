import XCTest

/// The widget snapshot: the shared fixtures, the patches and the store.
///
/// The patch cases carry the same names as
/// `android/app/src/test/kotlin/app/critalarm/widgets/WidgetSnapshotPatchTest.kt`.
/// Fixture: prod (open inc_9a8b7c, count 2), backups (acked inc_4d5e6f,
/// count 1), staging (quiet).
final class WidgetSnapshotTests: XCTestCase {
    private let defaults = UserDefaults(suiteName: "widget-snapshot-store-tests")!
    private let now = Date(timeIntervalSince1970: 1_759_047_000)
    private var nowSeconds: Int { WidgetSnapshot.seconds(now) }

    override func setUp() {
        super.setUp()
        defaults.removeObject(forKey: WidgetSnapshotStore.key)
    }

    /// The repo's `test/fixtures`. The simulator reads host paths.
    private func fixtureData(_ name: String) throws -> Data {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // RunnerTests
            .deletingLastPathComponent() // ios
            .deletingLastPathComponent() // repo root
        return try Data(contentsOf: root.appendingPathComponent("test/fixtures/\(name)"))
    }

    private func fixture() throws -> WidgetSnapshot {
        try XCTUnwrap(WidgetSnapshot.decode(fixtureData("widget_snapshot_v1.json")))
    }

    private func changed(_ result: WidgetPatchResult, file: StaticString = #filePath, line: UInt = #line) -> WidgetSnapshot? {
        guard case let .changed(snapshot) = result else {
            XCTFail("expected changed, got \(result)", file: file, line: line)
            return nil
        }
        return snapshot
    }

    private func partial(_ result: WidgetPatchResult, file: StaticString = #filePath, line: UInt = #line) -> WidgetSnapshot?? {
        guard case let .needsFetch(snapshot) = result else {
            XCTFail("expected needsFetch, got \(result)", file: file, line: line)
            return nil
        }
        return .some(snapshot)
    }

    private func topic(_ snapshot: WidgetSnapshot?, _ name: String) -> WidgetTopic? {
        snapshot?.topics.first { $0.name == name }
    }

    // MARK: the fixtures

    func testEveryCaseInTheTitleFixture() throws {
        let object = try JSONSerialization.jsonObject(with: fixtureData("widget_titles_v1.json")) as? [String: Any]
        XCTAssertEqual(object?["max_code_points"] as? Int, WidgetSnapshot.titleMaxLength)
        let cases = try XCTUnwrap(object?["cases"] as? [[String: String]])
        XCTAssertFalse(cases.isEmpty)
        for c in cases {
            XCTAssertEqual(WidgetSnapshot.title(c["raw"], topic: c["topic"] ?? ""), c["title"], c["note"] ?? "")
        }
    }

    func testTheFixtureDecodes() throws {
        let snapshot = try fixture()
        XCTAssertEqual(snapshot.updatedAt, 1_759_046_400)
        XCTAssertTrue(snapshot.connected)
        XCTAssertEqual(snapshot.openCount, 3)
        XCTAssertEqual(snapshot.topics.map(\.name), ["prod", "backups", "staging"])
        XCTAssertEqual(
            snapshot.topics[0].incident,
            WidgetIncident(id: "inc_9a8b7c", state: "open", title: "Database down", openedAt: 1_759_046_100, ackedAt: nil)
        )
        XCTAssertEqual(snapshot.topics[1].incident?.ackedAt, 1_759_042_920)
        XCTAssertNil(snapshot.topics[2].incident)
    }

    func testEncodingMatchesTheFixtureKeyForKey() throws {
        let written = try JSONSerialization.jsonObject(with: fixture().encoded()) as? NSDictionary
        let expected = try JSONSerialization.jsonObject(with: fixtureData("widget_snapshot_v1.json")) as? NSDictionary
        XCTAssertEqual(written, expected)
    }

    func testAnotherVersionDecodesToNil() throws {
        let text = try XCTUnwrap(String(data: fixtureData("widget_snapshot_v1.json"), encoding: .utf8))
            .replacingOccurrences(of: "\"v\": 1", with: "\"v\": 2")
        XCTAssertNil(WidgetSnapshot.decode(Data(text.utf8)))
    }

    func testGarbageDecodesToNil() {
        XCTAssertNil(WidgetSnapshot.decode(Data()))
        XCTAssertNil(WidgetSnapshot.decode(Data("not json".utf8)))
        XCTAssertNil(WidgetSnapshot.decode(Data("{\"v\":1}".utf8)))
    }

    func testTheServerSampleBuildsExactlyTheFixture() throws {
        let server = try XCTUnwrap(
            JSONSerialization.jsonObject(with: fixtureData("widget_server_v1.json")) as? [String: Any]
        )
        func data(_ key: String) throws -> Data {
            try JSONSerialization.data(withJSONObject: XCTUnwrap(server[key]))
        }
        let nowValue = try XCTUnwrap(server["now"] as? NSNumber).doubleValue
        let built = try WidgetSnapshot.fromServer(
            topics: data("topics"), open: data("open"), acked: data("acked"),
            now: Date(timeIntervalSince1970: nowValue)
        )
        XCTAssertEqual(built, try fixture())
    }

    func testUnreadableServerAnswersGiveNothing() {
        let empty = Data("[]".utf8)
        XCTAssertNil(WidgetSnapshot.fromServer(topics: Data("nope".utf8), open: empty, acked: empty, now: now))
        XCTAssertNil(WidgetSnapshot.fromServer(topics: empty, open: Data("{}".utf8), acked: empty, now: now))
    }

    func testTimesMayBeSecondsMillisecondsOrISO() {
        XCTAssertEqual(WidgetSnapshot.epochSeconds(NSNumber(value: 1_759_046_100)), 1_759_046_100)
        XCTAssertEqual(WidgetSnapshot.epochSeconds(NSNumber(value: 1_759_046_100_999 as Int64)), 1_759_046_100)
        XCTAssertEqual(WidgetSnapshot.epochSeconds("1759046100"), 1_759_046_100)
        XCTAssertEqual(WidgetSnapshot.epochSeconds("2025-09-28T07:55:00Z"), 1_759_046_100)
        XCTAssertNil(WidgetSnapshot.epochSeconds(nil))
        XCTAssertNil(WidgetSnapshot.epochSeconds("soon"))
    }

    func testTheDisconnectedShape() throws {
        let json = try JSONSerialization.jsonObject(
            with: WidgetSnapshot.disconnected(now: Date(timeIntervalSince1970: 1_759_046_400)).encoded()
        ) as? NSDictionary
        XCTAssertEqual(json, [
            "v": 1, "updated_at": 1_759_046_400, "connected": false, "open_count": 0, "topics": [Any](),
        ] as NSDictionary)
    }

    // MARK: freshness

    func testFreshAt899Seconds() throws {
        let snapshot = try fixture()
        XCTAssertFalse(snapshot.isStale(now: Date(timeIntervalSince1970: TimeInterval(snapshot.updatedAt + 899))))
    }

    func testStaleAt900Seconds() throws {
        let snapshot = try fixture()
        XCTAssertTrue(snapshot.isStale(now: Date(timeIntervalSince1970: TimeInterval(snapshot.updatedAt + 900))))
    }

    func testUpdatedAtZeroIsStaleRightAway() throws {
        var snapshot = try fixture()
        snapshot.updatedAt = 0
        XCTAssertTrue(snapshot.isStale(now: Date(timeIntervalSince1970: 1)))
    }

    func testSignedOutIsNeverStale() {
        XCTAssertFalse(WidgetSnapshot.disconnected(now: Date(timeIntervalSince1970: 0)).isStale(now: now))
    }

    // MARK: opened

    func testOpenedOnAMissingSnapshotIsUnchanged() {
        XCTAssertEqual(WidgetPatch.opened("inc_new", topic: "staging", title: "x", openedAt: now).apply(to: nil, now: now), .unchanged)
    }

    func testOpenedOnASignedOutSnapshotIsUnchanged() {
        let signedOut = WidgetSnapshot.disconnected(now: now)
        XCTAssertEqual(WidgetPatch.opened("inc_new", topic: "staging", title: "x", openedAt: now).apply(to: signedOut, now: now), .unchanged)
    }

    func testOpenedANewIdOnAQuietTopicShowsIt() throws {
        let next = changed(WidgetPatch.opened("inc_new", topic: "staging", title: "Queue stuck", openedAt: now).apply(to: try fixture(), now: now))
        XCTAssertEqual(
            topic(next, "staging")?.incident,
            WidgetIncident(id: "inc_new", state: "open", title: "Queue stuck", openedAt: nowSeconds, ackedAt: nil)
        )
        XCTAssertEqual(topic(next, "staging")?.count, 1)
        XCTAssertEqual(next?.openCount, 4)
        XCTAssertEqual(next?.updatedAt, nowSeconds)
        XCTAssertEqual(next?.topics.map(\.name), ["prod", "staging", "backups"])
    }

    func testOpenedAKnownIdIsUnchanged() throws {
        XCTAssertEqual(WidgetPatch.opened("inc_9a8b7c", topic: "prod", title: "Database down", openedAt: now).apply(to: try fixture(), now: now), .unchanged)
    }

    func testOpenedWithNoTopicNeedsAFetch() throws {
        XCTAssertEqual(WidgetPatch.opened("inc_new", topic: nil, title: "x", openedAt: now).apply(to: try fixture(), now: now), .needsFetch(nil))
    }

    func testOpenedOnAnUnknownTopicNeedsAFetch() throws {
        XCTAssertEqual(WidgetPatch.opened("inc_new", topic: "nope", title: "x", openedAt: now).apply(to: try fixture(), now: now), .needsFetch(nil))
    }

    func testOpenedOnATopicWithUnnamedIncidentsNeedsAFetch() throws {
        XCTAssertEqual(WidgetPatch.opened("inc_new", topic: "prod", title: "x", openedAt: now).apply(to: try fixture(), now: now), .needsFetch(nil))
    }

    func testOpenedANewerIdWinsOverAnAckedOne() throws {
        let next = changed(WidgetPatch.opened("inc_new", topic: "backups", title: "x", openedAt: now).apply(to: try fixture(), now: now))
        XCTAssertEqual(topic(next, "backups")?.incident?.id, "inc_new")
        XCTAssertEqual(topic(next, "backups")?.count, 2)
        XCTAssertEqual(next?.topics.map(\.name), ["backups", "prod", "staging"])
    }

    func testOpenedTitleFallsBackToTheTopicAndIsCutTo120() throws {
        let blank = changed(WidgetPatch.opened("inc_new", topic: "staging", title: "  ", openedAt: now).apply(to: try fixture(), now: now))
        XCTAssertEqual(topic(blank, "staging")?.incident?.title, "staging")
        let long = changed(WidgetPatch.opened("inc_new", topic: "staging", title: String(repeating: "a", count: 200), openedAt: now).apply(to: try fixture(), now: now))
        XCTAssertEqual(topic(long, "staging")?.incident?.title.count, 120)
    }

    // MARK: reopened

    func testReopenedAnAckedIdIsOpenAgain() throws {
        let next = changed(WidgetPatch.reopened("inc_4d5e6f").apply(to: try fixture(), now: now))
        XCTAssertEqual(topic(next, "backups")?.incident?.state, "open")
        XCTAssertNil(topic(next, "backups")?.incident?.ackedAt)
        XCTAssertEqual(topic(next, "backups")?.count, 1)
        XCTAssertEqual(next?.openCount, 3)
        XCTAssertEqual(next?.topics.map(\.name), ["backups", "prod", "staging"])
    }

    func testReopenedAnOpenIdIsUnchanged() throws {
        XCTAssertEqual(WidgetPatch.reopened("inc_9a8b7c").apply(to: try fixture(), now: now), .unchanged)
    }

    func testReopenedAnUnknownIdNeedsAFetch() throws {
        XCTAssertEqual(WidgetPatch.reopened("inc_nope").apply(to: try fixture(), now: now), .needsFetch(nil))
    }

    func testReopenedOnAMissingSnapshotIsUnchanged() {
        XCTAssertEqual(WidgetPatch.reopened("inc_4d5e6f").apply(to: nil, now: now), .unchanged)
    }

    // MARK: acked

    func testAckedTheOnlyIncidentOnATopicChangesIt() throws {
        let opened = try XCTUnwrap(changed(WidgetPatch.opened("inc_new", topic: "staging", title: "x", openedAt: now).apply(to: try fixture(), now: now)))
        let later = now.addingTimeInterval(10)
        let next = changed(WidgetPatch.acked("inc_new", at: now.addingTimeInterval(5)).apply(to: opened, now: later))
        XCTAssertEqual(
            topic(next, "staging")?.incident,
            WidgetIncident(id: "inc_new", state: "acked", title: "x", openedAt: nowSeconds, ackedAt: nowSeconds + 5)
        )
        XCTAssertEqual(next?.updatedAt, nowSeconds + 10)
        XCTAssertEqual(next?.topics.map(\.name), ["prod", "backups", "staging"])
    }

    func testAckedOnATopicWithOtherIncidentsWritesTheChangeAndNeedsAFetch() throws {
        let next = try XCTUnwrap(partial(WidgetPatch.acked("inc_9a8b7c", at: now).apply(to: try fixture(), now: now)) ?? nil)
        XCTAssertEqual(topic(next, "prod")?.incident?.state, "acked")
        XCTAssertEqual(topic(next, "prod")?.incident?.ackedAt, nowSeconds)
        XCTAssertEqual(topic(next, "prod")?.count, 2)
    }

    func testAckedKeepsAnAckedAtAlreadyKnown() throws {
        XCTAssertEqual(WidgetPatch.acked("inc_4d5e6f", at: now).apply(to: try fixture(), now: now), .unchanged)
    }

    func testAckedAnUnknownIdNeedsAFetch() throws {
        XCTAssertEqual(WidgetPatch.acked("inc_nope", at: now).apply(to: try fixture(), now: now), .needsFetch(nil))
    }

    func testAckedOnAMissingSnapshotIsUnchanged() {
        XCTAssertEqual(WidgetPatch.acked("inc_9a8b7c", at: now).apply(to: nil, now: now), .unchanged)
    }

    // MARK: ended

    func testEndedTheOnlyIncidentQuietsTheTopic() throws {
        let next = changed(WidgetPatch.ended("inc_4d5e6f").apply(to: try fixture(), now: now))
        XCTAssertNil(topic(next, "backups")?.incident)
        XCTAssertEqual(topic(next, "backups")?.count, 0)
        XCTAssertEqual(next?.openCount, 2)
        XCTAssertEqual(next?.topics.map(\.name), ["prod", "backups", "staging"])
    }

    func testEndedWithOtherIncidentsLeftWritesTheChangeAndNeedsAFetch() throws {
        let next = try XCTUnwrap(partial(WidgetPatch.ended("inc_9a8b7c").apply(to: try fixture(), now: now)) ?? nil)
        XCTAssertNil(topic(next, "prod")?.incident)
        XCTAssertEqual(topic(next, "prod")?.count, 1)
        XCTAssertEqual(next.openCount, 2)
    }

    func testEndedAnUnknownIdNeedsAFetch() throws {
        XCTAssertEqual(WidgetPatch.ended("inc_nope").apply(to: try fixture(), now: now), .needsFetch(nil))
    }

    func testEndedOnAMissingSnapshotIsUnchanged() {
        XCTAssertEqual(WidgetPatch.ended("inc_9a8b7c").apply(to: nil, now: now), .unchanged)
    }

    // MARK: upsert (iOS only, from the extension's fetch)

    func testUpsertPlacesAFetchedIncidentOnAQuietTopic() throws {
        let record = WidgetIncidentRecord(id: "inc_new", topic: "staging", state: "open", title: "Queue stuck", openedAt: 100, ackedAt: nil)
        let next = changed(WidgetPatch.upsert(record).apply(to: try fixture(), now: now))
        XCTAssertEqual(topic(next, "staging")?.incident?.title, "Queue stuck")
        XCTAssertEqual(topic(next, "staging")?.count, 1)
    }

    func testUpsertTheSameIncidentIsUnchanged() throws {
        let record = WidgetIncidentRecord(id: "inc_4d5e6f", topic: "backups", state: "acked", title: "nas-backup exited 1", openedAt: 1_759_042_800, ackedAt: 1_759_042_920)
        XCTAssertEqual(WidgetPatch.upsert(record).apply(to: try fixture(), now: now), .unchanged)
    }

    func testIncidentRecordReadsTheNewestMessage() throws {
        let json = Data("""
        {"id":"inc_1","topic":"prod","state":"acked","opened_at":100,"acked_at":"200",
         "messages":[{"time":20,"title":"newest"},{"time":10,"title":"oldest"}]}
        """.utf8)
        XCTAssertEqual(
            WidgetSnapshot.incidentRecord(fromIncidentJSON: json),
            WidgetIncidentRecord(id: "inc_1", topic: "prod", state: "acked", title: "newest", openedAt: 100, ackedAt: 200)
        )
    }

    // MARK: the store

    func testWriteJSONRefusesGarbage() throws {
        XCTAssertFalse(WidgetSnapshotStore.writeJSON("not json", in: defaults))
        XCTAssertFalse(WidgetSnapshotStore.writeJSON("{\"v\":2}", in: defaults))
        XCTAssertNil(WidgetSnapshotStore.read(in: defaults))

        let good = try XCTUnwrap(String(data: fixtureData("widget_snapshot_v1.json"), encoding: .utf8))
        XCTAssertTrue(WidgetSnapshotStore.writeJSON(good, in: defaults))
        XCTAssertEqual(WidgetSnapshotStore.read(in: defaults), try fixture())
    }

    func testAPatchOnAnEmptyStoreWritesNothing() {
        XCTAssertEqual(WidgetSnapshotStore.patch(.ended("inc_9a8b7c"), now: now, in: defaults), .unchanged)
        XCTAssertNil(WidgetSnapshotStore.read(in: defaults))
    }

    func testANeededFetchIsWrittenStale() throws {
        WidgetSnapshotStore.write(try fixture(), in: defaults)
        WidgetSnapshotStore.patch(.ended("inc_9a8b7c"), now: now, in: defaults)
        let stored = try XCTUnwrap(WidgetSnapshotStore.read(in: defaults))
        XCTAssertEqual(stored.updatedAt, 0)
        XCTAssertNil(topic(stored, "prod")?.incident)
    }

    func testClearWritesTheSignedOutSnapshot() {
        WidgetSnapshotStore.clear(now: now, in: defaults)
        XCTAssertEqual(WidgetSnapshotStore.read(in: defaults), .disconnected(now: now))
    }

    func testAckedAtComesFromTheSnapshot() throws {
        WidgetSnapshotStore.write(try fixture(), in: defaults)
        XCTAssertEqual(
            WidgetSnapshotStore.ackedAt(incidentId: "inc_4d5e6f", in: defaults),
            Date(timeIntervalSince1970: 1_759_042_920)
        )
        XCTAssertNil(WidgetSnapshotStore.ackedAt(incidentId: "inc_9a8b7c", in: defaults))
    }
}
