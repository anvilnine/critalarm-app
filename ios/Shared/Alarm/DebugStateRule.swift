import Foundation

/// Framework-free precedence rule for the diagnostic phone-state label.
enum DebugStateRule {
    struct Input {
        var active = false
        var acknowledged = false
        var closed = false
        var inLocalAckedSet = false
        var live = false
        var rearmPending = false
        var ringUntil: Date?
    }

    static func phoneState(_ input: Input, now: Date) -> String {
        if input.live { return "ringing" }
        if input.closed { return "closed" }
        if input.acknowledged && input.inLocalAckedSet { return "acked here" }
        if input.acknowledged { return "acked elsewhere" }
        if input.active && input.rearmPending { return "silenced" }
        if let ringUntil = input.ringUntil, ringUntil < now, !input.rearmPending { return "expired" }
        return "unknown"
    }
}
