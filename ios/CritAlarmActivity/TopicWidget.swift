import AppIntents
import SwiftUI
import WidgetKit

/// One topic, picked in the widget's settings. Shows the incident on it and
/// the one button that moves it along: "I'm up" while it rings, "Done" once
/// someone is awake. Tapping anywhere else opens the topic.
struct TopicWidget: Widget {
    static let kind = "app.critalarm.widget.topic"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: SelectTopicIntent.self, provider: TopicProvider()) { entry in
            TopicWidgetView(snapshot: entry.snapshot, topicName: entry.topic)
        }
        .configurationDisplayName("Topic")
        .description("One topic, with I'm up and Done buttons.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TopicWidgetView: View {
    let snapshot: WidgetSnapshot?
    let topicName: String?
    @Environment(\.widgetFamily) private var family

    var body: some View {
        content.homeWidgetBackground()
    }

    @ViewBuilder
    private var content: some View {
        if let snapshot, snapshot.locked {
            LockedState()
        } else if let snapshot, snapshot.connected {
            if let topicName {
                if let topic = snapshot.topics.first(where: { $0.name == topicName }) {
                    Group {
                        if family == .systemSmall {
                            SmallTopic(topic: topic)
                        } else {
                            MediumTopic(topic: topic)
                        }
                    }
                    .widgetURL(WidgetLink.url(topic: topic.name))
                } else {
                    EmptyState(face: .worried, message: WidgetCopy.topicNotFound)
                        .widgetURL(WidgetLink.homeURL)
                }
            } else {
                EmptyState(face: .watching, message: WidgetCopy.chooseTopic)
                    .widgetURL(WidgetLink.homeURL)
            }
        } else {
            EmptyState(face: .watching, message: WidgetCopy.connect)
                .widgetURL(WidgetLink.homeURL)
        }
    }
}

/// The incident's title, or "All quiet" on a quiet topic.
private struct IncidentTitle: View {
    let topic: WidgetTopic
    let lines: Int

    var body: some View {
        Text(topic.incident?.title ?? WidgetCopy.allQuiet)
            .font(.headline)
            .foregroundStyle(WidgetColors.ink)
            .lineLimit(lines)
            .minimumScaleFactor(0.85)
    }
}

private struct SmallTopic: View {
    let topic: WidgetTopic

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top) {
                FaceView(face: .forIncident(topic.incident), size: 28)
                Spacer(minLength: 4)
                StateWord(incident: topic.incident)
            }
            HStack(spacing: 4) {
                Text(topic.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WidgetColors.muted)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let incident = topic.incident { RunningTime(incident: incident) }
            }
            .padding(.top, 2)
            // Two lines of title before the spacer gives anything up.
            IncidentTitle(topic: topic, lines: 2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if let incident = topic.incident {
                IncidentActionButton(incident: incident)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct MediumTopic: View {
    let topic: WidgetTopic

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            FaceView(face: .forIncident(topic.incident), size: 52)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(topic.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WidgetColors.muted)
                        .lineLimit(1)
                    StateWord(incident: topic.incident)
                }
                IncidentTitle(topic: topic, lines: 2)
                Spacer(minLength: 0)
                if let incident = topic.incident {
                    HStack(alignment: .center) {
                        RunningTime(incident: incident)
                        Spacer(minLength: 8)
                        IncidentActionButton(incident: incident)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#if DEBUG
#Preview("Topic small", as: .systemSmall) {
    TopicWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .gallerySample, topic: "prod")
    SnapshotEntry(date: .now, snapshot: .gallerySample, topic: "backups")
    SnapshotEntry(date: .now, snapshot: .gallerySample, topic: "staging")
    SnapshotEntry(date: .now, snapshot: .gallerySample, topic: "gone")
}

#Preview("Topic medium", as: .systemMedium) {
    TopicWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .gallerySample, topic: "prod")
    SnapshotEntry(date: .now, snapshot: .gallerySample, topic: "backups")
    SnapshotEntry(date: .now, snapshot: nil, topic: "prod")
}

#Preview("Locked", as: .systemSmall) {
    TopicWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: WidgetSnapshot(updatedAt: 0, connected: true, openCount: 0, topics: [], locked: true))
}
#endif
