package app.critalarm.alarm

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ChainRuleTest {
    private val now = 1_757_462_400_000L
    private val minute = 60_000L

    @Test
    fun `the defaults set 60 rings, one every 30 seconds, all before ring_until`() {
        val ringUntil = now + 30 * minute
        val times = ChainRule.chainTimes(now, 30, ringUntil)

        assertEquals(59, times.size)
        assertEquals(now + 30_000L, times.first())
        assertTrue(times.last() < ringUntil)
        assertTrue(times.zipWithNext().all { (a, b) -> b - a == 30_000L })
    }

    @Test
    fun `the defaults counted from the opening ring are 60 rings in all`() {
        // The push rings once itself, and the chain holds every ring after it.
        val ringUntil = now + 30 * minute
        assertEquals(60, 1 + ChainRule.chainTimes(now, 30, ringUntil).size)
    }

    @Test
    fun `a ring window shorter than one interval sets nothing`() {
        assertTrue(ChainRule.chainTimes(now, 30, now + 20_000L).isEmpty())
    }

    @Test
    fun `a ring that would land exactly on ring_until is not set`() {
        assertTrue(ChainRule.chainTimes(now, 30, now + 30_000L).isEmpty())
    }

    @Test
    fun `a ring window already past sets nothing`() {
        assertTrue(ChainRule.chainTimes(now, 30, now - 1).isEmpty())
    }

    @Test
    fun `no ring_until sets nothing, which is the onboarding demo`() {
        assertTrue(ChainRule.chainTimes(now, 30, null).isEmpty())
    }

    @Test
    fun `a custom interval spaces the rings by it`() {
        val times = ChainRule.chainTimes(now, 120, now + 30 * minute)

        assertEquals(14, times.size)
        assertEquals(now + 120_000L, times.first())
        assertTrue(times.zipWithNext().all { (a, b) -> b - a == 120_000L })
    }

    @Test
    fun `an interval of zero falls back to the default`() {
        assertEquals(now + 30_000L, ChainRule.chainTimes(now, 0, now + 10 * minute).first())
    }

    @Test
    fun `a long window on a short interval stops at the cap`() {
        val times = ChainRule.chainTimes(now, 5, now + 120 * minute)
        assertEquals(ChainRule.MAX_SLOTS, times.size)
    }

    @Test
    fun `the last slot of a cut chain sets the rest`() {
        val until = now + 120 * minute
        assertTrue(ChainRule.extendsAfter(ChainRule.MAX_SLOTS - 1, ChainRule.MAX_SLOTS, now, 5, until))
        assertFalse(ChainRule.extendsAfter(3, ChainRule.MAX_SLOTS, now, 5, until))
        assertFalse(ChainRule.extendsAfter(59, 60, now + 30 * minute, 30, now + 30 * minute))
    }

    @Test
    fun `the desk timer chain starts when the desk timer ends and runs one ring window`() {
        val deskEnd = now + 10 * minute
        val times = ChainRule.deskChainTimes(deskEnd, 30, 1800)

        assertEquals(deskEnd, times.first())
        assertEquals(60, times.size)
        assertTrue(times.last() < ChainRule.deskChainUntilMillis(deskEnd, 1800))
    }

    @Test
    fun `the server's desk timer end beats the cached timer`() {
        assertEquals(now + 7 * minute, ChainRule.deskEndMillis(now, now + 7 * minute, 600))
        assertEquals(now + 10 * minute, ChainRule.deskEndMillis(now, null, 600))
        assertEquals(now + 10 * minute, ChainRule.deskEndMillis(now, null, null))
    }

    @Test
    fun `every slot of an incident has its own request code`() {
        val codes = (0 until 60).map { ChainRule.requestCode("inc_9a8b7c", it) }.toSet()
        assertEquals(60, codes.size)
        assertNotEquals("inc_9a8b7c".hashCode(), ChainRule.requestCode("inc_9a8b7c", 0))
    }

    private fun fired(
        kind: ChainRule.Kind? = ChainRule.Kind.RING,
        current: Boolean = true,
        active: Boolean = true,
        acknowledged: Boolean = false,
        closed: Boolean = false,
        criticalOn: Boolean = true,
        untilMillis: Long? = now + 10 * minute,
        quietHoursHold: Boolean = false,
    ) = ChainRule.onSlotFired(
        kind, current, active, acknowledged, closed, criticalOn, untilMillis, now, quietHoursHold,
    )

    @Test
    fun `a ring slot on an open incident rings`() {
        assertEquals(ChainRule.Fired.RING, fired())
    }

    @Test
    fun `a ring slot after an ack, a close, the switch off or ring_until ends the chain`() {
        assertEquals(ChainRule.Fired.END, fired(acknowledged = true, active = false))
        assertEquals(ChainRule.Fired.END, fired(closed = true))
        assertEquals(ChainRule.Fired.END, fired(criticalOn = false))
        assertEquals(ChainRule.Fired.END, fired(untilMillis = now))
        assertEquals(ChainRule.Fired.END, fired(active = false))
    }

    @Test
    fun `quiet hours skip one slot and keep the chain`() {
        assertEquals(ChainRule.Fired.SKIP, fired(quietHoursHold = true))
    }

    @Test
    fun `a slot from a replaced chain does nothing`() {
        assertEquals(ChainRule.Fired.STALE, fired(current = false))
        assertEquals(ChainRule.Fired.STALE, fired(kind = null))
    }

    @Test
    fun `a desk slot with nobody at the desk reopens and rings`() {
        assertEquals(
            ChainRule.Fired.REOPEN_AND_RING,
            fired(kind = ChainRule.Kind.DESK, active = false, acknowledged = true),
        )
    }

    @Test
    fun `a desk slot after At my desk ends the chain`() {
        assertEquals(
            ChainRule.Fired.END,
            fired(kind = ChainRule.Kind.DESK, active = false, acknowledged = true, closed = true),
        )
    }

    @Test
    fun `a ring chain is kept only for an open incident nobody acked`() {
        fun keeps(active: Boolean, acknowledged: Boolean, closed: Boolean = false) = ChainRule.keepsChain(
            ChainRule.Kind.RING, active, acknowledged, closed, true, now + minute, now,
        )
        assertTrue(keeps(active = true, acknowledged = false))
        assertFalse(keeps(active = false, acknowledged = false))
        assertFalse(keeps(active = false, acknowledged = true))
        assertFalse(keeps(active = true, acknowledged = true, closed = true))
    }

    @Test
    fun `a desk chain is kept only while acked and not closed`() {
        fun keeps(acknowledged: Boolean, closed: Boolean) = ChainRule.keepsChain(
            ChainRule.Kind.DESK, false, acknowledged, closed, true, now + minute, now,
        )
        assertTrue(keeps(acknowledged = true, closed = false))
        assertFalse(keeps(acknowledged = true, closed = true))
        assertFalse(keeps(acknowledged = false, closed = false))
    }
}
