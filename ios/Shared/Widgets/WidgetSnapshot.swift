import Foundation

/// The one document the home and lock screen widgets read.
///
/// Dart writes it over the `app.critalarm/widgets` channel, and the extension,
/// the intents and the delegate patch it. The format is
/// `backlog/home-widgets-plan.md` section 1, the same bytes Android keeps in
/// its `critalarm_widgets` preferences. `test/fixtures/widget_snapshot_v1.json`
/// is the sample every platform's tests read.
///
/// Foundation only, so every target and the tests can compile it.
struct WidgetSnapshot: Codable, Equatable {
    static let version = 1
    static let maxTopics = 50
    static let titleMaxLength = 120
    static let staleAfter = 900

    var v: Int = WidgetSnapshot.version
    /// Epoch seconds of the last write. 0 means a patch could not place
    /// something and the next redraw should fetch.
    var updatedAt: Int
    var connected: Bool
    var openCount: Int
    var topics: [WidgetTopic]

    enum CodingKeys: String, CodingKey {
        case v
        case updatedAt = "updated_at"
        case connected
        case openCount = "open_count"
        case topics
    }

    /// The snapshot in [data], or nil for anything that is not version 1.
    static func decode(_ data: Data) -> WidgetSnapshot? {
        guard let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data),
              snapshot.v == version
        else { return nil }
        return snapshot
    }

    func encoded() -> Data {
        (try? JSONEncoder().encode(self)) ?? Data()
    }

    /// What sign out writes: nothing to show and nothing to fetch.
    static func disconnected(now: Date) -> WidgetSnapshot {
        WidgetSnapshot(updatedAt: seconds(now), connected: false, openCount: 0, topics: [])
    }

    /// Topics with an open incident first, then acked, then quiet, each by name.
    func sorted() -> WidgetSnapshot {
        var copy = self
        copy.topics.sort { a, b in
            let (ga, gb) = (Self.group(a), Self.group(b))
            return ga != gb ? ga < gb : a.name < b.name
        }
        return copy
    }

    /// [openCount] as the sum of the topic counts.
    func recounted() -> WidgetSnapshot {
        var copy = self
        copy.openCount = topics.reduce(0) { $0 + $1.count }
        return copy
    }

    /// True when the widget should ask the server. A missing or signed-out
    /// snapshot is never stale, so a widget placed before the app was opened
    /// never fetches.
    func isStale(now: Date) -> Bool {
        guard connected else { return false }
        return updatedAt == 0 || Self.seconds(now) - updatedAt >= Self.staleAfter
    }

    static func seconds(_ date: Date) -> Int {
        Int(date.timeIntervalSince1970.rounded(.down))
    }

    private static func group(_ topic: WidgetTopic) -> Int {
        switch topic.incident?.state {
        case WidgetIncident.open: return 0
        case WidgetIncident.acked: return 1
        default: return 2
        }
    }

    /// Trimmed, cut to [titleMaxLength] code points (unicode scalars, the
    /// same cut Dart and Kotlin make), and the topic name when empty.
    static func title(_ raw: String?, topic: String) -> String {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let picked = trimmed.isEmpty ? topic : trimmed
        return String(String.UnicodeScalarView(picked.unicodeScalars.prefix(titleMaxLength)))
    }
}

struct WidgetTopic: Codable, Equatable {
    var name: String
    var critical: Bool
    /// Open plus acked incidents on this topic.
    var count: Int
    var incident: WidgetIncident?

    // Written out by hand so a quiet topic says `"incident": null`.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(critical, forKey: .critical)
        try container.encode(count, forKey: .count)
        try container.encode(incident, forKey: .incident)
    }
}

struct WidgetIncident: Codable, Equatable {
    static let open = "open"
    static let acked = "acked"

    var id: String
    /// `open` or `acked`.
    var state: String
    var title: String
    /// Epoch seconds, 0 when unknown.
    var openedAt: Int
    /// Epoch seconds, nil while open.
    var ackedAt: Int?

    enum CodingKeys: String, CodingKey {
        case id, state, title
        case openedAt = "opened_at"
        case ackedAt = "acked_at"
    }

    // Written out by hand so an open incident says `"acked_at": null`.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(state, forKey: .state)
        try container.encode(title, forKey: .title)
        try container.encode(openedAt, forKey: .openedAt)
        try container.encode(ackedAt, forKey: .ackedAt)
    }

    /// True when [self] is shown over [other]: open beats acked, then newer,
    /// then the smaller id.
    func wins(over other: WidgetIncident) -> Bool {
        if (state == Self.open) != (other.state == Self.open) { return state == Self.open }
        if openedAt != other.openedAt { return openedAt > other.openedAt }
        return id < other.id
    }
}

/// One incident as `GET /v1/incidents/{id}` describes it (api.md §3.2).
struct WidgetIncidentRecord: Equatable {
    let id: String
    let topic: String
    let state: String
    let title: String
    let openedAt: Int
    let ackedAt: Int?
}

/// What a patch did.
enum WidgetPatchResult: Equatable {
    case changed(WidgetSnapshot)
    case unchanged
    /// The patch could not place everything, so the widget has to ask the
    /// server. The snapshot is what the patch could do, written stale; nil
    /// keeps the old one and marks it stale.
    case needsFetch(WidgetSnapshot?)
}

/// The changes a push, a button or a fetch makes, without a network call.
///
/// Every one leaves a missing or signed-out snapshot alone: only the app writes
/// the first one. `WidgetSnapshot.kt` on Android has the first four with the
/// same tests.
enum WidgetPatch: Equatable {
    /// An `open` or `repeat` push. A new id goes on its topic, and shows if it
    /// wins over the incident already there.
    case opened(String, topic: String?, title: String?, openedAt: Date)
    /// A `reopen` push: the desk timer ran out on an acked incident.
    case reopened(String)
    /// An acknowledge. An `acked_at` already known is kept.
    case acked(String, at: Date)
    /// A close or an expiry.
    case ended(String)
    /// The whole incident, fetched. iOS only: the extension already has it.
    case upsert(WidgetIncidentRecord)

    func apply(to snapshot: WidgetSnapshot?, now: Date) -> WidgetPatchResult {
        guard let snapshot, snapshot.connected else { return .unchanged }
        let nowSeconds = WidgetSnapshot.seconds(now)
        switch self {
        case let .opened(id, topic, title, openedAt):
            if snapshot.index(of: id) != nil { return .unchanged }
            guard let topic else { return .needsFetch(nil) }
            let added = WidgetIncident(
                id: id, state: WidgetIncident.open,
                title: WidgetSnapshot.title(title, topic: topic),
                openedAt: WidgetSnapshot.seconds(openedAt), ackedAt: nil
            )
            return snapshot.placing(added, on: topic, now: nowSeconds)

        case let .reopened(id):
            guard let at = snapshot.index(of: id) else { return .needsFetch(nil) }
            var topic = snapshot.topics[at]
            guard topic.incident?.state != WidgetIncident.open else { return .unchanged }
            topic.incident?.state = WidgetIncident.open
            topic.incident?.ackedAt = nil
            return .changed(snapshot.replacing(at, with: topic, now: nowSeconds))

        case let .acked(id, ackedAt):
            guard let at = snapshot.index(of: id) else { return .needsFetch(nil) }
            var topic = snapshot.topics[at]
            guard var incident = topic.incident else { return .needsFetch(nil) }
            if incident.state == WidgetIncident.acked, incident.ackedAt != nil { return .unchanged }
            incident.state = WidgetIncident.acked
            incident.ackedAt = incident.ackedAt ?? WidgetSnapshot.seconds(ackedAt)
            topic.incident = incident
            let next = snapshot.replacing(at, with: topic, now: nowSeconds)
            // Another incident on this topic may now be the one to show.
            return topic.count > 1 ? .needsFetch(next) : .changed(next)

        case let .ended(id):
            guard let at = snapshot.index(of: id) else { return .needsFetch(nil) }
            var topic = snapshot.topics[at]
            topic.incident = nil
            topic.count = max(0, topic.count - 1)
            let next = snapshot.replacing(at, with: topic, now: nowSeconds)
            // Another incident on this topic is still going, and the snapshot
            // does not know which.
            return topic.count > 0 ? .needsFetch(next) : .changed(next)

        case let .upsert(record):
            let incident = WidgetIncident(
                id: record.id, state: record.state, title: record.title,
                openedAt: record.openedAt,
                ackedAt: record.state == WidgetIncident.acked ? record.ackedAt : nil
            )
            guard let at = snapshot.index(of: record.id) else {
                return snapshot.placing(incident, on: record.topic, now: nowSeconds)
            }
            var topic = snapshot.topics[at]
            guard topic.incident != incident else { return .unchanged }
            let stateMoved = topic.incident?.state != incident.state
            topic.incident = incident
            let next = snapshot.replacing(at, with: topic, now: nowSeconds)
            return stateMoved && topic.count > 1 ? .needsFetch(next) : .changed(next)
        }
    }
}

extension WidgetSnapshot {
    /// Index of the topic whose shown incident is [incidentId].
    func index(of incidentId: String) -> Int? {
        topics.firstIndex { $0.incident?.id == incidentId }
    }

    func replacing(_ index: Int, with topic: WidgetTopic, now: Int) -> WidgetSnapshot {
        var copy = self
        copy.topics[index] = topic
        copy.updatedAt = now
        return copy.sorted().recounted()
    }

    /// Puts an incident the snapshot has never seen on [topicName].
    fileprivate func placing(_ incident: WidgetIncident, on topicName: String, now: Int) -> WidgetPatchResult {
        guard let at = topics.firstIndex(where: { $0.name == topicName }) else { return .needsFetch(nil) }
        var topic = topics[at]
        // The topic holds incidents the snapshot does not name, and this id
        // could be one of them. Counting it again would be wrong.
        if topic.count > (topic.incident == nil ? 0 : 1) { return .needsFetch(nil) }
        topic.count += 1
        if let shown = topic.incident, !incident.wins(over: shown) {
            // Counted, not shown.
        } else {
            topic.incident = incident
        }
        return .changed(replacing(at, with: topic, now: now))
    }
}

// MARK: - Reading the server's answers

extension WidgetSnapshot {
    /// Builds a snapshot from the three answers the widget fetch gets
    /// (api.md §3.1 and §3.2), with the same rules as Dart's
    /// `buildWidgetSnapshot`. Nil when any answer is unreadable.
    static func fromServer(topics: Data, open: Data, acked: Data, now: Date) -> WidgetSnapshot? {
        guard let topicList = jsonArray(topics),
              let openList = jsonArray(open),
              let ackedList = jsonArray(acked)
        else { return nil }

        var live: [String: [WidgetIncident]] = [:]
        for json in openList + ackedList {
            guard let record = record(json),
                  record.state == WidgetIncident.open || record.state == WidgetIncident.acked
            else { continue }
            live[record.topic, default: []].append(
                WidgetIncident(
                    id: record.id, state: record.state, title: record.title,
                    openedAt: record.openedAt,
                    ackedAt: record.state == WidgetIncident.acked ? record.ackedAt : nil
                )
            )
        }

        let built: [WidgetTopic] = topicList.compactMap { json in
            guard let name = string(json["name"]) else { return nil }
            let incidents = live[name] ?? []
            var shown: WidgetIncident?
            for incident in incidents where shown == nil || incident.wins(over: shown!) {
                shown = incident
            }
            return WidgetTopic(
                name: name,
                critical: (json["critical"] as? Bool) ?? false,
                count: incidents.count,
                incident: shown
            )
        }

        var snapshot = WidgetSnapshot(
            updatedAt: seconds(now), connected: true, openCount: 0, topics: built
        ).sorted()
        snapshot.topics = Array(snapshot.topics.prefix(maxTopics))
        return snapshot.recounted()
    }

    /// The incident object `GET /v1/incidents/{id}` answers, for the
    /// extension. Nil when it is unreadable.
    static func incidentRecord(fromIncidentJSON data: Data) -> WidgetIncidentRecord? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return record(json)
    }

    private static func record(_ json: [String: Any]) -> WidgetIncidentRecord? {
        guard let id = string(json["id"]),
              let topic = string(json["topic"]),
              let state = string(json["state"])
        else { return nil }
        return WidgetIncidentRecord(
            id: id,
            topic: topic,
            state: state,
            title: title(newestText(json["messages"]), topic: topic),
            openedAt: epochSeconds(json["opened_at"]) ?? 0,
            ackedAt: epochSeconds(json["acked_at"])
        )
    }

    /// The newest message's title, else its text. Newest is the largest
    /// `time`, so the order the server lists them in does not matter.
    private static func newestText(_ raw: Any?) -> String? {
        guard let messages = raw as? [[String: Any]] else { return nil }
        var newest: [String: Any]?
        var newestTime = Int.min
        for message in messages {
            let time = (message["time"] as? NSNumber)?.intValue ?? 0
            if time >= newestTime {
                newest = message
                newestTime = time
            }
        }
        guard let newest else { return nil }
        for key in ["title", "message"] {
            let text = string(newest[key])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !text.isEmpty { return text }
        }
        return nil
    }

    private static func jsonArray(_ data: Data) -> [[String: Any]]? {
        guard let array = try? JSONSerialization.jsonObject(with: data) as? [Any] else { return nil }
        return array.compactMap { $0 as? [String: Any] }
    }

    private static func string(_ raw: Any?) -> String? {
        guard let text = raw as? String, !text.isEmpty else { return nil }
        return text
    }

    /// Unix seconds, unix milliseconds or ISO-8601, the three shapes Dart's
    /// NullableDateTimeConverter reads. Rounded down to whole seconds.
    static func epochSeconds(_ raw: Any?) -> Int? {
        if let number = raw as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() {
            return fromNumber(number.int64Value)
        }
        guard let text = raw as? String else { return nil }
        if let number = Int64(text) { return fromNumber(number) }
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: text) { return seconds(date) }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: text).map { seconds($0) }
    }

    private static func fromNumber(_ value: Int64) -> Int {
        Int(value < 10_000_000_000 ? value : value / 1000)
    }
}
