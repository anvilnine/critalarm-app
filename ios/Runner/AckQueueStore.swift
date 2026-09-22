import Foundation

/// The same queue Dart uses, written from the native side.
///
/// The ACK action on a notification runs with `foreground: false`, so it can
/// land with no Flutter engine up. The entry goes on this list, which is the
/// exact shape `AckQueue` in Dart reads, and the next launch (or the running
/// app, which is told about it) sends it.
///
/// Keep the field names in step with `lib/core/ack/ack_queue_entry.dart`.
enum AckQueueStore {
    /// `AckQueue.storageKey` in Dart, with the shared_preferences prefix.
    static let key = "flutter.ack_queue_v1"

    /// The same two seconds the Dart queue waits after one failure.
    static let firstRetryMs = 2_000

    static func enqueue(
        action: String,
        incidentId: String,
        alarmFiredAtMs: Int? = nil,
        defaults: UserDefaults = .standard
    ) {
        let now = Int(Date().timeIntervalSince1970 * 1000)
        var entry: [String: Any] = [
            "id": "\(now)-native-\(incidentId)-\(action)",
            "action": action,
            "incident_id": incidentId,
            "enqueued_at_ms": now,
            "attempts": 1,
            "next_attempt_at_ms": now + firstRetryMs,
        ]
        if let alarmFiredAtMs { entry["alarm_fired_at_ms"] = alarmFiredAtMs }

        var entries = read(from: defaults)
        entries.append(entry)
        write(entries, to: defaults)
        NSLog("CritAlarmAck: ack_queued_native action=%@ incident_id=%@", action, incidentId)
    }

    /// Takes every entry for `incidentId` with this `action` off the queue.
    /// For after `NativeAckSender` has already landed it, so Dart does not
    /// send it a second time.
    static func remove(
        incidentId: String,
        action: String,
        defaults: UserDefaults = .standard
    ) {
        let entries = read(from: defaults)
        let kept = entries.filter {
            !($0["incident_id"] as? String == incidentId && $0["action"] as? String == action)
        }
        guard kept.count != entries.count else { return }
        write(kept, to: defaults)
    }

    static func pendingCount(defaults: UserDefaults = .standard) -> Int {
        read(from: defaults).count
    }

    static func debugEntries(defaults: UserDefaults = .standard) -> [[String: Any]] {
        read(from: defaults).compactMap { entry in
            guard let action = entry["action"] as? String,
                  let incidentId = entry["incident_id"] as? String,
                  let attempts = entry["attempts"] as? Int,
                  let nextMs = entry["next_attempt_at_ms"] as? Int else { return nil }
            var row: [String: Any] = [
                "action": action,
                "incident_id": incidentId,
                "attempts": attempts,
                "next_attempt_at": nextMs / 1_000,
            ]
            if let error = entry["last_error"] as? String { row["last_error"] = error }
            return row
        }
    }

    private static func read(from defaults: UserDefaults) -> [[String: Any]] {
        guard let raw = defaults.string(forKey: key),
              let data = raw.data(using: .utf8),
              let decoded = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return [] }
        return decoded
    }

    /// An empty list is written as no key at all, the way Dart's `_write` does.
    private static func write(_ entries: [[String: Any]], to defaults: UserDefaults) {
        if entries.isEmpty {
            defaults.removeObject(forKey: key)
            return
        }
        guard let data = try? JSONSerialization.data(withJSONObject: entries),
              let json = String(data: data, encoding: .utf8)
        else { return }
        defaults.set(json, forKey: key)
    }
}
