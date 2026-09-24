import AppIntents
import SwiftUI
import WidgetKit

// The pieces the three home and lock screen widgets share. Colours and faces
// come from FaceView.swift so a widget reads as the same app as the live card.

extension CritAlarmFace {
    /// The face for what a widget shows: ringing is alarmed, awake is acked,
    /// nothing going is calm.
    static func forIncident(_ incident: WidgetIncident?) -> CritAlarmFace {
        switch incident?.state {
        case WidgetIncident.open: return .alarmed
        case WidgetIncident.acked: return .acked
        default: return .calm
        }
    }
}

/// Light and dark values from `lib/design/tokens/colors.dart`. The face and
/// state colours stay the same in both, as they do in the app.
enum WidgetColors {
    /// `cream` light, `surface` dark.
    static let background = adaptive(light: 0xF7F2E9, dark: 0x241D18)
    /// `ink`.
    static let ink = adaptive(light: 0x1A140F, dark: 0xF7F1EA)
    /// `ink3`.
    static let muted = adaptive(light: 0x6E543F, dark: 0x9A8877)
    /// `hairline` light, a white line dark.
    static let hairline = adaptive(light: 0x1A140F, dark: 0xFFFFFF, lightAlpha: 0.14, darkAlpha: 0.12)

    private static func adaptive(
        light: UInt32, dark: UInt32, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1
    ) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? uiColor(dark, alpha: darkAlpha)
                : uiColor(light, alpha: lightAlpha)
        })
    }

    private static func uiColor(_ hex: UInt32, alpha: CGFloat) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension View {
    /// The home screen card behind every system-family widget (G7).
    func homeWidgetBackground() -> some View {
        containerBackground(for: .widget) { WidgetColors.background }
    }
}

/// "Ringing", "Awake" or "Quiet" in the state's own colour, the same capsule
/// the live card carries.
struct StateWord: View {
    let incident: WidgetIncident?
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        let face = CritAlarmFace.forIncident(incident)
        let word = Text(WidgetDisplay.stateWord(incident).uppercased())
            .font(.system(size: 10, weight: .bold))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
        if renderingMode == .fullColor {
            word
                .background(incident == nil ? WidgetColors.hairline : face.canvas, in: Capsule())
                .foregroundStyle(incident == nil ? WidgetColors.muted : face.stroke)
        } else {
            // A filled capsule turns into a blob when tinted. An outline
            // keeps the word readable and takes the accent colour.
            word
                .overlay(Capsule().stroke(lineWidth: 1))
                .widgetAccentable()
        }
    }
}

/// One topic in the list widget: face, name, state, and what is going on.
struct TopicRow: View {
    let topic: WidgetTopic

    var body: some View {
        HStack(spacing: 10) {
            FaceView(face: .forIncident(topic.incident), size: 22)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(topic.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(WidgetColors.ink)
                        .lineLimit(1)
                    StateWord(incident: topic.incident)
                    Spacer(minLength: 4)
                    if let incident = topic.incident {
                        RunningTime(incident: incident)
                    }
                }
                if let incident = topic.incident {
                    Text(incident.title)
                        .font(.caption)
                        .foregroundStyle(WidgetColors.muted)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// How long the incident has been going, as a running clock ("11:24",
/// "1:09:12"). A relative date ("11 min, 24 sec") does not fit beside a row
/// and gets cut, so the tight spots use this.
struct RunningTime: View {
    let incident: WidgetIncident

    var body: some View {
        if incident.openedAt > 0 {
            Text(openedDate(incident), style: .timer)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(WidgetColors.muted)
                .lineLimit(1)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 60, alignment: .trailing)
        }
    }
}

/// When the incident on a topic opened.
func openedDate(_ incident: WidgetIncident) -> Date {
    Date(timeIntervalSince1970: TimeInterval(incident.openedAt))
}

/// A face and one short line, for the states with nothing to list.
struct EmptyState: View {
    let face: CritAlarmFace
    let message: String
    var faceSize: CGFloat = 36

    var body: some View {
        VStack(spacing: 8) {
            FaceView(face: face, size: faceSize)
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(WidgetColors.ink)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The copy the empty states use.
enum WidgetCopy {
    static let connect = "Open Crit Alarm to connect"
    static let allQuiet = "All quiet"
    static let noTopics = "No topics yet"
    static let topicNotFound = "Topic not found"
    static let chooseTopic = "Choose a topic"

    static func more(_ count: Int) -> String { "+\(count) more" }
    static func open(_ count: Int) -> String { "\(count) open" }
}

/// "I'm up" or "Done", the same capsules and the same intents as the live
/// card. Nothing here talks to the server itself.
struct IncidentActionButton: View {
    let incident: WidgetIncident
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        if let title = WidgetDisplay.buttonTitle(incident) {
            if renderingMode != .fullColor {
                // Tinted or clear: an outlined capsule in the accent colour.
                Group {
                    if incident.state == WidgetIncident.open {
                        Button(intent: AckAlarmIntent(incidentId: incident.id)) { label(title) }
                    } else {
                        Button(intent: CloseIncidentIntent(incidentId: incident.id)) { label(title) }
                    }
                }
                .buttonStyle(.plain)
                .overlay(Capsule().stroke(lineWidth: 1.5))
                .widgetAccentable()
            } else if incident.state == WidgetIncident.open {
                Button(intent: AckAlarmIntent(incidentId: incident.id)) { label(title) }
                    .buttonStyle(.plain)
                    .background(CritAlarmFace.alarmed.canvas, in: Capsule())
                    .foregroundStyle(CritAlarmFace.alarmed.stroke)
            } else {
                Button(intent: CloseIncidentIntent(incidentId: incident.id)) { label(title) }
                    .buttonStyle(.plain)
                    .background(CritAlarmPalette.cobalt, in: Capsule())
                    .foregroundStyle(CritAlarmPalette.onHighlight)
            }
        }
    }

    private func label(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
    }
}
