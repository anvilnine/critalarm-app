import UIKit
import UserNotifications
import XCTest

/// Answers every request with the next scripted status, and keeps what it
/// was asked.
final class CheckRelayStub: URLProtocol {
    /// One status per request, in order. The last one repeats. Nil hangs
    /// until the session times out.
    static var statuses: [Int?] = [200]
    static var body = #"{"counted":true,"next_due_at":1760404800,"notice_after":1761096000}"#
    static var requests: [URLRequest] = []
    static var bodies: [Data] = []

    static func reset() {
        statuses = [200]
        body = #"{"counted":true,"next_due_at":1760404800,"notice_after":1761096000}"#
        requests = []
        bodies = []
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let index = min(Self.requests.count, Self.statuses.count - 1)
        Self.requests.append(request)
        Self.bodies.append(Self.read(request))
        guard let status = Self.statuses[index], let url = request.url else { return }
        let response = HTTPURLResponse(
            url: url, statusCode: status, httpVersion: nil, headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(Self.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    /// URLSession hands a protocol the body as a stream.
    private static func read(_ request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

/// The weekly check push (api.md §5.4) and its receipt (api.md §4.5).
final class WeeklyCheckTests: XCTestCase {
    private let suite = "weekly-check-tests"
    private var defaults: UserDefaults!
    private let device = RelayDevice(
        relay: URL(string: "https://relay.example.test")!,
        deviceId: "dev_3f2a",
        deviceToken: "dv_test"
    )

    /// The APNs payload of api.md §5.4, as the app receives it.
    private let checkPayload: [AnyHashable: Any] = [
        "aps": ["content-available": 1],
        "kind": "check",
        "check_id": "chk_5c1d",
        "attempt": 1,
    ]

    /// An alarm push, api.md §5.1.
    private let alarmPayload: [AnyHashable: Any] = [
        "aps": [
            "alert": ["title": "Crit Alarm", "body": "Critical alert on prod"],
            "sound": "alarm.caf",
            "interruption-level": "time-sensitive",
            "mutable-content": 1,
            "content-available": 1,
            "category": "INCIDENT",
        ],
        "incident_id": "inc_9a8b7c",
        "server": "https://alerts.example.com",
        "kind": "open",
        "ring_until": 1757464200,
    ]

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
        CheckRelayStub.reset()
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private func stubbedSession(timeout: TimeInterval = 5) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CheckRelayStub.self]
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        return URLSession(configuration: configuration)
    }

    private func answer(
        _ push: CheckPush,
        device: RelayDevice?,
        timeout: TimeInterval = 5
    ) -> Bool {
        let done = expectation(description: "answered")
        var sent = false
        WeeklyCheckResponder.answer(
            push,
            device: device,
            urlSession: stubbedSession(timeout: timeout),
            defaults: defaults,
            delays: [0, 0.05, 0.05],
            now: { Date(timeIntervalSince1970: 1_759_800_004) }
        ) { ok in
            sent = ok
            done.fulfill()
        }
        wait(for: [done], timeout: 3 * timeout + 5)
        return sent
    }

    private func record() throws -> [String: Any] {
        let raw = try XCTUnwrap(defaults.string(forKey: WeeklyCheckResponder.arrivalKey))
        return try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any]
        )
    }

    // MARK: - Which pushes are a check

    func testTheContractPayloadParsesAsACheck() throws {
        let push = try XCTUnwrap(CheckPush(payload: checkPayload))
        XCTAssertEqual(push.checkId, "chk_5c1d")
        XCTAssertEqual(push.attempt, 1)
    }

    func testAttemptIsANoteAndMayBeMissingOrAString() throws {
        var payload = checkPayload
        payload["attempt"] = "2"
        XCTAssertEqual(CheckPush(payload: payload)?.attempt, 2)
        payload["attempt"] = nil
        let push = try XCTUnwrap(CheckPush(payload: payload))
        XCTAssertNil(push.attempt)
    }

    func testACheckWithNoIdCannotBeAnswered() {
        var payload = checkPayload
        payload["check_id"] = nil
        XCTAssertNil(CheckPush(payload: payload))
        payload["check_id"] = ""
        XCTAssertNil(CheckPush(payload: payload))
    }

    func testNoIncidentPushIsACheck() {
        XCTAssertNil(CheckPush(payload: alarmPayload))
        for kind in ["open", "repeat", "reopen", "p4", "ack", "close", "expire", "survey"] {
            var payload = alarmPayload
            payload["kind"] = kind
            // An id alone does not make one.
            payload["check_id"] = "chk_1"
            XCTAssertNil(CheckPush(payload: payload), kind)
        }
        XCTAssertNil(CheckPush(payload: [:]))
    }

    func testAnAlarmPushStillParsesAsTheAlarmItIs() throws {
        let push = try XCTUnwrap(IncidentPush(payload: alarmPayload))
        XCTAssertEqual(push.kind, .open)
        XCTAssertEqual(push.priority, 5)
        XCTAssertEqual(push.incidentId, "inc_9a8b7c")
        XCTAssertEqual(
            AlarmScheduleRule.ringingIncidentId(push: push, acked: [], heldByQuietHours: false),
            "inc_9a8b7c"
        )
    }

    /// What a build from before the check does with one: ignores it.
    func testACheckIsNothingToTheIncidentParser() {
        XCTAssertNil(IncidentPush(payload: checkPayload))
        XCTAssertNil(
            AlarmScheduleRule.ringingIncidentId(
                push: IncidentPush(payload: checkPayload), acked: [], heldByQuietHours: false
            )
        )
    }

    func testTheIdOfACheckStaysOutOfItsTextForm() throws {
        let push = try XCTUnwrap(CheckPush(payload: checkPayload))
        XCTAssertFalse("\(push)".contains("chk_5c1d"))
        XCTAssertFalse(String(describing: push).contains("chk_5c1d"))
    }

    // MARK: - The request

    func testTheRequestIsTheOneTheContractDescribes() throws {
        let push = try XCTUnwrap(CheckPush(payload: checkPayload))
        let request = WeeklyCheckResponder.request(
            device: device, push: push, receivedAt: 1_759_800_004
        )
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(
            request.url?.absoluteString,
            "https://relay.example.test/relay/v1/devices/dev_3f2a/checks/chk_5c1d/receipt"
        )
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer dv_test")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let body = try XCTUnwrap(
            JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any]
        )
        XCTAssertEqual(body["attempt"] as? Int, 1)
        XCTAssertEqual(body["received_at"] as? Int, 1_759_800_004)
        XCTAssertEqual(Set(body.keys), ["attempt", "received_at"])
    }

    func testAPushWithNoAttemptSendsNone() throws {
        let request = WeeklyCheckResponder.request(
            device: device, push: CheckPush(checkId: "chk_1", attempt: nil), receivedAt: 10
        )
        let body = try XCTUnwrap(
            JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any]
        )
        XCTAssertEqual(Set(body.keys), ["received_at"])
    }

    func testARelayUnderAPathKeepsItsPath() {
        let under = RelayDevice(
            relay: URL(string: "http://127.0.0.1:8787/base/")!,
            deviceId: "dev_3f2a",
            deviceToken: "dv_test"
        )
        let request = WeeklyCheckResponder.request(
            device: under, push: CheckPush(checkId: "chk_5c1d", attempt: 1), receivedAt: 10
        )
        XCTAssertEqual(
            request.url?.absoluteString,
            "http://127.0.0.1:8787/base/relay/v1/devices/dev_3f2a/checks/chk_5c1d/receipt"
        )
    }

    // MARK: - Where the credential comes from

    func testTheRelayComesFromTheSessionAndTheDeviceFromItsOwnItem() {
        let parsed = RelayDevice.parse(
            apiSession: "https://alerts.example.com|https://relay.example.test|selfhosted|ad_secret",
            identityJSON: #"{"device_id":"dev_3f2a","device_token":"dv_test","account_id":"acc_1"}"#
        )
        XCTAssertEqual(parsed, device)
    }

    func testWithAnyPartMissingThereIsNobodyToAnswer() {
        let session = "https://a.example|https://relay.example.test|hosted|dv_test"
        let identity = #"{"device_id":"dev_1","device_token":"dv_test"}"#
        XCTAssertNil(RelayDevice.parse(apiSession: nil, identityJSON: identity))
        XCTAssertNil(RelayDevice.parse(apiSession: "https://a.example", identityJSON: identity))
        XCTAssertNil(
            RelayDevice.parse(apiSession: "https://a.example|ftp://relay|hosted|x", identityJSON: identity)
        )
        XCTAssertNil(RelayDevice.parse(apiSession: session, identityJSON: nil))
        XCTAssertNil(RelayDevice.parse(apiSession: session, identityJSON: #"{"device_id":"dev_1"}"#))
        XCTAssertNil(
            RelayDevice.parse(
                apiSession: session, identityJSON: #"{"device_id":"dev_1","device_token":" "}"#
            )
        )
        XCTAssertNil(RelayDevice.parse(apiSession: session, identityJSON: "not json"))
    }

    // MARK: - Rules

    func testOnlyNoAnswerAndAServerErrorAreTriedAgain() {
        XCTAssertTrue(WeeklyCheckResponder.shouldRetry(status: nil))
        XCTAssertTrue(WeeklyCheckResponder.shouldRetry(status: 500))
        XCTAssertTrue(WeeklyCheckResponder.shouldRetry(status: 503))
        XCTAssertTrue(WeeklyCheckResponder.shouldRetry(status: 429))
        for status in [200, 401, 403, 404] {
            XCTAssertFalse(WeeklyCheckResponder.shouldRetry(status: status), "\(status)")
        }
    }

    func testThreeTriesFitInsideABackgroundPush() {
        XCTAssertEqual(WeeklyCheckResponder.tryDelays.count, 3)
        XCTAssertEqual(WeeklyCheckResponder.tryDelays.first, 0)
        let worst = WeeklyCheckResponder.tryDelays.reduce(0, +) + 3 * WeeklyCheckResponder.timeout
        XCTAssertLessThan(worst, 30)
    }

    func testTheAnswerIsRead() {
        XCTAssertEqual(
            WeeklyCheckResponder.parseAnswer(
                Data(#"{ "counted":true, "next_due_at":1760404800, "notice_after":1761096000 }"#.utf8)
            ),
            WeeklyCheckResponder.Answer(
                counted: true, nextDueAt: 1_760_404_800, noticeAfter: 1_761_096_000
            )
        )
        XCTAssertEqual(
            WeeklyCheckResponder.parseAnswer(
                Data(#"{"counted":false,"next_due_at":null,"notice_after":null}"#.utf8)
            ),
            WeeklyCheckResponder.Answer(counted: false, nextDueAt: nil, noticeAfter: nil)
        )
        XCTAssertNil(WeeklyCheckResponder.parseAnswer(Data("not json".utf8)))
        XCTAssertNil(WeeklyCheckResponder.parseAnswer(Data(#"{"error":"not found"}"#.utf8)))
        XCTAssertNil(WeeklyCheckResponder.parseAnswer(nil))
    }

    // MARK: - Answering

    func testACheckIsAnsweredWithOneReceiptAndTheAnswerIsKept() throws {
        let push = try XCTUnwrap(CheckPush(payload: checkPayload))
        XCTAssertTrue(answer(push, device: device))

        XCTAssertEqual(CheckRelayStub.requests.count, 1)
        let request = try XCTUnwrap(CheckRelayStub.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/relay/v1/devices/dev_3f2a/checks/chk_5c1d/receipt")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer dv_test")
        let body = try XCTUnwrap(
            JSONSerialization.jsonObject(with: XCTUnwrap(CheckRelayStub.bodies.first)) as? [String: Any]
        )
        XCTAssertEqual(body["attempt"] as? Int, 1)
        XCTAssertEqual(body["received_at"] as? Int, 1_759_800_004)

        let kept = try record()
        XCTAssertEqual(kept["received_at"] as? Int, 1_759_800_004)
        XCTAssertEqual(kept["notice_after"] as? Int, 1_761_096_000)
        XCTAssertEqual(kept["notice_after_seen_at"] as? Int, 1_759_800_004)
        XCTAssertEqual(kept["next_due_at"] as? Int, 1_760_404_800)
        // The id of the check is never written down.
        XCTAssertEqual(
            Set(kept.keys), ["received_at", "notice_after", "notice_after_seen_at", "next_due_at"]
        )
        let raw = try XCTUnwrap(defaults.string(forKey: WeeklyCheckResponder.arrivalKey))
        XCTAssertFalse(raw.contains("chk_5c1d"))
    }

    func testAFailedReceiptIsTriedAgainAndThenLands() throws {
        CheckRelayStub.statuses = [503, 503, 200]
        let push = try XCTUnwrap(CheckPush(payload: checkPayload))
        XCTAssertTrue(answer(push, device: device))
        XCTAssertEqual(CheckRelayStub.requests.count, 3)
    }

    func testAfterThreeTriesTheReceiptIsDropped() throws {
        CheckRelayStub.statuses = [503]
        let push = try XCTUnwrap(CheckPush(payload: checkPayload))
        XCTAssertFalse(answer(push, device: device))
        XCTAssertEqual(CheckRelayStub.requests.count, 3)
        // The arrival is still recorded: the push did reach this phone.
        let kept = try record()
        XCTAssertEqual(kept["received_at"] as? Int, 1_759_800_004)
        XCTAssertNil(kept["notice_after"])
    }

    func testARelayThatDoesNotAnswerIsGivenUpOn() throws {
        CheckRelayStub.statuses = [nil]
        let push = try XCTUnwrap(CheckPush(payload: checkPayload))
        XCTAssertFalse(answer(push, device: device, timeout: 0.5))
        XCTAssertEqual(CheckRelayStub.requests.count, 3)
    }

    func testAnAnswerThatIsFinalIsNotAskedAgain() throws {
        for status in [404, 401] {
            CheckRelayStub.reset()
            CheckRelayStub.statuses = [status]
            let push = try XCTUnwrap(CheckPush(payload: checkPayload))
            XCTAssertFalse(answer(push, device: device), "\(status)")
            XCTAssertEqual(CheckRelayStub.requests.count, 1, "\(status)")
        }
    }

    func testTheSamePushTwiceIsAnsweredTwice() throws {
        let push = try XCTUnwrap(CheckPush(payload: checkPayload))
        XCTAssertTrue(answer(push, device: device))
        XCTAssertTrue(answer(push, device: device))
        XCTAssertEqual(CheckRelayStub.requests.count, 2)
        XCTAssertEqual(CheckRelayStub.requests[0].url, CheckRelayStub.requests[1].url)
    }

    func testWithNoCredentialNothingIsSent() throws {
        let push = try XCTUnwrap(CheckPush(payload: checkPayload))
        XCTAssertFalse(answer(push, device: nil))
        XCTAssertTrue(CheckRelayStub.requests.isEmpty)
        XCTAssertEqual(try record()["received_at"] as? Int, 1_759_800_004)
    }

    func testALateAnswerKeepsWhatAnEarlierOneLeft() {
        let first = WeeklyCheckResponder.withAnswer(
            existing: WeeklyCheckResponder.withArrival(existing: nil, receivedAt: 100),
            answer: .init(counted: true, nextDueAt: 700, noticeAfter: 900),
            now: 101
        )
        let late = WeeklyCheckResponder.withAnswer(
            existing: WeeklyCheckResponder.withArrival(existing: first, receivedAt: 800),
            answer: .init(counted: false, nextDueAt: nil, noticeAfter: nil),
            now: 801
        )
        let json = try? JSONSerialization.jsonObject(with: Data(late.utf8)) as? [String: Any]
        XCTAssertEqual(json?["received_at"] as? Int, 800)
        XCTAssertEqual(json?["notice_after"] as? Int, 900)
        XCTAssertEqual(json?["notice_after_seen_at"] as? Int, 101)
    }

    // MARK: - What a check leaves alone

    private func notificationCounts() -> (pending: Int, delivered: Int) {
        let center = UNUserNotificationCenter.current()
        let loaded = expectation(description: "notifications")
        loaded.expectedFulfillmentCount = 2
        var pending = 0
        var delivered = 0
        center.getPendingNotificationRequests { requests in
            pending = requests.count
            loaded.fulfill()
        }
        center.getDeliveredNotifications { notifications in
            delivered = notifications.count
            loaded.fulfill()
        }
        wait(for: [loaded], timeout: 5)
        return (pending, delivered)
    }

    func testACheckPostsNoNotificationAndTouchesNoAlarmState() throws {
        let acked = AckedIncidentStore.all()
        let ackQueue = AckQueueStore.pendingCount()
        let events = PushEventLog.recent().count
        let before = notificationCounts()

        let push = try XCTUnwrap(CheckPush(payload: checkPayload))
        XCTAssertTrue(answer(push, device: device))

        let after = notificationCounts()
        XCTAssertEqual(after.pending, before.pending)
        XCTAssertEqual(after.delivered, before.delivered)
        XCTAssertEqual(AckedIncidentStore.all(), acked)
        XCTAssertEqual(AckQueueStore.pendingCount(), ackQueue)
        XCTAssertEqual(PushEventLog.recent().count, events)
        // The one thing written is the weekly check's own record, in the
        // suite this test handed over. Nothing landed in the app's own
        // preferences or in the group the extension shares.
        XCTAssertNil(PushEventLog.groupDefaults?.object(forKey: WeeklyCheckResponder.arrivalKey))
    }

    // MARK: - Through the app's own background handler

    /// Calls the real `application(_:didReceiveRemoteNotification:)` of the
    /// app hosting these tests, the way iOS does for a background push.
    ///
    /// Other code in the app sits on the same delegate call and can hold
    /// the completion handler back, so a callback is waited for briefly and
    /// not required. What the handler did is read off what it left behind.
    private func deliver(_ payload: [AnyHashable: Any]) {
        let done = XCTestExpectation(description: "handler completed")
        let app = UIApplication.shared
        let selector = #selector(
            UIApplicationDelegate.application(_:didReceiveRemoteNotification:fetchCompletionHandler:)
        )
        guard let delegate = app.delegate, delegate.responds(to: selector) else {
            XCTFail("the app delegate has no background push handler")
            return
        }
        delegate.application?(app, didReceiveRemoteNotification: payload) { _ in
            done.fulfill()
        }
        _ = XCTWaiter().wait(for: [done], timeout: 3)
    }

    /// With no saved session the handler has nobody to answer, so it records
    /// the arrival and sends nothing. The recorded arrival is what shows the
    /// check branch ran: the incident path writes no such record.
    func testTheAppHandlerTakesTheCheckBranchForACheck() throws {
        let standard = UserDefaults.standard
        let savedSession = standard.string(forKey: RelayDevice.apiSessionKey)
        let savedRecord = standard.string(forKey: WeeklyCheckResponder.arrivalKey)
        standard.removeObject(forKey: RelayDevice.apiSessionKey)
        standard.removeObject(forKey: WeeklyCheckResponder.arrivalKey)
        defer {
            standard.set(savedSession, forKey: RelayDevice.apiSessionKey)
            standard.set(savedRecord, forKey: WeeklyCheckResponder.arrivalKey)
        }
        let before = notificationCounts()
        let acked = AckedIncidentStore.all()

        deliver(checkPayload)

        let raw = try XCTUnwrap(standard.string(forKey: WeeklyCheckResponder.arrivalKey))
        let kept = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any]
        )
        XCTAssertNotNil(kept["received_at"])
        XCTAssertFalse(raw.contains("chk_5c1d"))
        let after = notificationCounts()
        XCTAssertEqual(after.pending, before.pending)
        XCTAssertEqual(after.delivered, before.delivered)
        XCTAssertEqual(AckedIncidentStore.all(), acked)
    }

    /// A forward with no incident id goes down the incident path, which
    /// ignores it. No weekly check record appears.
    func testTheAppHandlerLeavesAnIncidentPushToTheIncidentPath() {
        let standard = UserDefaults.standard
        let savedRecord = standard.string(forKey: WeeklyCheckResponder.arrivalKey)
        standard.removeObject(forKey: WeeklyCheckResponder.arrivalKey)
        defer { standard.set(savedRecord, forKey: WeeklyCheckResponder.arrivalKey) }

        let forward: [AnyHashable: Any] = [
            "aps": ["alert": ["title": "Disk at 91%", "body": "db01"], "content-available": 1],
            "server": "https://alerts.example.com",
            "kind": "p4",
        ]
        deliver(forward)
        XCTAssertNil(standard.string(forKey: WeeklyCheckResponder.arrivalKey))
    }
}
