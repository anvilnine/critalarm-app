import Foundation

/// The widget's own look at the server, for when the snapshot has gone stale
/// and nothing else has written it (a topic changed from the dashboard, or an
/// incident closed elsewhere while the app was killed).
///
/// Three GETs, api.md §3.1 and §3.2, with the session the app already left in
/// the shared keychain. `limit` is always sent. Anything but a full set of 2xx
/// answers returns nil and the caller keeps the old snapshot. A 401 means the
/// token is gone, so the widgets show the signed-out view.
enum WidgetFetcher {
    static let timeout: TimeInterval = 8

    static func fetch(session: NseCredentials.Session, now: Date) async -> WidgetSnapshot? {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        let urlSession = URLSession(configuration: configuration)

        async let topics = get(["v1", "topics"], query: [], session: session, using: urlSession)
        async let open = get(
            ["v1", "incidents"], query: [("limit", "200"), ("state", "open")],
            session: session, using: urlSession
        )
        async let acked = get(
            ["v1", "incidents"], query: [("limit", "200"), ("state", "acked")],
            session: session, using: urlSession
        )
        let answers = await [topics, open, acked]

        if answers.contains(where: { $0.status == 401 }) {
            NSLog("CritAlarmWidgets: widget_fetch_unauthorized")
            return .disconnected(now: now)
        }
        guard answers.allSatisfy({ (200 ..< 300).contains($0.status) }),
              let topicsData = answers[0].data,
              let openData = answers[1].data,
              let ackedData = answers[2].data
        else {
            NSLog("CritAlarmWidgets: widget_fetch_failed statuses=%@", "\(answers.map(\.status))")
            return nil
        }
        let snapshot = WidgetSnapshot.fromServer(
            topics: topicsData, open: openData, acked: ackedData, now: now
        )
        NSLog("CritAlarmWidgets: %@", snapshot == nil ? "widget_fetch_unreadable" : "widget_fetch_ok")
        return snapshot
    }

    private struct Answer {
        let status: Int
        let data: Data?
    }

    private static func get(
        _ path: [String],
        query: [(String, String)],
        session: NseCredentials.Session,
        using urlSession: URLSession
    ) async -> Answer {
        var url = session.server
        for part in path { url.appendPathComponent(part) }
        if !query.isEmpty, var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            parts.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) }
            url = parts.url ?? url
        }
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.setValue("Bearer \(session.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await urlSession.data(for: request)
            return Answer(status: (response as? HTTPURLResponse)?.statusCode ?? 0, data: data)
        } catch {
            return Answer(status: 0, data: nil)
        }
    }
}
