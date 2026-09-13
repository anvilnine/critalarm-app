import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// The acknowledge card.
///
/// One button, Acknowledge, which is stage 2 of the state machine in api.md
/// §3.2. It opens nothing: the intent runs in the app's process and puts a
/// close on the shared queue.
@available(iOS 16.2, *)
struct IncidentActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CritAlarmIncidentAttributes.self) { context in
            LockScreenCard(context: context)
                .activityBackgroundTint(CritAlarmPalette.cream)
                .activitySystemActionForegroundColor(CritAlarmPalette.ink)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    FaceView(face: .forIncident(context.state.state), size: 44)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    StatusPill(state: context.state.state)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.title)
                        .font(.headline)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.state == .acked {
                        AcknowledgeButton(incidentId: context.attributes.incidentId)
                    } else {
                        Text(context.attributes.topic)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                FaceView(face: .forIncident(context.state.state), size: 20)
            } compactTrailing: {
                Text(context.attributes.topic)
                    .font(.caption2)
                    .lineLimit(1)
            } minimal: {
                FaceView(face: .forIncident(context.state.state), size: 20)
            }
            .keylineTint(CritAlarmFace.forIncident(context.state.state).canvas)
        }
    }
}

@available(iOS 16.2, *)
private struct LockScreenCard: View {
    let context: ActivityViewContext<CritAlarmIncidentAttributes>

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            FaceView(face: .forIncident(context.state.state), size: 52)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(context.attributes.topic.isEmpty ? "Crit Alarm" : context.attributes.topic)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(CritAlarmPalette.ink.opacity(0.6))
                    StatusPill(state: context.state.state)
                }
                Text(context.state.title)
                    .font(.headline)
                    .foregroundStyle(CritAlarmPalette.ink)
                    .lineLimit(2)
                Text(context.state.openedAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(CritAlarmPalette.ink.opacity(0.6))
            }

            Spacer(minLength: 0)

            if context.state.state == .acked {
                AcknowledgeButton(incidentId: context.attributes.incidentId)
            }
        }
        .padding(16)
    }
}

@available(iOS 16.2, *)
private struct AcknowledgeButton: View {
    let incidentId: String

    var body: some View {
        Button(intent: AcknowledgeIncidentIntent(incidentId: incidentId)) {
            Text("Acknowledge")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .foregroundStyle(CritAlarmPalette.onHighlight)
        .background(CritAlarmPalette.cobalt, in: Capsule())
    }
}

@available(iOS 16.2, *)
private struct StatusPill: View {
    let state: IncidentActivityState

    private var label: String {
        switch state {
        case .open: return "Ringing"
        case .acked: return "Awake"
        case .closed: return "Closed"
        case .expired: return "Missed"
        }
    }

    var body: some View {
        Text(label.uppercased())
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(CritAlarmFace.forIncident(state).canvas, in: Capsule())
            .foregroundStyle(CritAlarmFace.forIncident(state).stroke)
    }
}
