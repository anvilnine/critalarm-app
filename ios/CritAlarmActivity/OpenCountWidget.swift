import SwiftUI
import WidgetKit

/// How many incidents are open, for the lock screen (and a small home screen
/// tile). Tapping it opens Home.
struct OpenCountWidget: Widget {
    static let kind = "app.critalarm.widget.count"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: TopicsProvider()) { entry in
            OpenCountView(snapshot: entry.snapshot)
                .widgetURL(entry.snapshot?.locked == true ? WidgetLink.paywallURL : WidgetLink.homeURL)
        }
        .configurationDisplayName("Open incidents")
        .description("How many incidents are open right now.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .systemSmall])
    }
}

struct OpenCountView: View {
    let snapshot: WidgetSnapshot?
    @Environment(\.widgetFamily) private var family

    private var isLocked: Bool { snapshot?.locked == true }

    private var connected: WidgetSnapshot? {
        guard let snapshot, snapshot.connected else { return nil }
        return snapshot
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            circular.containerBackground(for: .widget) { AccessoryWidgetBackground() }
        case .accessoryRectangular:
            rectangular.containerBackground(for: .widget) { Color.clear }
        case .accessoryInline:
            inline.containerBackground(for: .widget) { Color.clear }
        default:
            small.homeWidgetBackground()
        }
    }

    // MARK: lock screen

    @ViewBuilder
    private var circular: some View {
        if isLocked {
            Image(systemName: "lock.fill").font(.title3)
        } else if let snapshot = connected {
            VStack(spacing: 1) {
                FaceView(face: .forIncident(WidgetDisplay.worstIncident(snapshot)), size: 22)
                    .widgetAccentable()
                Text("\(snapshot.openCount)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .accessibilityLabel(snapshot.openCount > 0 ? WidgetCopy.open(snapshot.openCount) : WidgetCopy.allQuiet)
        } else {
            Text(WidgetCopy.connect)
                .font(.system(size: 9, weight: .semibold))
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .minimumScaleFactor(0.7)
                .padding(4)
        }
    }

    @ViewBuilder
    private var rectangular: some View {
        if isLocked {
            Label(WidgetCopy.lockedShort, systemImage: "lock.fill").font(.headline)
        } else if let snapshot = connected {
            HStack(spacing: 8) {
                FaceView(face: .forIncident(WidgetDisplay.worstIncident(snapshot)), size: 30)
                    .widgetAccentable()
                VStack(alignment: .leading, spacing: 0) {
                    Text(snapshot.openCount > 0 ? WidgetCopy.open(snapshot.openCount) : WidgetCopy.allQuiet)
                        .font(.headline)
                        .lineLimit(1)
                    if snapshot.openCount > 0, let top = snapshot.topics.first, let incident = top.incident {
                        Text(top.name)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Text(incident.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
        } else {
            Text(WidgetCopy.connect)
                .font(.headline)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var inline: some View {
        if isLocked {
            Label("Crit Alarm \(WidgetCopy.lockedShort)", systemImage: "lock.fill")
        } else if let snapshot = connected {
            Text(snapshot.openCount > 0
                 ? "Crit Alarm: \(WidgetCopy.open(snapshot.openCount))"
                 : "Crit Alarm: \(WidgetCopy.allQuiet)")
        } else {
            Text(WidgetCopy.connect)
        }
    }

    // MARK: home screen

    @ViewBuilder
    private var small: some View {
        if isLocked {
            LockedState()
        } else if let snapshot = connected {
            SmallCount(snapshot: snapshot)
        } else {
            EmptyState(face: .watching, message: WidgetCopy.connect)
        }
    }
}

#if DEBUG
#Preview("Count circular", as: .accessoryCircular) {
    OpenCountWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .gallerySample)
    SnapshotEntry(date: .now, snapshot: nil)
}

#Preview("Count rectangular", as: .accessoryRectangular) {
    OpenCountWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .gallerySample)
    SnapshotEntry(date: .now, snapshot: nil)
}

#Preview("Count inline", as: .accessoryInline) {
    OpenCountWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .gallerySample)
}

#Preview("Count locked", as: .accessoryCircular) {
    OpenCountWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: WidgetSnapshot(updatedAt: 0, connected: true, openCount: 0, topics: [], locked: true))
}
#endif
