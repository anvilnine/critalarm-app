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
}
