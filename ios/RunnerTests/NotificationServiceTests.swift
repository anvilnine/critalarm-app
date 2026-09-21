import UserNotifications
import XCTest

/// Runs the Notification Service Extension over the fixtures in
/// `scripts/push/`.
///
/// `xcrun simctl push` hands the payload straight to the notification system
/// and never starts a service extension, so a delivered banner cannot show
/// that the fetch worked. These call `didReceive` the way APNs would.
final class NotificationServiceTests: XCTestCase {
    /// Where `scripts/push/*.apns` points. Change both together.
    private let mockServer = URL(string: "http://127.0.0.1:8787")!

    /// Nothing listens here, which is what a stopped server looks like.
    private let deadServer = URL(string: "http://127.0.0.1:9")!

    override func tearDown() {
        NseCredentials.clear()
        super.tearDown()
    }

    // MARK: - Fixtures

    private func fixture(_ name: String) throws -> [String: Any] {
        let url = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: name, withExtension: "apns"),
            "\(name).apns is not in the test bundle"
        )
        let data = try Data(contentsOf: url)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func request(from payload: [String: Any]) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        let aps = payload["aps"] as? [String: Any] ?? [:]
        let alert = aps["alert"] as? [String: Any] ?? [:]
        content.title = alert["title"] as? String ?? ""
        content.body = alert["body"] as? String ?? ""
        content.categoryIdentifier = aps["category"] as? String ?? ""
        content.userInfo = payload
        return UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
    }

    @discardableResult
    private func run(_ name: String, timeout: TimeInterval = 20) throws -> UNNotificationContent {
        // The system holds the extension while the fetch is in flight. Hold it
        // here too, or the callback finds a deallocated `self` and the
        // notification is never delivered.
        let service = NotificationService()
        let delivered = expectation(description: "\(name) delivered")
        var result: UNNotificationContent?
        service.didReceive(request(from: try fixture(name))) { content in
            result = content
            delivered.fulfill()
        }
        wait(for: [delivered], timeout: timeout)
        withExtendedLifetime(service) {}
        return try XCTUnwrap(result)
    }

    private var serverIsUp: Bool {
        let probe = expectation(description: "probe")
        var reachable = false
        var request = URLRequest(url: mockServer.appendingPathComponent("v1/info"))
        request.timeoutInterval = 2
        URLSession.shared.dataTask(with: request) { _, response, _ in
            reachable = (response as? HTTPURLResponse) != nil
            probe.fulfill()
        }.resume()
        wait(for: [probe], timeout: 5)
        return reachable
    }

    // MARK: - Payload parsing (api.md §5.1)

    func testPriorityFivePayloadParses() throws {
        let push = try XCTUnwrap(IncidentPush(payload: try fixture("p5")))
        XCTAssertEqual(push.kind, .open)
        XCTAssertEqual(push.priority, 5)
        XCTAssertEqual(push.incidentId, "inc_alarmed_proddb")
        XCTAssertFalse(push.needsContentFetch, "relay_content: full carries its own text")
    }

    func testContentNonePayloadAsksForAFetch() throws {
        let push = try XCTUnwrap(IncidentPush(payload: try fixture("content-none")))
        XCTAssertEqual(push.kind, .open)
        XCTAssertEqual(push.priority, 5)
        XCTAssertTrue(push.needsContentFetch)
    }

    func testPriorityFourForwardCarriesNoIncident() throws {
        let push = try XCTUnwrap(IncidentPush(payload: try fixture("p4")))
        XCTAssertEqual(push.kind, .p4)
        XCTAssertEqual(push.priority, 4)
        XCTAssertNil(push.incidentId)
    }

    func testPriorityThreeIsNotARelayPush() throws {
        // api.md §1.7: priority 1-3 never reaches the relay. The fixture is the
        // local shape a poll produces, so it carries no `kind` and the
        // extension leaves it alone.
        XCTAssertNil(IncidentPush(payload: try fixture("p3")))
    }

    // MARK: - Interruption level

    func testPriorityThreeStaysActive() throws {
        let content = try run("p3")
        XCTAssertEqual(content.interruptionLevel, .active)
    }

    func testPriorityFourBreaksThroughAFocus() throws {
        let content = try run("p4")
        XCTAssertEqual(content.interruptionLevel, .timeSensitive)
    }

    func testACriticalTopicKeepsItsCriticalLevel() throws {
        let content = try run("p5")
        XCTAssertEqual(content.interruptionLevel, .critical)
    }

    // MARK: - The fetch (api.md §3.2)

    func testContentNoneResolvesAgainstTheMockServer() throws {
        NseCredentials.write(server: mockServer.absoluteString, token: "dv_test")
        let up = serverIsUp
        let content = try run("content-none")

        if up {
            XCTAssertEqual(
                content.title, "🚨 Database down",
                "the rotating_light tag renders as an emoji prefix"
            )
            XCTAssertEqual(
                content.body,
                "db01 is unreachable from every region, page the on-call"
            )
            XCTAssertEqual(
                content.userInfo["click"] as? String,
                "https://status.example.com/db01"
            )
            XCTAssertEqual(content.userInfo["topic"] as? String, "prod-db")
        } else {
            XCTAssertEqual(content.title, "Crit Alarm", "the placeholder survives")
            XCTAssertEqual(
                content.body,
                "Critical alert on prod-db, open to see details"
            )
            XCTAssertNil(content.userInfo["click"])
        }
        print("NSE fetch: mock server \(up ? "up, body replaced" : "down, placeholder kept")")
    }

    func testContentNoneFallsBackWhenTheServerIsGone() throws {
        NseCredentials.write(server: deadServer.absoluteString, token: "dv_test")
        let content = try run("content-none")

        XCTAssertEqual(content.title, "Crit Alarm")
        XCTAssertEqual(content.body, "Critical alert on prod-db, open to see details")
        XCTAssertNil(content.userInfo["click"])
        XCTAssertEqual(content.interruptionLevel, .critical, "the level still applies")
    }

    func testNoCredentialsFallsBackWithoutWaiting() throws {
        NseCredentials.clear()
        let started = Date()
        let content = try run("content-none")

        XCTAssertEqual(content.body, "Critical alert on prod-db, open to see details")
        XCTAssertLessThan(
            Date().timeIntervalSince(started), IncidentContentFetcher.timeout,
            "with nothing to call, there is nothing to wait for"
        )
    }

    // MARK: - Keychain

    func testCredentialsRoundTrip() {
        NseCredentials.write(server: "https://alerts.example.com", token: "dv_secret")
        let session = NseCredentials.read()
        XCTAssertEqual(session?.server.absoluteString, "https://alerts.example.com")
        XCTAssertEqual(session?.token, "dv_secret")

        NseCredentials.clear()
        XCTAssertNil(NseCredentials.read())
    }

    // MARK: - Rendering

    func testEmojiTagsGoInFrontOfTheTitle() {
        XCTAssertEqual(
            NtfyEmoji.prefixTitle("Database down", tags: ["rotating_light", "db01"]),
            "🚨 Database down"
        )
        XCTAssertEqual(
            NtfyEmoji.prefixTitle("Database down", tags: ["db01"]),
            "Database down",
            "a tag that matches no shortcode stays out of the title"
        )
    }
}

/// Which sound the extension hands the notification.
final class SharedSoundsTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "SharedSoundsTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testTopicChoiceWinsOverTheDefault() {
        SharedSounds.publish(defaultFile: "classic_siren.caf", perTopicFiles: ["prod": "user_1.caf"], to: defaults)
        let name = SharedSounds.fileName(forTopic: "prod", defaults: defaults) { _ in true }
        XCTAssertEqual(name, "user_1.caf")
    }

    func testUnknownTopicUsesTheDefault() {
        SharedSounds.publish(defaultFile: "classic_siren.caf", perTopicFiles: ["prod": "user_1.caf"], to: defaults)
        XCTAssertEqual(SharedSounds.fileName(forTopic: nil, defaults: defaults) { _ in true }, "classic_siren.caf")
        XCTAssertEqual(SharedSounds.fileName(forTopic: "staging", defaults: defaults) { _ in true }, "classic_siren.caf")
    }

    func testMissingFileLeavesThePayloadSound() {
        SharedSounds.publish(defaultFile: "classic_siren.caf", perTopicFiles: ["prod": "user_1.caf"], to: defaults)
        XCTAssertNil(SharedSounds.fileName(forTopic: "prod", defaults: defaults) { _ in false })
    }

    func testNothingPublishedLeavesThePayloadSound() {
        XCTAssertNil(SharedSounds.fileName(forTopic: "prod", defaults: defaults) { _ in true })
        XCTAssertNil(SharedSounds.fileName(forTopic: "prod", defaults: nil) { _ in true })
    }
}
