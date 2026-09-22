import Foundation

/// Whether the phone may set its own next ring for an incident it just
/// silenced, and when that ring lands.
///
/// Stop, a swipe and the system Stop button all silence the alarm and nothing
/// more. The phone then rings again for the same incident at
/// `now + repeat_interval_s`, and only "I'm up" ends it. The server keeps
/// repeating too; both are keyed to the incident id, so they collapse into one
/// alarm.
///
/// The same five inputs answer the same way in
/// `android/app/src/main/kotlin/app/critalarm/alarm/RearmRule.kt` and
/// `lib/core/alarm/rearm_rule.dart`. Change the three together.
///
/// The app never generates an alert of its own (PRD commitment 5). A re-arm
/// re-delivers an incident the server opened, which is why every gate below
/// traces back to something the server said: the incident id came in a
/// priority-5 push, the topic's critical switch is on, and `ring_until` from
/// api.md §5.1 has not passed.
enum RearmRule {
    /// What every topic is created with (api.md §3.1).
    static let defaultRepeatIntervalS = 30

    /// Kinds that mean the server opened or continued an incident.
    static let ringingKinds: Set<IncidentPush.Kind> = [.open, .repeat, .reopen]

    static func canRearm(
        incidentId: String,
        kind: IncidentPush.Kind,
        criticalOn: Bool,
        ackedLocally: Bool,
        ringUntil: Date?,
        now: Date,
        quietHoursHold: Bool
    ) -> Bool {
        if incidentId.isEmpty { return false }
        if !ringingKinds.contains(kind) { return false }
        if !criticalOn { return false }
        if ackedLocally { return false }
        // No `ring_until` means no priority-5 alarm push from the server
        // carried this id. The onboarding demo `inc_demo` is the one that
        // reaches here, and it gets no re-arm.
        guard let ringUntil else { return false }
        if now >= ringUntil { return false }
        if quietHoursHold { return false }
        return true
    }

    /// When the next ring lands, or nil when it would fall past `ringUntil`.
    static func nextRingAt(
        now: Date,
        repeatIntervalS: Int,
        ringUntil: Date?
    ) -> Date? {
        let seconds = repeatIntervalS > 0 ? repeatIntervalS : defaultRepeatIntervalS
        let at = now.addingTimeInterval(TimeInterval(seconds))
        if let ringUntil, at >= ringUntil { return nil }
        return at
    }
}
