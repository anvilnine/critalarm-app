package app.critalarm.notifications

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** One case per phone state, plus the refused re-arm. */
class IncidentCardRuleTest {
    private val now = 1_757_462_400_000L

    @Test
    fun `ringing shows the ringing card`() {
        val decision = IncidentCardRule.decide(IncidentPhoneState.Ringing, now)
        assertEquals(IncidentCardRule.Card.RINGING, decision.card)
        assertNull(decision.countdownEndMillis)
    }

    @Test
    fun `silenced shows the silenced card counting to the next ring`() {
        val next = now + 30_000L
        val decision = IncidentCardRule.decide(IncidentPhoneState.Silenced(next), now)
        assertEquals(IncidentCardRule.Card.SILENCED, decision.card)
        assertEquals(next, decision.countdownEndMillis)
    }

    @Test
    fun `silenced but re-arm refused shows nothing`() {
        val decision = IncidentCardRule.decide(IncidentPhoneState.Silenced(null), now)
        assertEquals(IncidentCardRule.Card.NONE, decision.card)
        assertNull(decision.countdownEndMillis)
    }

    @Test
    fun `a next ring already past shows nothing`() {
        val decision = IncidentCardRule.decide(IncidentPhoneState.Silenced(now), now)
        assertEquals(IncidentCardRule.Card.NONE, decision.card)
    }

    @Test
    fun `acked counts to the server deadline when the response carried one`() {
        val firesAt = now + 120_000L
        val decision = IncidentCardRule.decide(
            IncidentPhoneState.Acked(now, firesAt, 600),
            now,
        )
        assertEquals(IncidentCardRule.Card.ACKED, decision.card)
        assertEquals(firesAt, decision.countdownEndMillis)
    }

    @Test
    fun `acked falls back to acked_at plus the cached desk timer`() {
        val decision = IncidentCardRule.decide(
            IncidentPhoneState.Acked(now, null, 600),
            now,
        )
        assertEquals(IncidentCardRule.Card.ACKED, decision.card)
        assertEquals(now + 600_000L, decision.countdownEndMillis)
    }

    @Test
    fun `acked with no deadline and no timer counts nothing`() {
        val decision = IncidentCardRule.decide(
            IncidentPhoneState.Acked(now, null, null),
            now,
        )
        assertEquals(IncidentCardRule.Card.ACKED, decision.card)
        assertNull(decision.countdownEndMillis)
    }

    @Test
    fun `a deadline already past falls back to the cached timer`() {
        val decision = IncidentCardRule.decide(
            IncidentPhoneState.Acked(now, now - 1_000L, 600),
            now,
        )
        assertEquals(IncidentCardRule.Card.ACKED, decision.card)
        assertEquals(now + 600_000L, decision.countdownEndMillis)
    }

    @Test
    fun `closed and expired show nothing`() {
        assertEquals(IncidentCardRule.Card.NONE, IncidentCardRule.decide(IncidentPhoneState.Closed, now).card)
        assertEquals(IncidentCardRule.Card.NONE, IncidentCardRule.decide(IncidentPhoneState.Expired, now).card)
    }
}
