import Foundation

/// Holds the text the extension already fetched for one incident.
///
/// Hosted mode sends no text in the push, so the extension calls
/// `GET /v1/incidents/{id}` (api.md §3.2) to fill the banner in. A repeat
/// arrives every 30 seconds and carries the same text as the one before it, so
/// a 30 minute incident used to cost 60 calls per iPhone. This keeps the last
/// answer in the app group, where both the app and the extension can read it,
/// and the repeats read it instead of the server.
///
/// The server is still the only source of the text. This is a copy of its last
/// answer, never a second source.
enum IncidentContentCache {
    /// The same app group `SharedSounds` and `QuietHours` use.
    static let appGroup = "group.app.critalarm"

    /// One key per incident, id and nothing else. Nothing is keyed by topic,
    /// so two incidents on one topic never see each other's text.
    static let keyPrefix = "incident_content_v1."

    /// Where the entries live. Tests point this at their own suite.
    static var defaults: UserDefaults? = UserDefaults(suiteName: appGroup)

    /// How long an entry is worth keeping: the longest an incident can ring
    /// plus the desk timer. The topic's own numbers are not in shared storage,
    /// so these are the defaults.
    static let maxRingSeconds = 1_800
    static let deskTimerSeconds = 600

    static var maxAge: TimeInterval {
        TimeInterval(maxRingSeconds + deskTimerSeconds)
    }

    /// One cached incident: what to show, when its newest message landed, and
    /// when this copy was written.
    struct Entry {
        let content: IncidentContent
        let lastMessageAt: Int?
        let cachedAtMs: Int
    }

    static func key(for incidentId: String) -> String { keyPrefix + incidentId }

    /// What was cached for this incident, or nil when nothing was.
    static func read(incidentId: String) -> Entry? {
        guard let stored = defaults?.dictionary(forKey: key(for: incidentId)),
              let title = stored["title"] as? String,
              let body = stored["body"] as? String
        else { return nil }

        return Entry(
            content: IncidentContent(
                title: title,
                body: body,
                tags: stored["tags"] as? [String] ?? [],
                click: stored["click"] as? String,
                topic: stored["topic"] as? String
            ),
            lastMessageAt: stored["last_message_at"] as? Int,
            cachedAtMs: stored["cached_at_ms"] as? Int ?? 0
        )
    }

    /// Keeps `content` as the text for this incident, replacing whatever was
    /// there. A later push reads it back instead of calling the server.
    static func write(
        _ content: IncidentContent,
        for incidentId: String,
        lastMessageAt: Int? = nil,
        now: Date = Date()
    ) {
        var stored: [String: Any] = [
            "title": content.title,
            "body": content.body,
            "tags": content.tags,
            "cached_at_ms": Int(now.timeIntervalSince1970 * 1000),
        ]
        if let click = content.click { stored["click"] = click }
        if let topic = content.topic { stored["topic"] = topic }
        if let lastMessageAt { stored["last_message_at"] = lastMessageAt }

        defaults?.set(stored, forKey: key(for: incidentId))
    }

    /// Drops every entry older than `maxAge`. Runs on each extension pass, so
    /// the app group does not fill up with incidents nobody will see again.
    static func prune(olderThan maxAge: TimeInterval = maxAge, now: Date = Date()) {
        guard let defaults else { return }
        let oldest = Int((now.timeIntervalSince1970 - maxAge) * 1000)

        for (key, value) in defaults.dictionaryRepresentation()
        where key.hasPrefix(keyPrefix) {
            let cachedAtMs = (value as? [String: Any])?["cached_at_ms"] as? Int ?? 0
            if cachedAtMs < oldest { defaults.removeObject(forKey: key) }
        }
    }

    /// Everything, for a test that wants a clean slate.
    static func clear() {
        guard let defaults else { return }
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(keyPrefix) {
            defaults.removeObject(forKey: key)
        }
    }
}
