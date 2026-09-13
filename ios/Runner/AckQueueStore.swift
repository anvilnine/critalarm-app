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

    static func enqueue(action: String, incidentId: String, alarmFiredAtMs: Int? = nil) {
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

        let defaults = UserDefaults.standard
        var entries: [[String: Any]] = []
        if let raw = defaults.string(forKey: key),
           let data = raw.data(using: .utf8),
           let decoded = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            entries = decoded
        }
        entries.append(entry)

        guard let data = try? JSONSerialization.data(withJSONObject: entries),
              let json = String(data: data, encoding: .utf8)
        else { return }
        defaults.set(json, forKey: key)
        NSLog("CritAlarmAck: ack_queued_native action=%@ incident_id=%@", action, incidentId)
    }

    static func pendingCount() -> Int {
        guard let raw = UserDefaults.standard.string(forKey: key),
              let data = raw.data(using: .utf8),
              let decoded = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return 0 }
        return decoded.count
    }
}
