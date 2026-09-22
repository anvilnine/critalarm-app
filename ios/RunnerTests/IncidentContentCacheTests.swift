import XCTest

/// The store behind the extension's "do not ask the server twice" rule.
final class IncidentContentCacheTests: XCTestCase {
    private let suite = "IncidentContentCacheTests"
    private var testDefaults: UserDefaults!
    private var realDefaults: UserDefaults?

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: suite)
        testDefaults.removePersistentDomain(forName: suite)
        realDefaults = IncidentContentCache.defaults
        IncidentContentCache.defaults = testDefaults
    }

    override func tearDown() {
        IncidentContentCache.defaults = realDefaults
        testDefaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private func content(
        title: String = "Database down",
        body: String = "db01 is unreachable"
    ) -> IncidentContent {
        IncidentContent(
            title: title,
            body: body,
            tags: ["rotating_light"],
            click: "https://status.example.com/db01",
            topic: "prod-db"
        )
    }

    func testWriteThenRead() {
        IncidentContentCache.write(content(), for: "inc_1", lastMessageAt: 1_700_000_000)

        let entry = IncidentContentCache.read(incidentId: "inc_1")
        XCTAssertEqual(entry?.content.title, "Database down")
        XCTAssertEqual(entry?.content.body, "db01 is unreachable")
        XCTAssertEqual(entry?.content.tags, ["rotating_light"])
        XCTAssertEqual(entry?.content.click, "https://status.example.com/db01")
        XCTAssertEqual(entry?.content.topic, "prod-db")
        XCTAssertEqual(entry?.lastMessageAt, 1_700_000_000)
        XCTAssertGreaterThan(entry?.cachedAtMs ?? 0, 0)
    }

    func testAnUnknownIdReadsAsNothing() {
        XCTAssertNil(IncidentContentCache.read(incidentId: "inc_never_seen"))
    }

    func testASecondWriteReplacesTheFirst() {
        IncidentContentCache.write(content(), for: "inc_1")
        IncidentContentCache.write(content(title: "Database back", body: "db01 is up"), for: "inc_1")

        XCTAssertEqual(IncidentContentCache.read(incidentId: "inc_1")?.content.title, "Database back")
    }

    func testOneIncidentDoesNotSeeAnother() {
        IncidentContentCache.write(content(title: "First"), for: "inc_1")
        IncidentContentCache.write(content(title: "Second"), for: "inc_2")

        XCTAssertEqual(IncidentContentCache.read(incidentId: "inc_1")?.content.title, "First")
        XCTAssertEqual(IncidentContentCache.read(incidentId: "inc_2")?.content.title, "Second")
    }

    func testPruneDropsTheOldAndKeepsTheNew() {
        let now = Date()
        let tooOld = now.addingTimeInterval(-IncidentContentCache.maxAge - 60)
        let stillFresh = now.addingTimeInterval(-60)

        IncidentContentCache.write(content(title: "Old"), for: "inc_old", now: tooOld)
        IncidentContentCache.write(content(title: "New"), for: "inc_new", now: stillFresh)

        IncidentContentCache.prune(now: now)

        XCTAssertNil(IncidentContentCache.read(incidentId: "inc_old"))
        XCTAssertEqual(IncidentContentCache.read(incidentId: "inc_new")?.content.title, "New")
    }

    func testPruneLeavesOtherKeysAlone() {
        testDefaults.set("keep me", forKey: "flutter.something_else")
        IncidentContentCache.write(content(), for: "inc_1")

        IncidentContentCache.prune(olderThan: 0, now: Date().addingTimeInterval(1))

        XCTAssertNil(IncidentContentCache.read(incidentId: "inc_1"))
        XCTAssertEqual(testDefaults.string(forKey: "flutter.something_else"), "keep me")
    }

    func testThirtyMinutesOfRingingPlusTheDeskTimerIsWhatIsKept() {
        XCTAssertEqual(IncidentContentCache.maxAge, 2_400)
    }
}
