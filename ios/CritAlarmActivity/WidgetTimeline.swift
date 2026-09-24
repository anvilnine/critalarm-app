import SwiftUI
import WidgetKit

/// One moment of widget: the snapshot to draw, and for the per-topic widget
/// the topic it was set up for. A nil snapshot draws the signed-out view.
struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
    /// The topic the per-topic widget shows. Nil on the other widgets, and on
    /// a per-topic widget nobody has picked a topic for.
    var topic: String? = nil
}

/// Where every widget gets its snapshot.
///
/// The store first. Only when that is stale, and the app left a session in
/// the keychain, does the widget ask the server itself. A missing or
/// signed-out snapshot is never stale, so a widget placed before the app was
/// ever opened never makes a call.
enum SnapshotLoader {
    /// All widget kinds share one extension process. When they reload
    /// together, they share one fetch.
    private static let gate = FetchGate()

    static func load(now: Date) async -> WidgetSnapshot? {
        let stored = WidgetSnapshotStore.read()
        guard let stored, stored.isStale(now: now), let session = NseCredentials.read() else {
            return stored
        }
        guard let fresh = await gate.fetch(session: session, now: now) else { return stored }
        // A push or a button may have patched the store while the fetch was
        // out. That patch is newer than what the server said a moment ago.
        let current = WidgetSnapshotStore.read()
        if let current, current.updatedAt != stored.updatedAt { return current }
        // No reload: this is already inside one. The other widget kinds pick
        // the fresh snapshot up on their own next reload.
        WidgetSnapshotStore.write(fresh, reload: false)
        return fresh
    }

    /// The next time WidgetKit should ask again (D6). iOS may stretch it.
    static func nextReload(after now: Date) -> Date {
        now.addingTimeInterval(15 * 60)
    }
}

private actor FetchGate {
    private var running: Task<WidgetSnapshot?, Never>?

    func fetch(session: NseCredentials.Session, now: Date) async -> WidgetSnapshot? {
        if let running { return await running.value }
        let task = Task { await WidgetFetcher.fetch(session: session, now: now) }
        running = task
        let result = await task.value
        running = nil
        return result
    }
}

/// The all-topics list and the open count.
struct TopicsProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: Date(), snapshot: .gallerySample)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        if context.isPreview {
            completion(SnapshotEntry(date: Date(), snapshot: .forGallery()))
            return
        }
        Task {
            let now = Date()
            completion(SnapshotEntry(date: now, snapshot: await SnapshotLoader.load(now: now)))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        Task {
            let now = Date()
            let entry = SnapshotEntry(date: now, snapshot: await SnapshotLoader.load(now: now))
            completion(Timeline(entries: [entry], policy: .after(SnapshotLoader.nextReload(after: now))))
        }
    }
}

/// The per-topic widget, set up with `SelectTopicIntent`.
struct TopicProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: Date(), snapshot: .gallerySample, topic: "prod")
    }

    func snapshot(for configuration: SelectTopicIntent, in context: Context) async -> SnapshotEntry {
        if context.isPreview {
            let snapshot = WidgetSnapshot.forGallery()
            return SnapshotEntry(date: Date(), snapshot: snapshot, topic: snapshot.topics.first?.name)
        }
        let now = Date()
        return SnapshotEntry(
            date: now, snapshot: await SnapshotLoader.load(now: now), topic: configuration.topic?.id
        )
    }

    func timeline(for configuration: SelectTopicIntent, in context: Context) async -> Timeline<SnapshotEntry> {
        let now = Date()
        let entry = SnapshotEntry(
            date: now, snapshot: await SnapshotLoader.load(now: now), topic: configuration.topic?.id
        )
        return Timeline(entries: [entry], policy: .after(SnapshotLoader.nextReload(after: now)))
    }
}

extension WidgetSnapshot {
    /// The gallery shows the user's own topics when the app has written them,
    /// and the made-up sample otherwise. It never fetches.
    static func forGallery() -> WidgetSnapshot {
        if let stored = WidgetSnapshotStore.read(), stored.connected, !stored.topics.isEmpty {
            return stored
        }
        return gallerySample
    }

    /// What the widget gallery shows before anyone has placed a widget. Made
    /// up, and never written to the store.
    static var gallerySample: WidgetSnapshot {
        let now = WidgetSnapshot.seconds(Date())
        return WidgetSnapshot(
            updatedAt: now,
            connected: true,
            openCount: 3,
            topics: [
                WidgetTopic(
                    name: "prod", critical: true, count: 2,
                    incident: WidgetIncident(
                        id: "sample-open", state: WidgetIncident.open,
                        title: "Database down", openedAt: now - 300, ackedAt: nil
                    )
                ),
                WidgetTopic(
                    name: "backups", critical: false, count: 1,
                    incident: WidgetIncident(
                        id: "sample-acked", state: WidgetIncident.acked,
                        title: "nas-backup exited 1", openedAt: now - 3_600, ackedAt: now - 3_480
                    )
                ),
                WidgetTopic(name: "staging", critical: false, count: 0, incident: nil),
            ]
        )
    }
}
