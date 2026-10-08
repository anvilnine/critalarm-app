import Foundation

/// The `critalarm://` links widgets open, and what each one asks Dart for.
///
/// Flutter's own deep linking is off, so a link never reaches go_router as a
/// URL. `AppDelegate.openWidgetLink` turns it into the same tap map a tapped
/// notification produces, and Dart's `PushDeepLink` picks the screen.
///
/// - `critalarm://topics/<name>` opens that topic.
/// - `critalarm://incidents/<id>` opens that incident.
/// - `critalarm://home` opens Home.
/// - `critalarm://paywall` opens the plans screen.
enum WidgetLink {
    static let scheme = "critalarm"

    static let homeURL = URL(string: "\(scheme)://home")!
    static let paywallURL = URL(string: "\(scheme)://paywall")!

    static func url(topic: String) -> URL {
        URL(string: "\(scheme)://topics/\(escape(topic))")!
    }

    static func url(incidentId: String) -> URL {
        URL(string: "\(scheme)://incidents/\(escape(incidentId))")!
    }

    /// Where Done on a home screen widget goes while the topic owes a
    /// wake-up challenge: the incident, as a link. Nil when Done closes
    /// from the widget, as it always has.
    ///
    /// A link and not `OpenIncidentIntent`: a widget's button can run in
    /// the widget extension's process, where that intent would only note
    /// the incident in memory the app never sees.
    ///
    /// The link carries `from=done`. Done is only ever drawn on an
    /// acknowledged incident, so the marker tells Dart "native holds this
    /// one as acknowledged", and the app can hand the close back when it
    /// cannot reach the server. A plain tap on a card never carries it.
    /// `PushDeepLink.fromKey` and `fromDone` in Dart hold the same words.
    static func doneURL(incidentId: String, topic: String, shared: UserDefaults?) -> URL? {
        guard DoneButton.forCard(topic: topic, shared: shared) == .opensApp else { return nil }
        return URL(string: "\(scheme)://incidents/\(escape(incidentId))?\(fromKey)=\(fromDone)")!
    }

    static let fromKey = "from"
    static let fromDone = "done"

    /// The one link the small topic widget has for its whole face. A small
    /// widget cannot hold a link of its own inside it, so while Done opens
    /// the app, the face goes where Done goes. Otherwise the topic.
    static func smallTopicURL(
        topic: String, ackedIncidentId: String?, shared: UserDefaults?
    ) -> URL {
        if let ackedIncidentId,
           let done = doneURL(incidentId: ackedIncidentId, topic: topic, shared: shared) {
            return done
        }
        return url(topic: topic)
    }

    /// The tap map for [url], or nil for any other scheme or shape.
    static func tap(from url: URL) -> [String: String]? {
        guard url.scheme == scheme,
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return nil }
        let path = parts.percentEncodedPath
        switch parts.host {
        case "home":
            return path.isEmpty || path == "/" ? ["open": "home"] : nil
        case "paywall":
            return path.isEmpty || path == "/" ? ["open": "paywall"] : nil
        case "topics":
            return segment(path).map { ["topic": $0] }
        case "incidents":
            guard let id = segment(path) else { return nil }
            // Only the one marker, and only beside an incident.
            let isFromDone = parts.queryItems?.contains {
                $0.name == fromKey && $0.value == fromDone
            } ?? false
            return isFromDone ? ["incident_id": id, fromKey: fromDone] : ["incident_id": id]
        default:
            return nil
        }
    }

    /// Only letters, digits and `-._~` stay as they are, so a `/` in a name
    /// cannot split the path.
    private static let unreserved = CharacterSet(
        charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"
    )

    private static func escape(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: unreserved) ?? value
    }

    /// The one non-empty segment after the host, decoded.
    private static func segment(_ encodedPath: String) -> String? {
        guard encodedPath.hasPrefix("/") else { return nil }
        let raw = String(encodedPath.dropFirst())
        guard !raw.isEmpty, !raw.contains("/"),
              let decoded = raw.removingPercentEncoding, !decoded.isEmpty
        else { return nil }
        return decoded
    }
}
