import AlarmKit
import AppIntents
import SwiftUI
import WidgetKit

/// AlarmKit's own Live Activity for a ringing alarm.
///
/// The system owns this one end to end. Declaring it here is what lets the
/// ringing alarm wear the app's face and colours instead of the stock
/// countdown. The Stop button is the `stopIntent` on the configuration, so
/// there is no button to add here.
@available(iOS 26.0, *)
struct AlarmActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<IncidentAlarmMetadata>.self) { context in
            HStack(spacing: 14) {
                FaceView(face: .alarmed, size: 52)
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.attributes.presentation.alert.title)
                        .font(.headline)
                        .lineLimit(2)
                    if let topic = context.attributes.metadata?.topic, !topic.isEmpty {
                        Text(topic)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .activityBackgroundTint(CritAlarmPalette.cream)
            .activitySystemActionForegroundColor(CritAlarmPalette.ink)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    FaceView(face: .alarmed, size: 44)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.presentation.alert.title)
                        .font(.headline)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                FaceView(face: .alarmed, size: 20)
            } compactTrailing: {
                Image(systemName: "bell.fill")
            } minimal: {
                FaceView(face: .alarmed, size: 20)
            }
            .keylineTint(CritAlarmPalette.crit)
        }
    }
}
