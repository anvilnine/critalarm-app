import XCTest

/// Answers every request the way the test asks, or never answers at all.
final class StubURLProtocol: URLProtocol {
    /// Nil means hang until the session times out.
    static var status: Int? = 200
    static var requests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requests.append(request)
        guard let status = Self.status, let url = request.url else { return }
        let response = HTTPURLResponse(
            url: url, statusCode: status, httpVersion: nil, headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// The one native try at `POST /v1/incidents/{id}/ack` after Stop, and what it
/// does to the queue entry Dart would otherwise send.
final class NativeAckSenderTests: XCTestCase {
    private let queue = UserDefaults(suiteName: "native-ack-sender-tests")!
    private let session = NseCredentials.Session(
        server: URL(string: "https://api.example.test")!,
        token: "dv_test"
    )

    override func setUp() {
        super.setUp()
        queue.removeObject(forKey: AckQueueStore.key)
        StubURLProtocol.status = 200
        StubURLProtocol.requests = []
    }

    private func stubbedSession(timeout: TimeInterval = 5) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        return URLSession(configuration: configuration)
    }

    private func send(action: String = "ack", timeout: TimeInterval = 5) -> Bool {
        let done = expectation(description: "send finished")
        var settled = false
        NativeAckSender.send(
            action: action,
            incidentId: "inc_1",
            session: session,
            urlSession: stubbedSession(timeout: timeout),
            queue: queue
        ) { ok in
            settled = ok
            done.fulfill()
        }
        wait(for: [done], timeout: timeout + 5)
        return settled
    }

    func testA200RemovesTheQueueEntry() {
        AckQueueStore.enqueue(action: "ack", incidentId: "inc_1", defaults: queue)

        XCTAssertTrue(send())

        XCTAssertEqual(AckQueueStore.pendingCount(defaults: queue), 0)
    }

    func testA409RemovesTheQueueEntry() {
        StubURLProtocol.status = 409
        AckQueueStore.enqueue(action: "ack", incidentId: "inc_1", defaults: queue)

        XCTAssertTrue(send())

        XCTAssertEqual(AckQueueStore.pendingCount(defaults: queue), 0)
    }

    func testA503KeepsTheQueueEntry() {
        StubURLProtocol.status = 503
        AckQueueStore.enqueue(action: "ack", incidentId: "inc_1", defaults: queue)

        XCTAssertFalse(send())

        XCTAssertEqual(AckQueueStore.pendingCount(defaults: queue), 1)
    }

    func testATimeoutKeepsTheQueueEntry() {
        StubURLProtocol.status = nil
        AckQueueStore.enqueue(action: "ack", incidentId: "inc_1", defaults: queue)

        XCTAssertFalse(send(timeout: 1))

        XCTAssertEqual(AckQueueStore.pendingCount(defaults: queue), 1)
    }

    func testOnlyTheMatchingEntryIsRemoved() {
        AckQueueStore.enqueue(action: "ack", incidentId: "inc_1", defaults: queue)
        AckQueueStore.enqueue(action: "close", incidentId: "inc_1", defaults: queue)
        AckQueueStore.enqueue(action: "ack", incidentId: "inc_2", defaults: queue)

        XCTAssertTrue(send())

        XCTAssertEqual(AckQueueStore.pendingCount(defaults: queue), 2)
    }

    /// Same route, method and headers as `lib/core/api/http_api_client.dart`.
    func testTheRequestMatchesTheDartClient() throws {
        _ = send()

        let request = try XCTUnwrap(StubURLProtocol.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "https://api.example.test/v1/incidents/inc_1/ack")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer dv_test")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
    }

    func testCloseGoesToTheCloseRoute() throws {
        _ = send(action: "close")

        let request = try XCTUnwrap(StubURLProtocol.requests.first)
        XCTAssertEqual(request.url?.path, "/v1/incidents/inc_1/close")
    }

    func testNoCredentialsMeansNoRequestAndTheEntryStays() {
        AckQueueStore.enqueue(action: "ack", incidentId: "inc_1", defaults: queue)
        let done = expectation(description: "send finished")
        var settled = true
        NativeAckSender.send(
            action: "ack",
            incidentId: "inc_1",
            session: nil,
            urlSession: stubbedSession(),
            queue: queue
        ) { ok in
            settled = ok
            done.fulfill()
        }
        wait(for: [done], timeout: 5)

        XCTAssertFalse(settled)
        XCTAssertTrue(StubURLProtocol.requests.isEmpty)
        XCTAssertEqual(AckQueueStore.pendingCount(defaults: queue), 1)
    }

    func testOnlyAFinishedCloseEndsTheWidgetRow() {
        for status in [200, 204, 404, 410] {
            XCTAssertTrue(NativeAckSender.endsTheIncident(status: status), "\(status)")
        }
        // 409: not acked, maybe opened again. nil: no answer at all.
        XCTAssertFalse(NativeAckSender.endsTheIncident(status: 409))
        XCTAssertFalse(NativeAckSender.endsTheIncident(status: 500))
        XCTAssertFalse(NativeAckSender.endsTheIncident(status: nil))
    }
}

/// The one question Stop asks the server, and which answers take the ring
/// it just set away again.
final class RemoteStateCheckTests: XCTestCase {
    private func body(_ state: String) -> Data {
        Data(#"{"id":"inc_1","topic":"prod","state":"\#(state)","messages":[]}"#.utf8)
    }

    func testAckedClosedAndExpiredEndTheRing() {
        for state in ["acked", "closed", "expired"] {
            XCTAssertEqual(RemoteStateCheck.endingState(status: 200, body: body(state)), state)
        }
    }

    func testAnOpenIncidentKeepsTheRing() {
        XCTAssertNil(RemoteStateCheck.endingState(status: 200, body: body("open")))
    }

    func testAWordTheAppDoesNotKnowKeepsTheRing() {
        XCTAssertNil(RemoteStateCheck.endingState(status: 200, body: body("snoozed")))
        XCTAssertNil(RemoteStateCheck.endingState("ACKED"))
        XCTAssertNil(RemoteStateCheck.endingState(nil))
    }

    func testNoAnswerKeepsTheRing() {
        XCTAssertNil(RemoteStateCheck.endingState(status: nil, body: nil))
        XCTAssertNil(RemoteStateCheck.endingState(status: 500, body: body("acked")))
        XCTAssertNil(RemoteStateCheck.endingState(status: 404, body: nil))
        XCTAssertNil(RemoteStateCheck.endingState(status: 200, body: Data("not json".utf8)))
    }

    func testTheCheckIsAGetOnTheIncident() {
        let session = NseCredentials.Session(
            server: URL(string: "https://api.example.test")!,
            token: "dv_test"
        )
        let request = RemoteStateCheck.request(incidentId: "inc_1", session: session)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.absoluteString, "https://api.example.test/v1/incidents/inc_1")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer dv_test")
    }
}

/// Whether an answer about an incident may still end the ring this phone
/// holds: the ring generation it was asked under, and the serial step that
/// push arming and every guarded stop share.
final class RingGenerationTests: XCTestCase {
    func testAnAnswerForTheGenerationGoingNowStopsALiveRing() {
        XCTAssertEqual(RingGeneration.decide(expected: 4, current: 4, live: true), .stopped)
    }

    func testNothingLiveIsStillAnAcceptedAnswer() {
        XCTAssertEqual(RingGeneration.decide(expected: 4, current: 4, live: false), .nothing)
    }

    func testAPushThatArmedARingSinceWins() {
        XCTAssertEqual(RingGeneration.decide(expected: 4, current: 5, live: true), .refused)
    }

    func testAnAnswerWithNoGenerationNeverCounts() {
        XCTAssertEqual(RingGeneration.decide(expected: nil, current: 0, live: true), .refused)
    }

    func testTheOutcomeWordsMatchWhatDartReads() {
        XCTAssertEqual(RingGeneration.Outcome.stopped.rawValue, "stopped")
        XCTAssertEqual(RingGeneration.Outcome.nothing.rawValue, "nothing")
        XCTAssertEqual(RingGeneration.Outcome.refused.rawValue, "refused")
    }

    func testAPushMovesTheGenerationOnByOne() {
        let id = "inc_gen_\(UUID().uuidString)"
        let before = RingGeneration.current(incidentId: id)
        RingGeneration.bump(incidentId: id)
        XCTAssertEqual(RingGeneration.current(incidentId: id), before + 1)
    }

    func testTheCheckAnswerCarriesTheStage() {
        let body = Data(#"{"id":"inc_1","state":"acked","opened_at":1760000000}"#.utf8)
        let answer = RemoteStateCheck.answer(status: 200, body: body)
        XCTAssertEqual(answer?.state, "acked")
        XCTAssertEqual(answer?.openedAt, Date(timeIntervalSince1970: 1_760_000_000))
    }

    @MainActor
    func testOneStepRunsAtATime() async {
        var order: [String] = []
        let gate = AsyncGate()
        let first = Task { @MainActor in
            await AlarmSerial.shared.run {
                order.append("first starts")
                await gate.wait()
                order.append("first ends")
            }
        }
        await Task.yield()
        let second = Task { @MainActor in
            await AlarmSerial.shared.run { order.append("second") }
        }
        for _ in 0 ..< 5 { await Task.yield() }
        XCTAssertEqual(order, ["first starts"])
        await gate.open()
        await first.value
        await second.value
        XCTAssertEqual(order, ["first starts", "first ends", "second"])
    }
}

/// Holds a step until the test opens it.
actor AsyncGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        waiters.forEach { $0.resume() }
        waiters = []
    }
}
