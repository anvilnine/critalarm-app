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
        fetch(incidentId: incidentId, session: session) { content in
            completion(content ?? fallback(push), content == nil)
        }
    }

    static func fetch(
        incidentId: String,
        session: NseCredentials.Session,
        completion: @escaping (IncidentContent?) -> Void
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

        URLSession(configuration: configuration).dataTask(with: request) { data, response, error in
            if let error {
                NSLog("CritAlarmNSE incident_fetch_failed incident_id=%@ reason=%@", incidentId, "\(error)")
                completion(nil)
                return
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200 ..< 300).contains(status), let data else {
                NSLog("CritAlarmNSE incident_fetch_failed_%d incident_id=%@", status, incidentId)
                completion(nil)
                return
            }
            let parsed = parse(data)
            NSLog("CritAlarmNSE %@ incident_id=%@", parsed == nil ? "incident_fetch_unreadable" : "incident_fetch_ok", incidentId)
            completion(parsed)
        }.resume()
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
