package app.critalarm.push

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotSame
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class RemoteStateRuleTest {
    @Test
    fun `acked closed and expired stand for the three state pushes`() {
        assertEquals(IncidentPushKind.ACK, RemoteStateRule.kindForState("acked"))
        assertEquals(IncidentPushKind.CLOSE, RemoteStateRule.kindForState("closed"))
        assertEquals(IncidentPushKind.EXPIRE, RemoteStateRule.kindForState("expired"))
    }

    @Test
    fun `open, nothing and unknown words never end a ring`() {
        for (state in listOf("open", null, "", "ACKED", "snoozed")) {
            assertNull(state, RemoteStateRule.kindForState(state))
        }
    }

    @Test
    fun `the state is read off the incident the server sends`() {
        assertEquals(
            "acked",
            RemoteStateRule.stateOf("""{"id":"inc_1","topic":"prod","state":"acked","messages":[]}"""),
        )
        assertNull(RemoteStateRule.stateOf("""{"id":"inc_1"}"""))
        assertNull(RemoteStateRule.stateOf("not json"))
    }

    private fun live(
        holding: Boolean = false,
        rearmPending: Boolean = false,
        active: Boolean = false,
        acknowledged: Boolean = false,
        closed: Boolean = false,
        ringUntilMillis: Long? = null,
        nowMillis: Long = 1_000L,
    ) = RemoteStateRule.isLiveHere(
        holding, rearmPending, active, acknowledged, closed, ringUntilMillis, nowMillis,
    )

    @Test
    fun `an alarm holding the incident is live, whatever the store says`() {
        assertTrue(live(holding = true))
        assertTrue(live(holding = true, acknowledged = true))
    }

    @Test
    fun `a ring set by Stop is live`() {
        assertTrue(live(rearmPending = true))
    }

    @Test
    fun `an unanswered alarm push inside its ring window is live`() {
        assertTrue(live(active = true, ringUntilMillis = 2_000L))
        assertFalse(live(active = true, ringUntilMillis = 1_000L))
        assertFalse(live(active = true, ringUntilMillis = null))
    }

    @Test
    fun `an incident answered or closed here has nothing left to stop`() {
        assertFalse(live(active = true, acknowledged = true, ringUntilMillis = 2_000L))
        assertFalse(live(rearmPending = true, closed = true))
    }

    @Test
    fun `an incident this phone never rang for is not live`() {
        assertFalse(live())
    }

    @Test
    fun `an answer for the ring generation going now stops a live ring`() {
        assertEquals(
            RemoteStateRule.Outcome.STOPPED,
            RemoteStateRule.decide(expectedGeneration = 4L, currentGeneration = 4L, live = true),
        )
    }

    @Test
    fun `an answer for the generation going now with nothing live changes nothing`() {
        assertEquals(
            RemoteStateRule.Outcome.NOTHING,
            RemoteStateRule.decide(expectedGeneration = 4L, currentGeneration = 4L, live = false),
        )
    }

    @Test
    fun `a push that armed a ring since the question went out wins`() {
        assertEquals(
            RemoteStateRule.Outcome.REFUSED,
            RemoteStateRule.decide(expectedGeneration = 4L, currentGeneration = 5L, live = true),
        )
    }

    @Test
    fun `an answer with no generation never counts`() {
        assertEquals(
            RemoteStateRule.Outcome.REFUSED,
            RemoteStateRule.decide(expectedGeneration = null, currentGeneration = 0L, live = true),
        )
    }

    @Test
    fun `the outcome words match what Dart reads`() {
        assertEquals("stopped", RemoteStateRule.Outcome.STOPPED.wire)
        assertEquals("nothing", RemoteStateRule.Outcome.NOTHING.wire)
        assertEquals("refused", RemoteStateRule.Outcome.REFUSED.wire)
    }

    @Test
    fun `one incident has one lock, and two incidents two`() {
        assertSame(RingLocks.of("inc_1"), RingLocks.of("inc_1"))
        assertNotSame(RingLocks.of("inc_1"), RingLocks.of("inc_2"))
    }
}
