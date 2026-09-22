package app.critalarm.alarm

import app.critalarm.push.IncidentPushKind
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RearmRuleTest {
    private val now = 1_757_462_400_000L
    private val ringUntil = now + 20 * 60 * 1000L

    private fun ask(
        incidentId: String = "inc_9a8b7c",
        kind: IncidentPushKind = IncidentPushKind.REPEAT,
        criticalOn: Boolean = true,
        ackedLocally: Boolean = false,
        ringUntilMillis: Long? = ringUntil,
        quietHoursHold: Boolean = false,
    ) = RearmRule.canRearm(
        incidentId = incidentId,
        kind = kind,
        criticalOn = criticalOn,
        ackedLocally = ackedLocally,
        ringUntilMillis = ringUntilMillis,
        nowMillis = now,
        quietHoursHold = quietHoursHold,
    )

    @Test
    fun `all five inputs good lets the phone set its own next ring`() {
        assertTrue(ask())
    }

    @Test
    fun `an acked incident does not ring again`() {
        assertFalse(ask(ackedLocally = true))
    }

    @Test
    fun `a ring_until in the past stops the loop`() {
        assertFalse(ask(ringUntilMillis = now - 1))
    }

    @Test
    fun `ring_until exactly now stops the loop`() {
        assertFalse(ask(ringUntilMillis = now))
    }

    @Test
    fun `no ring_until means the server never sent this incident`() {
        assertFalse(ask(incidentId = "inc_demo", ringUntilMillis = null))
    }

    @Test
    fun `a topic whose critical switch is off does not ring`() {
        assertFalse(ask(criticalOn = false))
    }

    @Test
    fun `quiet hours holds the ring`() {
        assertTrue(ask(quietHoursHold = false))
        assertFalse(ask(quietHoursHold = true))
    }

    @Test
    fun `an empty incident id never rings`() {
        assertFalse(ask(incidentId = ""))
    }

    @Test
    fun `open repeat and reopen all re-arm`() {
        for (kind in listOf(IncidentPushKind.OPEN, IncidentPushKind.REPEAT, IncidentPushKind.REOPEN)) {
            assertTrue(kind.wireValue, ask(kind = kind))
        }
    }

    @Test
    fun `a forward or a state change never re-arms`() {
        val never = listOf(
            IncidentPushKind.P4,
            IncidentPushKind.P5,
            IncidentPushKind.ACK,
            IncidentPushKind.CLOSE,
            IncidentPushKind.EXPIRE,
        )
        for (kind in never) {
            assertFalse(kind.wireValue, ask(kind = kind))
        }
    }

    @Test
    fun `the next ring lands one repeat interval out`() {
        assertEquals(now + 30_000L, RearmRule.nextRingAtMillis(now, 30, ringUntil))
    }

    @Test
    fun `the next ring never lands after ring_until`() {
        assertNull(RearmRule.nextRingAtMillis(now, 30, now + 10_000L))
    }

    @Test
    fun `a nonsense interval falls back to the server default`() {
        assertEquals(
            now + RearmRule.DEFAULT_REPEAT_INTERVAL_S * 1000L,
            RearmRule.nextRingAtMillis(now, 0, ringUntil),
        )
    }
}
