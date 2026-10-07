import Foundation

/// Which links from outside the app go to Dart, and the tap they become.
///
/// Two kinds: an `https://critalarm.app` universal link under `/connect` or
/// `/open/`, and the `critalarm://` form of the same routes. Widget links
/// (`WidgetLink`) are not handled here and keep their own path.
///
/// The link goes over whole, under `link`, and Dart's parser decides what it
/// opens. Nothing here reads it beyond its shape, and nothing logs it: a
/// connect link carries a token.
enum AppLinkRule {
    static let host = "critalarm.app"
    static let connectPath = "/connect"
    static let openPrefix = "/open/"

    /// Matches `PushHost.linkKey` in Dart.
    static let linkKey = "link"

    /// The first parts of a `critalarm://` link this rule takes. `topics`,
    /// `incidents`, `home` and `paywall` belong to `WidgetLink`.
    static let customHosts: Set<String> = ["connect", "open", "settings"]

    /// The tap for [url], or nil when the link is not one of these.
    static func tap(from url: URL) -> [String: String]? {
        guard !url.isFileURL,
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = parts.scheme?.lowercased(),
              let linkHost = parts.host?.lowercased()
        else { return nil }
        switch scheme {
        case "https":
            guard linkHost == host, parts.port == nil || parts.port == 443 else { return nil }
            let path = parts.percentEncodedPath
            guard path == connectPath || path.hasPrefix(openPrefix) else { return nil }
        case WidgetLink.scheme:
            guard customHosts.contains(linkHost) else { return nil }
        default:
            return nil
        }
        return [linkKey: url.absoluteString]
    }

    /// True when [activity] carries a link this rule takes. Such an activity
    /// must not stay on a scene or be passed on: the link may hold a token.
    static func holdsLink(_ activity: NSUserActivity?) -> Bool {
        guard let activity else { return false }
        return tap(from: activity) != nil
    }

    /// The link a universal-link activity carries, or nil for any other
    /// activity (Handoff, Spotlight, a Siri shortcut).
    static func tap(from activity: NSUserActivity) -> [String: String]? {
        guard activity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = activity.webpageURL
        else { return nil }
        return tap(from: url)
    }
}
