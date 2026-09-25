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
enum WidgetLink {
    static let scheme = "critalarm"

    static let homeURL = URL(string: "\(scheme)://home")!

    static func url(topic: String) -> URL {
        URL(string: "\(scheme)://topics/\(escape(topic))")!
    }

    static func url(incidentId: String) -> URL {
        URL(string: "\(scheme)://incidents/\(escape(incidentId))")!
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
        case "topics":
            return segment(path).map { ["topic": $0] }
        case "incidents":
            return segment(path).map { ["incident_id": $0] }
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
