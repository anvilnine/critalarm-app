import Foundation

/// Push events recorded while Dart was not running.
///
/// Analytics is opt-in and the switch lives in Dart, so nothing native ever
/// reports anything itself. The extension writes what happened into the App
/// Group both targets share, the app moves those rows into the list Dart
/// drains on launch, and Dart drops the lot unless the user turned analytics
/// on. Keep the names in step with `lib/core/telemetry/analytics_events.dart`.
enum PushEventLog {
    static let appGroup = "group.app.critalarm"

    /// Where the extension writes. Only the App Group is reachable from there.
    static let groupKey = "nse_push_events"

    /// Where Dart reads. The `flutter.` prefix is what the shared_preferences
    /// plugin puts on every key it owns.
    static let dartKey = "flutter.pending_push_events"

    static let maxRows = 50

    static var groupDefaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    static func record(_ name: String, _ params: [String: Any] = [:]) {
        guard let defaults = groupDefaults else { return }
        var row: [String: Any] = params
        row["name"] = name
        row["at_ms"] = Int(Date().timeIntervalSince1970 * 1000)

        var rows = defaults.array(forKey: groupKey) as? [[String: Any]] ?? []
        rows.append(row)
        if rows.count > maxRows { rows.removeFirst(rows.count - maxRows) }
        defaults.set(rows, forKey: groupKey)
    }

    /// Moves everything the extension logged onto the list Dart drains.
    /// Returns how many rows moved.
    @discardableResult
    static func handOverToDart() -> Int {
        guard let defaults = groupDefaults,
              let rows = defaults.array(forKey: groupKey) as? [[String: Any]],
              !rows.isEmpty
        else { return 0 }
        defaults.removeObject(forKey: groupKey)

        let standard = UserDefaults.standard
        var pending: [[String: Any]] = []
        if let raw = standard.string(forKey: dartKey),
           let data = raw.data(using: .utf8),
           let decoded = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            pending = decoded
        }
        pending.append(contentsOf: rows)
        if pending.count > maxRows { pending.removeFirst(pending.count - maxRows) }

        guard let data = try? JSONSerialization.data(withJSONObject: pending),
              let json = String(data: data, encoding: .utf8)
        else { return 0 }
        standard.set(json, forKey: dartKey)
        return rows.count
    }

    static func recent() -> [[String: Any]] {
        guard let defaults = groupDefaults else { return [] }
        return (defaults.array(forKey: groupKey) as? [[String: Any]] ?? []).reversed()
    }
}
