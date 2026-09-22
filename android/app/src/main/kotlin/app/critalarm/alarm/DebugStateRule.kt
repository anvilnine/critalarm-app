package app.critalarm.alarm

/** Pure precedence rule for the diagnostic phone-state label. */
object DebugStateRule {
    data class Input(
        val active: Boolean = false,
        val acknowledged: Boolean = false,
        val closed: Boolean = false,
        val inLocalAckedSet: Boolean = false,
        val live: Boolean = false,
        val rearmPending: Boolean = false,
        val ringUntilMillis: Long? = null,
    )

    fun phoneState(input: Input, nowMillis: Long): String = when {
        input.live -> "ringing"
        input.closed -> "closed"
        input.acknowledged && input.inLocalAckedSet -> "acked here"
        input.acknowledged -> "acked elsewhere"
        input.active && input.rearmPending -> "silenced"
        input.ringUntilMillis?.let { it < nowMillis } == true && !input.rearmPending -> "expired"
        else -> "unknown"
    }
}
