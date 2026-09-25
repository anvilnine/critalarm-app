import Foundation

/// One try at telling the server from native code, right after Stop.
///
/// The queue entry is already on disk by the time this runs, so nothing is
/// lost if the try fails: Dart's `AckQueue` sends it with its own backoff on
/// the next launch. What this buys is the round trip. Without it the server
/// keeps repeating until Dart gets to run, which on a suspended app can be
/// minutes.
///
/// Same route, method and headers as `lib/core/api/http_api_client.dart`:
/// `POST {server}/v1/incidents/{id}/ack` or `/close`, `Authorization: Bearer
/// dv_...`, `Accept: application/json`. api.md §3.2.
enum NativeAckSender {
    static let timeout: TimeInterval = 8

    static func makeSession(timeout: TimeInterval = timeout) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        return URLSession(configuration: configuration)
    }

    static func request(
        action: String,
        incidentId: String,
        session: NseCredentials.Session
    ) -> URLRequest {
        let escaped = incidentId.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed
        ) ?? incidentId
        let url = session.server
            .appendingPathComponent("v1")
            .appendingPathComponent("incidents")
            .appendingPathComponent(escaped)
            .appendingPathComponent(action)

        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    /// The same one try, for the intents, which run as async code.
    @discardableResult
    static func send(action: String, incidentId: String) async -> Bool {
        await withCheckedContinuation { continuation in
            send(action: action, incidentId: incidentId) { ok in
                continuation.resume(returning: ok)
            }
        }
    }

    /// The same one try, answering with the HTTP status, or nil when nothing
    /// came back (no credentials, offline). The close intent needs the status
    /// to tell a finished incident from a 409.
    static func sendForStatus(action: String, incidentId: String) async -> Int? {
        await withCheckedContinuation { continuation in
            sendReportingStatus(action: action, incidentId: incidentId) { status in
                continuation.resume(returning: status)
            }
        }
    }

    /// True when a close answer means the incident is over, so the widget can
    /// drop it: 2xx closed it, 404 or 410 means it is not there any more. A
    /// 409 means it is not acked (it may have opened again), so it stays. The
    /// same rule as `ActionResponseRule.endsTheIncident` on Android.
    static func endsTheIncident(status: Int?) -> Bool {
        guard let status else { return false }
        return (200 ..< 300).contains(status) || status == 404 || status == 410
    }

    /// Calls back with true once the server has the ack (2xx) or already had
    /// it (409); the queue entry is gone by then. False leaves the entry for
    /// Dart. `action` is `ack` or `close`, the same words the queue uses.
    static func send(
        action: String,
        incidentId: String,
        session: NseCredentials.Session? = NseCredentials.read(),
        urlSession: URLSession = makeSession(),
        queue: UserDefaults = .standard,
        completion: @escaping (Bool) -> Void
    ) {
        sendReportingStatus(
            action: action, incidentId: incidentId, session: session,
            urlSession: urlSession, queue: queue
        ) { status in
            completion(status.map { (200 ..< 300).contains($0) || $0 == 409 } ?? false)
        }
    }

    /// The try itself. Calls back with the HTTP status, or nil when no answer
    /// came back. The queue entry goes on 2xx or 409, as above.
    static func sendReportingStatus(
        action: String,
        incidentId: String,
        session: NseCredentials.Session? = NseCredentials.read(),
        urlSession: URLSession = makeSession(),
        queue: UserDefaults = .standard,
        statusCompletion: @escaping (Int?) -> Void
    ) {
        guard let session else {
            NSLog("CritAlarmAck: ack_native_skipped reason=no_credentials action=%@ incident_id=%@", action, incidentId)
            statusCompletion(nil)
            return
        }

        let request = request(action: action, incidentId: incidentId, session: session)
        urlSession.dataTask(with: request) { _, response, error in
            if let error {
                NSLog("CritAlarmAck: ack_native_failed action=%@ incident_id=%@ reason=%@", action, incidentId, "\(error)")
                statusCompletion(nil)
                return
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200 ..< 300).contains(status) || status == 409 else {
                NSLog("CritAlarmAck: ack_native_failed_%d action=%@ incident_id=%@", status, action, incidentId)
                statusCompletion(status)
                return
            }
            AckQueueStore.remove(incidentId: incidentId, action: action, defaults: queue)
            NSLog("CritAlarmAck: ack_native_sent status=%d action=%@ incident_id=%@", status, action, incidentId)
            statusCompletion(status)
        }.resume()
    }
}
