import Foundation

/// Whether a push should schedule an AlarmKit alarm, given what the user has
/// already stopped on this phone.
///
/// Android has the same rule in `PushRouter.kt`: a `repeat` for an acked
/// incident is dropped, everything else rings. A `reopen` is a new stage
/// started by the desk timer, so it rings and the old mark is forgotten.
enum AlarmScheduleRule {
    static func shouldSchedule(
        kind: IncidentPush.Kind,
        incidentId: String,
        acked: Set<String>
    ) -> Bool {
        switch kind {
        case .repeat:
            return !acked.contains(incidentId)
        case .open, .reopen, .p4:
            return true
        }
    }

    /// The incident a push rang this phone for, or nil when it rang nothing.
    ///
    /// A running app is told this id so a screen waiting for one alarm knows
    /// it arrived. Only a priority 5 `open`, `repeat` or `reopen` counts,
    /// the same pushes Android reports from `PushRouter.kt`. A push that did
    /// not parse (an ack, a close, an expire), a `p4`, a `repeat` for an
    /// incident already stopped here, and a ring held by quiet hours all
    /// answer nil: none of them is a ring.
    static func ringingIncidentId(
        push: IncidentPush?,
        acked: Set<String>,
        heldByQuietHours: Bool
    ) -> String? {
        guard let push, let incidentId = push.incidentId else { return nil }
        guard push.priority == 5 else { return nil }
        switch push.kind {
        case .p4:
            return nil
        case .open, .repeat, .reopen:
            break
        }
        if heldByQuietHours { return nil }
        if !shouldSchedule(kind: push.kind, incidentId: incidentId, acked: acked) { return nil }
        return incidentId
    }

    /// True for the push that starts a new stage, which makes the mark stale.
    static func clearsAck(kind: IncidentPush.Kind) -> Bool {
        kind == .reopen
    }
}
