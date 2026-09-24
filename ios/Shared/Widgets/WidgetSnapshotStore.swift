import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Where the widget snapshot lives: the app group, key `widget_snapshot_v1`,
/// as a JSON string. The app, the notification extension and the widget
/// extension all read and write it here.
///
/// Every function takes the defaults to use, so a test can run against its own
/// suite the way `OpenIncidentStoreTests` does. Every change asks WidgetKit to
/// draw the widgets again.
enum WidgetSnapshotStore {
    static let key = "widget_snapshot_v1"

    static var groupDefaults: UserDefaults? { UserDefaults(suiteName: AckedIncidentStore.appGroup) }

    /// One writer at a time inside a process. The app and its extensions are
    /// separate processes; a lost patch there heals on the next write.
    private static let lock = NSLock()

    static func read(in defaults: UserDefaults? = groupDefaults) -> WidgetSnapshot? {
        guard let json = defaults?.string(forKey: key), let data = json.data(using: .utf8) else {
            return nil
        }
        return WidgetSnapshot.decode(data)
    }

    static func write(_ snapshot: WidgetSnapshot, in defaults: UserDefaults? = groupDefaults) {
        lock.lock()
        save(snapshot, in: defaults)
        lock.unlock()
        reloadWidgets()
    }

    /// Stores a snapshot Dart built. Anything that does not decode is refused.
    @discardableResult
    static func writeJSON(_ json: String, in defaults: UserDefaults? = groupDefaults) -> Bool {
        guard let data = json.data(using: .utf8), WidgetSnapshot.decode(data) != nil else {
            NSLog("CritAlarmWidgets: widget_snapshot_refused")
            return false
        }
        lock.lock()
        defaults?.set(json, forKey: key)
        lock.unlock()
        reloadWidgets()
        return true
    }

    /// Signed out. Every widget says so and nothing is fetched.
    static func clear(now: Date = Date(), in defaults: UserDefaults? = groupDefaults) {
        write(.disconnected(now: now), in: defaults)
    }

    /// Runs one patch against what is stored. A fetch that is needed is left
    /// to the widget's next reload: the stored snapshot gets `updated_at = 0`,
    /// which `isStale` reads as stale.
    @discardableResult
    static func patch(
        _ operation: WidgetPatch,
        now: Date = Date(),
        in defaults: UserDefaults? = groupDefaults
    ) -> WidgetPatchResult {
        lock.lock()
        let current = read(in: defaults)
        let result = operation.apply(to: current, now: now)
        switch result {
        case let .changed(snapshot):
            save(snapshot, in: defaults)
        case let .needsFetch(partial):
            if var stale = partial ?? current {
                stale.updatedAt = 0
                save(stale, in: defaults)
            }
        case .unchanged:
            break
        }
        lock.unlock()
        NSLog("CritAlarmWidgets: widget_snapshot_patch result=%@", "\(result.name)")
        if result != .unchanged { reloadWidgets() }
        return result
    }

    /// The incident object `GET /v1/incidents/{id}` answered. Closed and
    /// expired take the incident off its topic.
    static func upsertIncident(
        json: Data,
        now: Date,
        in defaults: UserDefaults? = groupDefaults
    ) {
        guard let record = WidgetSnapshot.incidentRecord(fromIncidentJSON: json) else { return }
        switch record.state {
        case WidgetIncident.open, WidgetIncident.acked:
            patch(.upsert(record), now: now, in: defaults)
        default:
            patch(.ended(record.id), now: now, in: defaults)
        }
    }

    /// When [incidentId] was acknowledged, if the snapshot knows.
    static func ackedAt(incidentId: String, in defaults: UserDefaults? = groupDefaults) -> Date? {
        guard let snapshot = read(in: defaults),
              let at = snapshot.index(of: incidentId),
              let seconds = snapshot.topics[at].incident?.ackedAt
        else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(seconds))
    }

    static func reloadWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    private static func save(_ snapshot: WidgetSnapshot, in defaults: UserDefaults?) {
        guard let json = String(data: snapshot.encoded(), encoding: .utf8) else { return }
        defaults?.set(json, forKey: key)
    }
}

private extension WidgetPatchResult {
    var name: String {
        switch self {
        case .changed: return "changed"
        case .unchanged: return "unchanged"
        case .needsFetch: return "needs_fetch"
        }
    }
}
