package app.critalarm.actions

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DoneHandOffRuleTest {
    private fun mayClose(
        acknowledged: Boolean = false,
        closed: Boolean = false,
        active: Boolean = false,
        ringing: Boolean = false,
        rearmPending: Boolean = false,
    ) = DoneHandOffRule.mayClose(acknowledged, closed, active, ringing, rearmPending)

    @Test
    fun `acknowledged here and quiet may be closed`() {
        assertTrue(mayClose(acknowledged = true))
    }

    @Test
    fun `an id this phone has never seen is refused`() {
        assertFalse(mayClose())
    }

    @Test
    fun `open and never acknowledged is refused`() {
        assertFalse(mayClose(active = true))
    }

    @Test
    fun `ringing is refused`() {
        assertFalse(mayClose(active = true, ringing = true))
        // Even if a stale mark says acknowledged.
        assertFalse(mayClose(acknowledged = true, ringing = true))
    }

    @Test
    fun `silenced but not acknowledged is refused`() {
        assertFalse(mayClose(active = true, rearmPending = true))
        assertFalse(mayClose(rearmPending = true))
        assertFalse(mayClose(acknowledged = true, rearmPending = true))
    }

    @Test
    fun `rung again after an acknowledge is refused`() {
        // A reopen drops the acknowledged mark and sets active.
        assertFalse(mayClose(active = true))
        // And if the mark somehow survived, active alone still refuses.
        assertFalse(mayClose(acknowledged = true, active = true))
    }

    @Test
    fun `already closed is refused, there is nothing left to close`() {
        assertFalse(mayClose(acknowledged = true, closed = true))
    }

    @Test
    fun `only the one combination passes`() {
        var passes = 0
        for (bits in 0 until 32) {
            fun bit(n: Int) = bits and (1 shl n) != 0
            if (DoneHandOffRule.mayClose(bit(0), bit(1), bit(2), bit(3), bit(4))) passes++
        }
        org.junit.Assert.assertEquals(1, passes)
    }
}
