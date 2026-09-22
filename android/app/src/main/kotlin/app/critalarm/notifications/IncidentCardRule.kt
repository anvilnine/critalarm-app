package app.critalarm.notifications

/**
 * The phone state one incident is in, read off disk or off the call that just
 * changed it. Pure: no Android, no context, so a test can build one directly.
 */
sealed class IncidentPhoneState {
    /** The alarm is ringing, so the foreground service owns the card. */
    object Ringing : IncidentPhoneState()

    /**
     * Silenced, with the next ring this phone set for itself. Null means the
     * re-arm was refused, so there is nothing to count down to.
     */
    data class Silenced(val nextRingAtMillis: Long?) : IncidentPhoneState()

    /**
     * Acknowledged. [deskTimerEndMillis] is the absolute instant the ack
     * response carried, [deskTimerSeconds] the cached topic timer used when the
     * response carried none.
     */
    data class Acked(
        val ackedAtMillis: Long,
        val deskTimerEndMillis: Long?,
        val deskTimerSeconds: Int?,
    ) : IncidentPhoneState()

    object Closed : IncidentPhoneState()
    object Expired : IncidentPhoneState()
}

/**
 * Which card one incident shows, from its phone state.
 *
 * One card per incident, never two. While the alarm rings the foreground
 * service owns the ringing card under its own id; once it stops, the status
 * card takes over under one id so a state change replaces it in place.
 */
object IncidentCardRule {
    enum class Card { RINGING, SILENCED, ACKED, NONE }

    data class Decision(val card: Card, val countdownEndMillis: Long?)

    fun decide(state: IncidentPhoneState, nowMillis: Long): Decision = when (state) {
        IncidentPhoneState.Ringing -> Decision(Card.RINGING, null)
        is IncidentPhoneState.Silenced -> {
            val at = state.nextRingAtMillis
            if (at == null || at <= nowMillis) Decision(Card.NONE, null)
            else Decision(Card.SILENCED, at)
        }
        is IncidentPhoneState.Acked -> {
            val end = state.deskTimerEndMillis?.takeIf { it > state.ackedAtMillis }
                ?: state.deskTimerSeconds?.let { state.ackedAtMillis + it * 1000L }
            Decision(Card.ACKED, end)
        }
        IncidentPhoneState.Closed, IncidentPhoneState.Expired -> Decision(Card.NONE, null)
    }
}
