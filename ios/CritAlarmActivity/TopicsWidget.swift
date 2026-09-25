import SwiftUI
import WidgetKit

/// Every topic at a glance. Small shows the open count and the top topic;
/// medium and large list topics, ringing first, each row opening its topic.
struct TopicsWidget: Widget {
    static let kind = "app.critalarm.widget.topics"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: TopicsProvider()) { entry in
            TopicsWidgetView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("Topics")
        .description("Your topics, ringing ones first.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct TopicsWidgetView: View {
    let snapshot: WidgetSnapshot?
    @Environment(\.widgetFamily) private var family

    var body: some View {
        content.homeWidgetBackground()
    }

    @ViewBuilder
    private var content: some View {
        if let snapshot, snapshot.locked {
            LockedState()
        } else if let snapshot, snapshot.connected {
            if snapshot.topics.isEmpty {
                EmptyState(face: .watching, message: WidgetCopy.noTopics)
                    .widgetURL(WidgetLink.homeURL)
            } else if family == .systemSmall {
                SmallCount(snapshot: snapshot)
                    .widgetURL(WidgetLink.homeURL)
            } else {
                // Rows open their topic; the header and the gaps open Home.
                TopicList(snapshot: snapshot, limit: WidgetDisplay.rowLimit(family: familyName))
                    .widgetURL(WidgetLink.homeURL)
            }
        } else {
            EmptyState(face: .watching, message: WidgetCopy.connect)
                .widgetURL(WidgetLink.homeURL)
        }
    }

    private var familyName: String {
        switch family {
        case .systemMedium: return "systemMedium"
        case .systemLarge: return "systemLarge"
        default: return "systemSmall"
        }
    }
}

/// The open count, big, over the topic at the top of the list.
struct SmallCount: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        let top = snapshot.topics.first
        let incident = snapshot.openCount > 0 ? top?.incident : nil
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                FaceView(face: .forIncident(WidgetDisplay.worstIncident(snapshot)), size: 36)
                Spacer(minLength: 0)
                if let incident { StateWord(incident: incident) }
            }
            Spacer(minLength: 4)
            if snapshot.openCount > 0 {
                Text("\(snapshot.openCount)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(WidgetColors.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(top.map { "open · \($0.name)" } ?? "open")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WidgetColors.muted)
                    .lineLimit(1)
            } else {
                Text(WidgetCopy.allQuiet)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(WidgetColors.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(WidgetCopy.open(0))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WidgetColors.muted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// Medium and large: rows in display order, "+N more" when they do not fit.
struct TopicList: View {
    let snapshot: WidgetSnapshot
    let limit: Int

    var body: some View {
        let cut = WidgetDisplay.rows(snapshot, limit: limit)
        // Large has room to breathe; medium has to fit three rows.
        VStack(alignment: .leading, spacing: limit > 3 ? 11 : 6) {
            HStack {
                Text(snapshot.openCount > 0 ? WidgetCopy.open(snapshot.openCount) : WidgetCopy.allQuiet)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(WidgetColors.ink)
                Spacer()
                if cut.more > 0 {
                    Text(WidgetCopy.more(cut.more))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WidgetColors.muted)
                }
            }
            ForEach(cut.rows, id: \.name) { topic in
                Link(destination: WidgetLink.url(topic: topic.name)) {
                    TopicRow(topic: topic)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#if DEBUG
#Preview("List small", as: .systemSmall) {
    TopicsWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .gallerySample)
    SnapshotEntry(date: .now, snapshot: nil)
}

#Preview("List medium", as: .systemMedium) {
    TopicsWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .gallerySample)
}

#Preview("List large", as: .systemLarge) {
    TopicsWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .gallerySample)
}

#Preview("Locked", as: .systemSmall) {
    TopicsWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: WidgetSnapshot(updatedAt: 0, connected: true, openCount: 0, topics: [], locked: true))
}
#endif
