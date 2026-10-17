package app.critalarm.push

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * A state push (ack, close, expire) can arrive late, after a reopen armed a
 * new ring. It may only end a ring through the same guarded server check
 * Stop uses.
 */
class StatePushRuleTest {
    @Test
    fun `a state push for a phone that rings or has a ring set asks the server`() {
        assertEquals(StatePushRule.Step.ASK_SERVER, StatePushRule.onArrival(live = true))
    }

    @Test
    fun `a state push for a quiet phone updates the card at once`() {
        assertEquals(StatePushRule.Step.APPLY_NOW, StatePushRule.onArrival(live = false))
    }

    @Test
    fun `an answer that would end a live ring is refused when the caller keeps live rings`() {
        assertEquals(
            RemoteStateRule.Outcome.REFUSED,
            RemoteStateRule.decide(expectedGeneration = 4, currentGeneration = 4, live = true, keepLive = true),
        )
        assertEquals(
            RemoteStateRule.Outcome.NOTHING,
            RemoteStateRule.decide(expectedGeneration = 4, currentGeneration = 4, live = false, keepLive = true),
        )
    }
}
