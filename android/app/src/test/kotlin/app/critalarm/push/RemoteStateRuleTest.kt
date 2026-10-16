package app.critalarm.push

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
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
    fun `an answer counts only when no ring was armed after the question went out`() {
        assertTrue(RemoteStateRule.mayApply(checkedAtMillis = 2_000L, ringArmedAtMillis = 1_000L))
        // A reopen push after the question: the answer may be about the old stage.
        assertFalse(RemoteStateRule.mayApply(checkedAtMillis = 2_000L, ringArmedAtMillis = 3_000L))
        assertFalse(RemoteStateRule.mayApply(checkedAtMillis = 2_000L, ringArmedAtMillis = 2_000L))
        // Nothing armed since this build: no push can have reopened it.
        assertTrue(RemoteStateRule.mayApply(checkedAtMillis = 2_000L, ringArmedAtMillis = null))
        // An answer with no time on it never counts.
        assertFalse(RemoteStateRule.mayApply(checkedAtMillis = null, ringArmedAtMillis = null))
    }
}
