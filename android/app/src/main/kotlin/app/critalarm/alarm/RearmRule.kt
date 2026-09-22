package app.critalarm.alarm

import app.critalarm.push.IncidentPushKind

/**
 * Whether the phone may set its own next ring for an incident it just
 * silenced, and when that ring lands.
 *
 * Stop, a swipe and Back all silence the alarm and nothing more. The phone
 * then rings again for the same incident at `now + repeat_interval_s`, and
 * only "I'm up" ends it. The server keeps repeating too; both are keyed to the
 * incident id, so they collapse into one alarm.
 *
 * The same five inputs answer the same way in `ios/Shared/Alarm/RearmRule.swift`
 * and `lib/core/alarm/rearm_rule.dart`. Change the three together.
 *
 * The app never generates an alert of its own (PRD commitment 5). A re-arm
 * re-delivers an incident the server opened, which is why every gate below
 * traces back to something the server said: the incident id came in a
 * priority-5 push, the topic's critical switch is on, and `ring_until` from
 * api.md §5.2 has not passed.
 */
object RearmRule {
    /** What every topic is created with (api.md §3.1). */
    const val DEFAULT_REPEAT_INTERVAL_S = 30

    /** Kinds that mean the server opened or continued an incident. */
    private val RINGING_KINDS = setOf(
        IncidentPushKind.OPEN,
        IncidentPushKind.REPEAT,
        IncidentPushKind.REOPEN,
    )

    fun canRearm(
        incidentId: String,
        kind: IncidentPushKind,
        criticalOn: Boolean,
        ackedLocally: Boolean,
        ringUntilMillis: Long?,
        nowMillis: Long,
        quietHoursHold: Boolean,
    ): Boolean {
        if (incidentId.isEmpty()) return false
        if (kind !in RINGING_KINDS) return false
        if (!criticalOn) return false
        if (ackedLocally) return false
        // No ring_until means no priority-5 alarm push from the server carried
        // this id. The onboarding demo inc_demo is the one that reaches here,
        // and it gets no re-arm.
        val until = ringUntilMillis ?: return false
        if (nowMillis >= until) return false
        if (quietHoursHold) return false
        return true
    }

    /** When the next ring lands, or null when it would fall past [ringUntilMillis]. */
    fun nextRingAtMillis(
        nowMillis: Long,
        repeatIntervalS: Int,
        ringUntilMillis: Long?,
    ): Long? {
        val seconds = if (repeatIntervalS > 0) repeatIntervalS else DEFAULT_REPEAT_INTERVAL_S
        val at = nowMillis + seconds * 1000L
        if (ringUntilMillis != null && at >= ringUntilMillis) return null
        return at
    }
}
