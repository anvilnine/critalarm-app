import Foundation

/// The incidents the user already stopped on this phone.
///
/// Stop queues an `ack` for Dart to send, and until that lands the server
/// keeps sending `repeat` pushes. Each one used to schedule a fresh AlarmKit
/// alarm (`backlog/bug-ios-stop-ack-queue-rering.md`). This set is what the
/// push handler and the notification extension check first, so a repeat for
/// an incident on it does not ring. It lives in the app group because the
/// extension runs in its own process and cannot see the app's preferences.
///
/// Stored as `[incident_id: marked_at_ms]` so old entries can be pruned.
enum AckedIncidentStore {
    static let key = "acked_incidents_v1"
    static let localKey = "locally_acked_incidents_v1"
    static let appGroup = "group.app.critalarm"

    static var groupDefaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    /// `max_ring_s` plus `desk_timer_s` for a topic on its server defaults.
    /// After that the desk timer has reopened the incident or it has expired,
    /// and either way the mark is stale.
    static let fallbackPruneWindow: TimeInterval = 1_800 + 600

    static func mark(
        incidentId: String,
        at now: Date = Date(),
        in defaults: UserDefaults? = groupDefaults
    ) {
        guard let defaults else { return }
        var entries = read(from: defaults)
        entries[incidentId] = Int(now.timeIntervalSince1970 * 1_000)
        defaults.set(entries, forKey: key)
        var localEntries = readLocal(from: defaults)
        localEntries[incidentId] = entries[incidentId]
        defaults.set(localEntries, forKey: localKey)
    }

    static func markRemotelyAcknowledged(
        incidentId: String,
        at now: Date = Date(),
        in defaults: UserDefaults? = groupDefaults
    ) {
        guard let defaults else { return }
        var entries = read(from: defaults)
        entries[incidentId] = Int(now.timeIntervalSince1970 * 1_000)
        defaults.set(entries, forKey: key)
        var localEntries = readLocal(from: defaults)
        localEntries.removeValue(forKey: incidentId)
        defaults.set(localEntries, forKey: localKey)
    }

    static func contains(
        incidentId: String,
        in defaults: UserDefaults? = groupDefaults
    ) -> Bool {
        guard let defaults else { return false }
        return read(from: defaults)[incidentId] != nil
    }

    static func clear(
        incidentId: String,
        in defaults: UserDefaults? = groupDefaults
    ) {
        guard let defaults else { return }
        var entries = read(from: defaults)
        if entries.removeValue(forKey: incidentId) != nil {
            defaults.set(entries, forKey: key)
        }
        var localEntries = readLocal(from: defaults)
        if localEntries.removeValue(forKey: incidentId) != nil {
            defaults.set(localEntries, forKey: localKey)
        }
    }

    /// Drops every mark older than `window` seconds.
    static func prune(
        olderThan window: TimeInterval,
        now: Date = Date(),
        in defaults: UserDefaults? = groupDefaults
    ) {
        guard let defaults else { return }
        let cutoff = Int((now.timeIntervalSince1970 - window) * 1_000)
        let entries = read(from: defaults)
        let kept = entries.filter { $0.value >= cutoff }
        if kept.count != entries.count { defaults.set(kept, forKey: key) }
        let localEntries = readLocal(from: defaults)
        let keptLocal = localEntries.filter { $0.value >= cutoff }
        if keptLocal.count != localEntries.count { defaults.set(keptLocal, forKey: localKey) }
    }

    static func all(in defaults: UserDefaults? = groupDefaults) -> Set<String> {
        guard let defaults else { return [] }
        return Set(read(from: defaults).keys)
    }

    static func debugEntries(in defaults: UserDefaults? = groupDefaults) -> [[String: Any]] {
        guard let defaults else { return [] }
        return readLocal(from: defaults).map { ["incident_id": $0.key, "marked_at": $0.value / 1_000] }
    }

    static func clearLocalMarks(in defaults: UserDefaults? = groupDefaults) {
        defaults?.removeObject(forKey: localKey)
    }

    static func locallyAcknowledged(in defaults: UserDefaults? = groupDefaults) -> Set<String> {
        guard let defaults else { return [] }
        return Set(readLocal(from: defaults).keys)
    }

    /// How long a mark for an incident on `topic` is worth keeping.
    ///
    /// Dart caches each topic's timers under `topic_timers.<topic>` in
    /// shared_preferences, which on iOS is `UserDefaults.standard` with the
    /// `flutter.` prefix (`lib/core/notifications/topic_timer_cache.dart`).
    static func pruneWindow(
        topic: String?,
        defaults: UserDefaults = .standard
    ) -> TimeInterval {
        guard let topic, !topic.isEmpty else { return fallbackPruneWindow }
        return pruneWindow(topicTimers: defaults.string(forKey: "flutter.topic_timers.\(topic)"))
    }

    /// The cached value is `repeat_interval_s|max_ring_s|desk_timer_s`.
    static func pruneWindow(topicTimers: String?) -> TimeInterval {
        guard let topicTimers else { return fallbackPruneWindow }
        let parts = topicTimers.split(separator: "|").map { Int($0) }
        guard parts.count == 3, let maxRing = parts[1], let deskTimer = parts[2] else {
            return fallbackPruneWindow
        }
        return TimeInterval(maxRing + deskTimer)
    }

    private static func read(from defaults: UserDefaults) -> [String: Int] {
        (defaults.dictionary(forKey: key) as? [String: Int]) ?? [:]
    }

    private static func readLocal(from defaults: UserDefaults) -> [String: Int] {
        (defaults.dictionary(forKey: localKey) as? [String: Int]) ?? [:]
    }
}
