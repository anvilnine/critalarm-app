import Foundation

/// What the app shows for one incident, once the content has been resolved.
struct IncidentContent {
    let title: String
    let body: String
    let tags: [String]
    let click: String?
    let topic: String?
}

/// Fills in the title and body a `relay_content: none` push leaves out.
///
/// api.md §3.2 has `GET /v1/incidents/{id}` for exactly this, and §5.1 gives
/// the extension until its own deadline to use it. Ten seconds is the budget;
/// past that the notification goes up with the placeholder text rather than
/// making the user wait on an alarm.
enum IncidentContentFetcher {
    static let timeout: TimeInterval = 10

    /// Extra `URLProtocol` classes to put in front of the real network. Empty
    /// in the app; a test puts a stub in here so it can count the calls.
    static var extraProtocolClasses: [AnyClass] = []

    /// The kinds that may answer from the cache. A repeat and a reopen carry
    /// the text the incident already had, so calling the server again buys
    /// nothing. An `open` or a `p4` may carry a message the cache has never
    /// seen, so those always go to the server.
    static let cacheableKinds: Set<IncidentPush.Kind> = [.repeat, .reopen]

    static func fallback(_ push: IncidentPush) -> IncidentContent {
        IncidentContent(
            title: push.title ?? (push.incidentId == nil ? "Alert" : "Crit Alarm"),
            body: push.body ?? (push.incidentId == nil
                ? "Open Crit Alarm to see details"
                : "Critical alert — open to see details"),
            tags: [],
            click: nil,
            topic: nil
        )
    }

    /// Runs the fetch and calls back with the resolved content, or with the
    /// fallback when the push carries nothing and the call does not land.
    static func resolve(
        _ push: IncidentPush,
        session: NseCredentials.Session?,
        completion: @escaping (IncidentContent, Bool) -> Void
    ) {
        // Every pass through the extension throws out what has gone stale.
        IncidentContentCache.prune()

        if !push.needsContentFetch {
            completion(
                IncidentContent(
                    title: push.title ?? fallback(push).title,
                    body: push.body ?? fallback(push).body,
                    tags: [], click: nil, topic: nil
                ),
                false
            )
            return
        }
        guard let incidentId = push.incidentId, let session else {
            completion(fallback(push), true)
            return
        }

        let cached = IncidentContentCache.read(incidentId: incidentId)
        if let cached, cacheableKinds.contains(push.kind) {
            NSLog("CritAlarmNSE incident_content_cache_hit incident_id=%@", incidentId)
            completion(cached.content, false)
            return
        }

        fetch(incidentId: incidentId, session: session) { content, lastMessageAt in
            if let content {
                IncidentContentCache.write(
                    content, for: incidentId, lastMessageAt: lastMessageAt
                )
                completion(content, false)
                return
            }
            // The call did not land. Warm cache beats the placeholder.
            if let cached {
                NSLog(
                    "CritAlarmNSE incident_content_cache_hit incident_id=%@ reason=fetch_failed",
                    incidentId
                )
                completion(cached.content, false)
                return
            }
            completion(fallback(push), true)
        }
    }

    static func fetch(
        incidentId: String,
        session: NseCredentials.Session,
        completion: @escaping (IncidentContent?, Int?) -> Void
    ) {
        let escaped = incidentId.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed
        ) ?? incidentId
        let url = session.server
            .appendingPathComponent("v1")
            .appendingPathComponent("incidents")
            .appendingPathComponent(escaped)

        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.setValue("Bearer \(session.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        if !extraProtocolClasses.isEmpty {
            configuration.protocolClasses = extraProtocolClasses + (configuration.protocolClasses ?? [])
        }

        URLSession(configuration: configuration).dataTask(with: request) { data, response, error in
            if let error {
                NSLog("CritAlarmNSE incident_fetch_failed incident_id=%@ reason=%@", incidentId, "\(error)")
                completion(nil, nil)
                return
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200 ..< 300).contains(status), let data else {
                NSLog("CritAlarmNSE incident_fetch_failed_%d incident_id=%@", status, incidentId)
                completion(nil, nil)
                return
            }
            let parsed = parse(data)
            NSLog("CritAlarmNSE %@ incident_id=%@", parsed == nil ? "incident_fetch_unreadable" : "incident_fetch_ok", incidentId)
            completion(parsed, parsed == nil ? nil : lastMessageAt(data))
        }.resume()
    }

    /// `last_message_at` off the incident object (api.md §3.2), in seconds.
    static func lastMessageAt(_ data: Data) -> Int? {
        guard let incident = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return (incident["last_message_at"] as? NSNumber)?.intValue
    }

    /// Reads the newest message out of an incident object (api.md §3.2).
    static func parse(_ data: Data) -> IncidentContent? {
        guard let incident = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let messages = incident["messages"] as? [[String: Any]],
              let newest = messages.last
        else { return nil }

        let topic = (incident["topic"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let tags = (newest["tags"] as? [String])?.filter { !$0.isEmpty } ?? []

        return IncidentContent(
            title: (newest["title"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                ?? topic ?? "Critical incident",
            body: (newest["message"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                ?? "Immediate attention required",
            tags: tags,
            click: (newest["click"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            topic: topic
        )
    }
}
