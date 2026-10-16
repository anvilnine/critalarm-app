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

/// One question to the server after Stop: is this incident still open?
///
/// Every phone on a topic rings for the same incident. iOS hears that it was
/// answered somewhere else only through the Live Activity update (api.md
/// §5.3), and only while the app runs. A phone that was asleep kept setting
/// its own next ring on every Stop until `ring_until`. Stop now asks once.
/// The ring it set stays unless the server names a state that ends it:
/// `acked`, `closed` or `expired`. No answer, an error or a word this app
/// does not know leaves the ring alone, because a phone that stops ringing
/// for an incident nobody handled is the worse mistake.
///
/// Dart reads the same three words in
/// `lib/core/alarm/handled_elsewhere_rule.dart`, and Android in
/// `RemoteStateRule.kt`.
enum RemoteStateCheck {
    static let timeout: TimeInterval = 4

    /// [state] when it ends the ring, nil for anything else.
    static func endingState(_ state: String?) -> String? {
        switch state {
        case "acked", "closed", "expired": return state
        default: return nil
        }
    }

    /// The ending state in a `GET /v1/incidents/{id}` answer, or nil for any
    /// answer that is not a 2xx incident in one of the three states.
    static func endingState(status: Int?, body: Data?) -> String? {
        guard let status, (200 ..< 300).contains(status), let body,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
        else { return nil }
        return endingState(json["state"] as? String)
    }

    /// The ending state and the stage (`opened_at`, epoch seconds in
    /// api.md §3.2) of a `GET /v1/incidents/{id}` answer, or nil when the
    /// answer does not end the ring.
    static func answer(status: Int?, body: Data?) -> (state: String, openedAt: Date?)? {
        guard let state = endingState(status: status, body: body), let body,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
        else { return nil }
        let openedAt = (json["opened_at"] as? NSNumber).map {
            Date(timeIntervalSince1970: $0.doubleValue)
        }
        return (state, openedAt)
    }

    /// `GET {server}/v1/incidents/{id}`, with the same headers as the ack.
    static func request(incidentId: String, session: NseCredentials.Session) -> URLRequest {
        let escaped = incidentId.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed
        ) ?? incidentId
        let url = session.server
            .appendingPathComponent("v1")
            .appendingPathComponent("incidents")
            .appendingPathComponent(escaped)

        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "GET"
        request.setValue("Bearer \(session.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    /// The ending state the server holds for [incidentId], with its stage,
    /// or nil.
    static func fetch(
        incidentId: String,
        session: NseCredentials.Session? = NseCredentials.read(),
        urlSession: URLSession = NativeAckSender.makeSession(timeout: timeout)
    ) async -> (state: String, openedAt: Date?)? {
        guard let session else { return nil }
        let request = request(incidentId: incidentId, session: session)
        return await withCheckedContinuation { continuation in
            urlSession.dataTask(with: request) { data, response, error in
                if let error {
                    NSLog("CritAlarmAck: state_check_failed incident_id=%@ reason=%@", incidentId, "\(error)")
                    continuation.resume(returning: nil)
                    return
                }
                let status = (response as? HTTPURLResponse)?.statusCode
                let found = answer(status: status, body: data)
                NSLog(
                    "CritAlarmAck: state_check status=%d incident_id=%@ ends=%@",
                    status ?? 0, incidentId, found?.state ?? "-"
                )
                continuation.resume(returning: found)
            }.resume()
        }
    }
}
