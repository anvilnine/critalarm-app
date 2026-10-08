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

    /// The cache the extension reads instead of the network. Held in its own
    /// suite so a test never touches the app group on the machine.
    private let cacheSuite = "NotificationServiceTestsCache"
    private var cacheDefaults: UserDefaults!
    private var realCacheDefaults: UserDefaults?

    override func setUp() {
        super.setUp()
        cacheDefaults = UserDefaults(suiteName: cacheSuite)
        cacheDefaults.removePersistentDomain(forName: cacheSuite)
        realCacheDefaults = IncidentContentCache.defaults
        IncidentContentCache.defaults = cacheDefaults
    }

    override func tearDown() {
        NseCredentials.clear()
        IncidentContentCache.defaults = realCacheDefaults
        cacheDefaults.removePersistentDomain(forName: cacheSuite)
        StubIncidentServer.stop()
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
        try run(payload: try fixture(name), named: name, timeout: timeout)
    }

    @discardableResult
    private func run(
        payload: [String: Any],
        named name: String = "push",
        timeout: TimeInterval = 20
    ) throws -> UNNotificationContent {
        // The system holds the extension while the fetch is in flight. Hold it
        // here too, or the callback finds a deallocated `self` and the
        // notification is never delivered.
        let service = NotificationService()
        let delivered = expectation(description: "\(name) delivered")
        var result: UNNotificationContent?
        service.didReceive(request(from: payload)) { content in
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

    // MARK: - The content cache

    /// A hosted push with no text in it, of whichever kind the test needs.
    private func hostedPush(kind: String, incidentId: String = "inc_cache") -> [String: Any] {
        [
            "aps": [
                "alert": ["title": "Crit Alarm", "body": "Critical alert, open to see details"],
                "mutable-content": 1,
            ],
            "kind": kind,
            "incident_id": incidentId,
            "server": "https://api.example.test",
        ]
    }

    /// What `GET /v1/incidents/{id}` answers (api.md §3.2).
    private var serverIncident: Data {
        let incident: [String: Any] = [
            "id": "inc_cache",
            "topic": "prod-db",
            "state": "open",
            "last_message_at": 1_700_000_000,
            "messages": [[
                "id": "msg_1",
                "topic": "prod-db",
                "title": "Database down",
                "message": "db01 is unreachable",
                "priority": 5,
                "tags": [],
                "time": 1_700_000_000,
            ]],
        ]
        return try! JSONSerialization.data(withJSONObject: incident)
    }

    private func warmTheCache(title: String = "Cached title", body: String = "Cached body") {
        IncidentContentCache.write(
            IncidentContent(title: title, body: body, tags: [], click: nil, topic: "prod-db"),
            for: "inc_cache"
        )
    }

    func testARepeatWithAWarmCacheCallsNobody() throws {
        NseCredentials.write(server: "https://api.example.test", token: "dv_test")
        warmTheCache()
        StubIncidentServer.start(body: serverIncident)

        let content = try run(payload: hostedPush(kind: "repeat"))

        XCTAssertEqual(StubIncidentServer.requestCount, 0, "the repeat is what the cache is for")
        XCTAssertEqual(content.title, "Cached title")
        XCTAssertEqual(content.body, "Cached body")
    }

    func testAnOpenPushWithAWarmCacheStillAsksTheServer() throws {
        NseCredentials.write(server: "https://api.example.test", token: "dv_test")
        warmTheCache()
        StubIncidentServer.start(body: serverIncident)

        let content = try run(payload: hostedPush(kind: "open"))

        XCTAssertEqual(StubIncidentServer.requestCount, 1, "a new message may have joined")
        XCTAssertEqual(content.title, "Database down")
        XCTAssertEqual(content.body, "db01 is unreachable")
    }

    func testARepeatWithAColdCacheFetchesAndWarmsIt() throws {
        NseCredentials.write(server: "https://api.example.test", token: "dv_test")
        StubIncidentServer.start(body: serverIncident)

        let content = try run(payload: hostedPush(kind: "repeat"))

        XCTAssertEqual(StubIncidentServer.requestCount, 1)
        XCTAssertEqual(content.body, "db01 is unreachable")

        let entry = IncidentContentCache.read(incidentId: "inc_cache")
        XCTAssertEqual(entry?.content.title, "Database down")
        XCTAssertEqual(entry?.lastMessageAt, 1_700_000_000)
    }

    func testARepeatWithAWarmCacheAndNoServerShowsTheRealText() throws {
        NseCredentials.write(server: "https://api.example.test", token: "dv_test")
        warmTheCache()
        StubIncidentServer.start(body: nil)

        let content = try run(payload: hostedPush(kind: "repeat"))

        XCTAssertEqual(StubIncidentServer.requestCount, 0)
        XCTAssertEqual(content.body, "Cached body", "not the placeholder")
    }

    func testAFailedFetchWithAWarmCacheShowsTheRealText() throws {
        NseCredentials.write(server: "https://api.example.test", token: "dv_test")
        warmTheCache()
        StubIncidentServer.start(body: nil)

        let content = try run(payload: hostedPush(kind: "open"))

        XCTAssertEqual(StubIncidentServer.requestCount, 1, "an open push always tries")
        XCTAssertEqual(content.title, "Cached title")
        XCTAssertEqual(content.body, "Cached body", "not the placeholder")
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

    func testAMissingPackSoundPlaysTheClassicSiren() {
        SharedSounds.publish(defaultFile: "classic_siren.caf", perTopicFiles: ["prod": "pack_library_boxing_bell.caf"], to: defaults)
        let name = SharedSounds.fileName(forTopic: "prod", defaults: defaults) { $0 == "classic_siren.caf" }
        XCTAssertEqual(name, "classic_siren.caf")
    }

    func testATopicWhosePackSoundIsGonePlaysTheDefault() {
        SharedSounds.publish(defaultFile: "pager_beep.caf", perTopicFiles: ["prod": "pack_library_boxing_bell.caf"], to: defaults)
        let name = SharedSounds.fileName(forTopic: "prod", defaults: defaults) { $0 != "pack_library_boxing_bell.caf" }
        XCTAssertEqual(name, "pager_beep.caf")
    }

    func testAPackSoundOnDiskPlaysItself() {
        SharedSounds.publish(defaultFile: "pack_library_boxing_bell.caf", perTopicFiles: [:], to: defaults)
        XCTAssertEqual(SharedSounds.fileName(forTopic: nil, defaults: defaults) { _ in true }, "pack_library_boxing_bell.caf")
    }

    func testAMissingPackSoundWithNoFallbackLeavesThePayloadSound() {
        SharedSounds.publish(defaultFile: "pack_library_boxing_bell.caf", perTopicFiles: [:], to: defaults)
        XCTAssertNil(SharedSounds.fileName(forTopic: nil, defaults: defaults) { _ in false })
    }

    func testNoDefaultClearsAnOldOne() {
        SharedSounds.publish(defaultFile: "classic_siren.caf", perTopicFiles: [:], to: defaults)
        SharedSounds.publish(defaultFile: nil, perTopicFiles: [:], to: defaults)
        XCTAssertNil(SharedSounds.fileName(forTopic: "prod", defaults: defaults) { _ in true })
    }

    func testThirtySecondsOrMoreDoesNotRing() {
        XCTAssertTrue(SharedSounds.ringsOnIphone(durationMs: 29_999))
        XCTAssertFalse(SharedSounds.ringsOnIphone(durationMs: 30_000))
    }

    func testNothingPublishedLeavesThePayloadSound() {
        XCTAssertNil(SharedSounds.fileName(forTopic: "prod", defaults: defaults) { _ in true })
        XCTAssertNil(SharedSounds.fileName(forTopic: "prod", defaults: nil) { _ in true })
    }
}

/// What rings while own sounds are locked. The same cases as
/// test/core/sound/own_sound_rule_test.dart, run on the three things iOS
/// has: what the app publishes, what the extension resolves, and the name
/// the AlarmKit alarm is handed.
final class OwnSoundLockTests: XCTestCase {
    private let suite = "app.critalarm.tests.own-sound-lock"
    private var defaults: UserDefaults!

    private let own = "user_1700000000000000"
    private let otherOwn = "user_1700000000000001"
    private let pack = "pack_library_boxing_bell"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    /// Publishes the saved ids the way the app does, every file ringable.
    private func publish(defaultId: String?, perTopic: [String: String], ownLocked: Bool) {
        let choices = SharedSounds.choicesToPublish(
            defaultId: defaultId,
            perTopicIds: perTopic,
            ownLocked: ownLocked,
            ringableFileName: SharedSounds.fileNameFor(soundID:)
        )
        SharedSounds.publish(
            defaultFile: choices.defaultFile,
            perTopicFiles: choices.perTopicFiles,
            ownLocked: ownLocked,
            to: defaults
        )
    }

    /// What the extension plays, with every file on disk.
    private func rings(_ topic: String?) -> String? {
        SharedSounds.fileName(forTopic: topic, defaults: defaults) { _ in true }
    }

    // What the app publishes.

    func testOpenPublishesOwnSoundsAsBefore() {
        let choices = SharedSounds.choicesToPublish(
            defaultId: own,
            perTopicIds: ["prod": otherOwn, "staging": "pager_beep"],
            ownLocked: false,
            ringableFileName: SharedSounds.fileNameFor(soundID:)
        )
        XCTAssertEqual(choices.defaultFile, "\(own).caf")
        XCTAssertEqual(choices.perTopicFiles, ["prod": "\(otherOwn).caf", "staging": "pager_beep.caf"])
    }

    func testLockedPublishesNoOwnFile() {
        let choices = SharedSounds.choicesToPublish(
            defaultId: own,
            perTopicIds: ["prod": otherOwn, "staging": "pager_beep", "web": pack],
            ownLocked: true,
            ringableFileName: SharedSounds.fileNameFor(soundID:)
        )
        XCTAssertEqual(choices.defaultFile, "classic_siren.caf")
        XCTAssertEqual(choices.perTopicFiles, ["staging": "pager_beep.caf", "web": "\(pack).caf"])
    }

    func testLockedKeepsABuiltInDefault() {
        let choices = SharedSounds.choicesToPublish(
            defaultId: "pager_beep",
            perTopicIds: ["prod": own],
            ownLocked: true,
            ringableFileName: SharedSounds.fileNameFor(soundID:)
        )
        XCTAssertEqual(choices.defaultFile, "pager_beep.caf")
        XCTAssertEqual(choices.perTopicFiles, [:])
    }

    func testLockedAnOwnDefaultTooLongToRingStillBecomesTheClassicSiren() {
        let choices = SharedSounds.choicesToPublish(
            defaultId: own, perTopicIds: [:], ownLocked: true, ringableFileName: { _ in nil }
        )
        XCTAssertEqual(choices.defaultFile, "classic_siren.caf")
    }

    func testNoDefaultSavedPublishesNoneLockedOrOpen() {
        for locked in [true, false] {
            let choices = SharedSounds.choicesToPublish(
                defaultId: nil, perTopicIds: [:], ownLocked: locked,
                ringableFileName: SharedSounds.fileNameFor(soundID:)
            )
            XCTAssertNil(choices.defaultFile)
            XCTAssertEqual(choices.perTopicFiles, [:])
        }
    }

    // What the extension rings.

    func testOpenAnOwnTopicSoundRings() {
        publish(defaultId: "pager_beep", perTopic: ["prod": own], ownLocked: false)
        XCTAssertEqual(rings("prod"), "\(own).caf")
        XCTAssertEqual(rings("staging"), "pager_beep.caf")
    }

    func testLockedAnOwnTopicSoundRingsTheBuiltInDefault() {
        publish(defaultId: "pager_beep", perTopic: ["prod": own], ownLocked: true)
        XCTAssertEqual(rings("prod"), "pager_beep.caf")
        XCTAssertEqual(rings(nil), "pager_beep.caf")
    }

    func testLockedAnOwnDefaultRingsTheClassicSiren() {
        publish(defaultId: own, perTopic: ["prod": "pager_beep"], ownLocked: true)
        XCTAssertEqual(rings(nil), "classic_siren.caf")
        XCTAssertEqual(rings("staging"), "classic_siren.caf")
        XCTAssertEqual(rings("prod"), "pager_beep.caf")
    }

    func testLockedOwnOnTheTopicAndAsTheDefaultRingsTheClassicSiren() {
        publish(defaultId: otherOwn, perTopic: ["prod": own], ownLocked: true)
        XCTAssertEqual(rings("prod"), "classic_siren.caf")
        XCTAssertEqual(rings(nil), "classic_siren.caf")
    }

    func testOpenAgainTheSameChoicesRingTheirOwnSounds() {
        publish(defaultId: otherOwn, perTopic: ["prod": own], ownLocked: true)
        publish(defaultId: otherOwn, perTopic: ["prod": own], ownLocked: false)
        XCTAssertEqual(rings("prod"), "\(own).caf")
        XCTAssertEqual(rings(nil), "\(otherOwn).caf")
    }

    func testNoOwnSoundAnywhereRingsTheSameLockedOrOpen() {
        for locked in [true, false] {
            publish(defaultId: "pager_beep", perTopic: ["prod": pack], ownLocked: locked)
            XCTAssertEqual(rings("prod"), "\(pack).caf")
            XCTAssertEqual(rings(nil), "pager_beep.caf")
        }
    }

    /// Own files published before the lock, with only the flag set since.
    func testTheFlagAloneKeepsAnOwnFileFromRinging() {
        SharedSounds.publish(
            defaultFile: "pager_beep.caf",
            perTopicFiles: ["prod": "\(own).caf"],
            ownLocked: true,
            to: defaults
        )
        XCTAssertEqual(rings("prod"), "pager_beep.caf")

        SharedSounds.publish(
            defaultFile: "\(otherOwn).caf",
            perTopicFiles: ["prod": "\(own).caf"],
            ownLocked: true,
            to: defaults
        )
        XCTAssertEqual(rings("prod"), "classic_siren.caf")
        XCTAssertEqual(rings(nil), "classic_siren.caf")
    }

    func testNoFlagPublishedIsNotLocked() {
        defaults.set("\(own).caf", forKey: SharedSounds.defaultFileKey)
        XCTAssertFalse(OwnSoundLock.isLocked(in: defaults))
        XCTAssertFalse(OwnSoundLock.isLocked(in: nil))
        XCTAssertEqual(rings(nil), "\(own).caf")
    }

    func testAFlagThatIsNotABooleanIsNotLocked() {
        defaults.set(["not": "a boolean"], forKey: OwnSoundLock.groupKey)
        XCTAssertFalse(OwnSoundLock.isLocked(in: defaults))
    }

    /// Every way out of a locked own sound is a file that ships in the app:
    /// the next choice, then the classic siren, then nil, which leaves the
    /// payload's `alarm.caf` in place.
    func testLockedWithNothingOnDiskLeavesThePayloadSound() {
        publish(defaultId: otherOwn, perTopic: ["prod": own], ownLocked: true)
        XCTAssertNil(SharedSounds.fileName(forTopic: "prod", defaults: defaults) { _ in false })
    }

    func testLockedNeverRingsAnOwnFileWhateverIsSaved() {
        let ids = [own, otherOwn, "pager_beep", pack, "classic_siren"]
        for defaultId in ids {
            for topicId in ids {
                publish(defaultId: defaultId, perTopic: ["prod": topicId], ownLocked: true)
                for topic in [nil, "prod", "other"] as [String?] {
                    let name = rings(topic)
                    XCTAssertNotNil(name, "\(defaultId) \(topicId)")
                    XCTAssertFalse(OwnSoundLock.isOwn(name ?? ""), "\(defaultId) \(topicId)")
                }
            }
        }
    }

    // The name the AlarmKit alarm and the re-arm notification are handed.

    func testTheAlarmGetsTheBundledNameForALockedOwnSound() {
        XCTAssertEqual(
            OwnSoundLock.alarmSound(requested: "\(own).caf", ownLocked: true, bundled: "alarm.caf"),
            "alarm.caf"
        )
    }

    func testTheAlarmKeepsAnOwnSoundWhileOpen() {
        XCTAssertEqual(
            OwnSoundLock.alarmSound(requested: "\(own).caf", ownLocked: false, bundled: "alarm.caf"),
            "\(own).caf"
        )
    }

    func testTheAlarmKeepsABuiltInNameLockedOrOpen() {
        for locked in [true, false] {
            XCTAssertEqual(
                OwnSoundLock.alarmSound(requested: "pager_beep.caf", ownLocked: locked, bundled: "alarm.caf"),
                "pager_beep.caf"
            )
        }
    }

    func testTheAlarmAlwaysHasAName() {
        for locked in [true, false] {
            XCTAssertEqual(OwnSoundLock.alarmSound(requested: nil, ownLocked: locked, bundled: "alarm.caf"), "alarm.caf")
            XCTAssertEqual(OwnSoundLock.alarmSound(requested: "", ownLocked: locked, bundled: "alarm.caf"), "alarm.caf")
        }
    }

    func testTheBundledAlarmSoundShipsInTheApp() {
        let name = IncidentAlarmScheduler.soundName as NSString
        XCTAssertNotNil(
            Bundle.main.url(forResource: name.deletingPathExtension, withExtension: name.pathExtension),
            "\(name) is not in the app bundle"
        )
    }

    func testTheNamesMatchWhatDartWrites() {
        XCTAssertEqual(OwnSoundLock.appKey, "flutter.alarm_sound_own_locked")
        XCTAssertEqual(OwnSoundLock.ownPrefix, "user_")
        XCTAssertEqual(OwnSoundLock.appGroup, SharedSounds.appGroup)
        XCTAssertTrue(OwnSoundLock.isOwn("user_1700000000000000.caf"))
        XCTAssertFalse(OwnSoundLock.isOwn("classic_siren.caf"))
        XCTAssertFalse(OwnSoundLock.isOwn("pack_library_boxing_bell.caf"))
    }
}

/// Stands in for the server so a test can count what the extension asks for.
///
/// `IncidentContentFetcher` builds its own `URLSession`, and a custom session
/// does not consult the global `URLProtocol` registry, so this goes in through
/// `IncidentContentFetcher.extraProtocolClasses` instead.
final class StubIncidentServer: URLProtocol {
    /// The JSON to answer with, or nil to fail the way a dead server does.
    private static var body: Data?
    private static var count = 0
    private static let lock = NSLock()

    static var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    static func start(body: Data?) {
        lock.lock()
        count = 0
        self.body = body
        lock.unlock()
        IncidentContentFetcher.extraProtocolClasses = [StubIncidentServer.self]
    }

    static func stop() {
        lock.lock()
        count = 0
        body = nil
        lock.unlock()
        IncidentContentFetcher.extraProtocolClasses = []
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self.count += 1
        let body = Self.body
        Self.lock.unlock()

        guard let body, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
            return
        }
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
