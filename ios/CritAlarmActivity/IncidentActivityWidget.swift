import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// The card left behind once the alarm has stopped.
///
/// Done on an acknowledged card is stage 2 of the state machine in api.md
/// §3.2, the one api.md calls "At my desk". I'm up on a silenced card is
/// stage 1. Neither opens anything: the intents run in the app's process and
/// put the action on the shared queue. A tap anywhere else opens the
/// incident through `critalarm://incidents/<id>`.
///
/// The Done button used to say Acknowledge, which was wrong twice over. The card only
/// appears once the incident is already acknowledged, and the word was long
/// enough that the capsule hyphenated it down the middle.
@available(iOS 16.2, *)
struct IncidentActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CritAlarmIncidentAttributes.self) { context in
            LockScreenCard(card: LiveCard(context))
                .activityBackgroundTint(CritAlarmPalette.cream)
                .activitySystemActionForegroundColor(CritAlarmPalette.ink)
                .widgetURL(WidgetLink.url(incidentId: context.attributes.incidentId))
        } dynamicIsland: { context in
            let card = LiveCard(context)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    FaceView(face: card.face, size: 44)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    // The topic sits under the pill. Above the title it cost
                    // the island a row and pushed the clock off the bottom.
                    VStack(alignment: .trailing, spacing: 4) {
                        StatusPill(card: card)
                        Text(card.topic.isEmpty ? "Crit Alarm" : card.topic)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(card.title)
                        .font(.headline)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    IslandBottom(card: card)
                }
            } compactLeading: {
                FaceView(face: card.face, size: 20)
            } compactTrailing: {
                liveTimer(card.timerStart)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(card.state == .open ? CritAlarmPalette.crit : .white)
                    .lineLimit(1)
                    .multilineTextAlignment(.trailing)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: 50)
            } minimal: {
                FaceView(face: card.face, size: 20)
            }
            .keylineTint(card.face.canvas)
            .widgetURL(WidgetLink.url(incidentId: context.attributes.incidentId))
        }
    }
}

/// Everything the card and the island draw, worked out once.
@available(iOS 16.2, *)
private struct LiveCard {
    let incidentId: String
    let topic: String
    let title: String
    let state: IncidentActivityState
    let openedAt: Date
    let ringsAgainInSeconds: Int?
    let isStale: Bool

    /// This phone's own time when it has one. A server `update` push clears
    /// it, and then the snapshot the app keeps in the app group still knows.
    let ackedAt: Date?

    init(_ context: ActivityViewContext<CritAlarmIncidentAttributes>) {
        incidentId = context.attributes.incidentId
        topic = context.attributes.topic
        title = LiveCard.localizedTitle(context.state.title, topic: context.attributes.topic)
        state = context.state.state
        openedAt = context.state.openedAt
        ringsAgainInSeconds = context.state.ringsAgainInSeconds
        isStale = context.isStale
        ackedAt = context.state.ackedAt
            ?? (context.state.state == .acked ? WidgetSnapshotStore.ackedAt(incidentId: incidentId) : nil)
    }

    /// The server's fixed English title for a `relay_content: none` card
    /// (api.md §5.3), rebuilt in the picked language. The topic is in the
    /// attributes, so only an exact match is replaced; any other title, the
    /// user's own included, stays as it came.
    static func localizedTitle(_ title: String, topic: String) -> String {
        guard !topic.isEmpty,
              title == NativeL10n.fill(NativeText.contentCriticalAlertOn.english, ["topic": topic])
        else { return title }
        return NativeL10n.text(.contentCriticalAlertOn, ["topic": topic])
    }

    var face: CritAlarmFace { .forIncident(state) }
    var pill: String { LiveCardText.pillLabel(state: state, isStale: isStale) }
    var timerStart: Date { LiveCardText.timerStart(state: state, openedAt: openedAt, ackedAt: ackedAt) }
    var button: LiveCardText.Button? {
        LiveCardText.button(state: state, silenced: ringsAgainInSeconds != nil)
    }
}

/// A clock that counts up from [start] by itself, with no push to redraw it.
///
/// A plain `Text`, so it can join the words around it on one line. On its
/// own a timer takes every point it is offered and pushes itself to the far
/// edge.
@available(iOS 16.2, *)
private func liveTimer(_ start: Date) -> Text {
    Text(timerInterval: start...Date.distantFuture, countsDown: false)
        .monospacedDigit()
}

@available(iOS 16.2, *)
private struct LockScreenCard: View {
    let card: LiveCard

    private let muted = CritAlarmPalette.ink.opacity(0.6)

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            FaceView(face: card.face, size: 52)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(card.topic.isEmpty ? "Crit Alarm" : card.topic)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(muted)
                        .lineLimit(1)
                    StatusPill(card: card)
                }
                Text(card.title)
                    .font(.headline)
                    .foregroundStyle(CritAlarmPalette.ink)
                    .lineLimit(2)
                detail
                    .font(.caption2)
                    .foregroundStyle(muted)
            }

            Spacer(minLength: 8)

            if let button = card.button {
                CardButton(kind: button, incidentId: card.incidentId, topic: card.topic)
                    .layoutPriority(1)
            }
        }
        .padding(16)
    }

    @ViewBuilder
    private var detail: some View {
        if let seconds = card.ringsAgainInSeconds, card.state == .open {
            Text(silencedText(seconds))
                .lineLimit(2)
        } else if card.state == .acked, card.isStale {
            Text(LiveCardText.staleLine)
                .lineLimit(2)
        } else if card.state == .acked, let ackedAt = card.ackedAt {
            // Two lines: beside the Done button one line cuts the clock off.
            VStack(alignment: .leading, spacing: 2) {
                Text(LiveCardText.ackedLine(ackedAt))
                around(.cardAwakeFor) {
                    liveTimer(ackedAt).fontWeight(.semibold).foregroundColor(CritAlarmPalette.ink)
                }
            }
            .lineLimit(1)
        } else if card.state == .acked {
            // Acknowledged somewhere this phone did not see: no time to
            // show, so the open time stays instead.
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: NativeL10n.text(.cardAcknowledged))
                around(.cardOpenedAgo) { Text(card.openedAt, style: .relative) }
            }
            .lineLimit(1)
        } else if card.state == .open {
            around(.cardOpenFor) {
                liveTimer(card.openedAt).fontWeight(.semibold).foregroundColor(CritAlarmPalette.ink)
            }
            .lineLimit(1)
        } else {
            Text(card.openedAt, style: .relative)
        }
    }
}

/// The expanded island's bottom row: what the card says, and its button.
@available(iOS 16.2, *)
private struct IslandBottom: View {
    let card: LiveCard

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                if let line {
                    Text(line)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                clockLine
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let button = card.button {
                CardButton(kind: button, incidentId: card.incidentId, topic: card.topic)
            }
        }
        .padding(.horizontal, 4)
    }

    /// Nothing on a ringing card: the pill already says so.
    private var line: String? {
        if card.state == .open, let seconds = card.ringsAgainInSeconds {
            return NativeL10n.text(.cardSilencedShort, ["seconds": "\(seconds)"])
        }
        if card.state == .acked {
            if card.isStale { return LiveCardText.staleLine }
            if let ackedAt = card.ackedAt { return LiveCardText.ackedLine(ackedAt) }
            return NativeL10n.text(.cardAcknowledged)
        }
        return nil
    }

    /// Says what the clock counts, so it never reads as a countdown.
    private var clockLine: Text {
        let words: NativeText = card.state == .acked && card.ackedAt != nil ? .cardAwakeFor : .cardOpenFor
        let (before, after) = NativeL10n.around(words, placeholder: "time")
        return Text(verbatim: before).font(.caption).foregroundColor(.secondary)
            + liveTimer(card.timerStart).font(.title3.weight(.semibold))
            + Text(verbatim: after).font(.caption).foregroundColor(.secondary)
    }
}

/// [id]'s words with [middle] where its `{time}` is: a live timer or a
/// relative date joined to the words on one line.
@available(iOS 16.2, *)
private func around(_ id: NativeText, middle: () -> Text) -> Text {
    let (before, after) = NativeL10n.around(id, placeholder: "time")
    return Text(verbatim: before) + middle() + Text(verbatim: after)
}

/// The line the card carries after Stop, in the picked language. The same
/// sentence is in `assets/translations/en.json` under `native.card`.
private func silencedText(_ seconds: Int) -> String {
    NativeL10n.text(.cardSilenced, ["seconds": "\(seconds)"])
}

/// I'm up on a card the user silenced, or Done on an acknowledged one.
@available(iOS 16.2, *)
private struct CardButton: View {
    let kind: LiveCardText.Button
    let incidentId: String
    let topic: String

    var body: some View {
        switch kind {
        case .imUp:
            Button(intent: AckAlarmIntent(incidentId: incidentId)) { label(NativeL10n.text(.actionImUp)) }
                .buttonStyle(.plain)
                .background(CritAlarmFace.alarmed.canvas, in: Capsule())
                .foregroundStyle(CritAlarmFace.alarmed.stroke)
        case .done:
            // A topic that owes a wake-up challenge: Done opens the app on
            // this incident, where the challenge and its way out are, and
            // closes nothing here. Dart wrote that flag. The alarm is
            // already stopped by the time this button exists.
            //
            // It is a link, marked as coming from Done, so the app can
            // still hand the close back when it cannot reach the server.
            Group {
                if let url = WidgetLink.doneURL(
                    incidentId: incidentId, topic: topic, shared: ChallengeFlag.groupDefaults
                ) {
                    Link(destination: url) { label(NativeL10n.text(.actionDone)) }
                } else {
                    Button(intent: CloseIncidentIntent(incidentId: incidentId)) { label(NativeL10n.text(.actionDone)) }
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(CritAlarmPalette.onHighlight)
            .background(CritAlarmPalette.cobalt, in: Capsule())
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            // A capsule that wraps its own label reads as broken. The button
            // takes the width the word needs and the column beside it gives
            // way instead.
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
    }
}

@available(iOS 16.2, *)
private struct StatusPill: View {
    let card: LiveCard

    var body: some View {
        Text(card.pill.uppercased())
            .font(.caption2.weight(.bold))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(card.face.canvas, in: Capsule())
            .foregroundStyle(card.face.stroke)
    }
}
