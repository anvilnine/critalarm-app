import Foundation

/// One APNs push, parsed off the custom keys that sit beside `aps`.
///
/// api.md §5.1 carries `incident_id`, `server` and `kind` at the top level and
/// no `priority`, so the priority comes from the kind: §1.7 fixes `open`,
/// `repeat` and `reopen` at 5, and `p4` is the forward path for 4 and for 5 on
/// a topic that is not critical. Keep this in step with
/// `lib/core/push/incident_push.dart`.
struct IncidentPush {
    enum Kind: String {
        case open, `repeat`, reopen, p4

        var impliedPriority: Int { self == .p4 ? 4 : 5 }
    }

    let incidentId: String?
    let server: URL
    let kind: Kind
    let priority: Int
    let title: String?
    let body: String?

    /// `aps.mutable-content: 1`. api.md §5.1 sets it only when the text in
    /// `aps.alert` is a placeholder; `relay_content: full` drops it.
    let mutableContent: Bool

    /// The last second this phone may ring for the incident on its own
    /// (api.md §5.1), as epoch seconds. Absent on a `p4`.
    let ringUntil: Date?

    /// The relay stripped the content, so the app has to fetch it with
    /// `GET /v1/incidents/{id}` (api.md §3.2). On APNs the placeholder text is
    /// always present, so the flag is what marks it as a placeholder.
    var needsContentFetch: Bool { mutableContent || (title == nil && body == nil) }

    init?(payload: [AnyHashable: Any]) {
        guard let kind = (payload["kind"] as? String).flatMap(Kind.init(rawValue:)) else { return nil }

        let id = (payload["incident_id"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        if id == nil, kind != .p4 { return nil }

        guard let raw = payload["server"] as? String,
              let server = URL(string: raw),
              let scheme = server.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              server.host != nil
        else { return nil }

        let priority = (payload["priority"] as? NSNumber)?.intValue
            ?? Int(payload["priority"] as? String ?? "")
            ?? kind.impliedPriority
        if priority < 1 || priority > 5 { return nil }

        let aps = payload["aps"] as? [AnyHashable: Any]
        let alert = aps?["alert"] as? [AnyHashable: Any]

        self.incidentId = id
        self.server = server
        self.kind = kind
        self.priority = priority
        self.title = (alert?["title"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        self.body = (alert?["body"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        self.mutableContent = (aps?["mutable-content"] as? NSNumber)?.intValue == 1
        let ringUntilSeconds = (payload["ring_until"] as? NSNumber)?.doubleValue
            ?? Double(payload["ring_until"] as? String ?? "")
        self.ringUntil = (ringUntilSeconds ?? 0) > 0
            ? Date(timeIntervalSince1970: ringUntilSeconds ?? 0)
            : nil
    }
}
