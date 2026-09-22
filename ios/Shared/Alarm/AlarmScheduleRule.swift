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

    /// True for the push that starts a new stage, which makes the mark stale.
    static func clearsAck(kind: IncidentPush.Kind) -> Bool {
        kind == .reopen
    }
}
