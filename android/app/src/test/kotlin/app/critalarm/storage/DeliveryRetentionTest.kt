package app.critalarm.storage

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DeliveryRetentionTest {
    private val now = 1_764_000_000_000L

    @Test
    fun `a ringing incident is never dropped`() {
        assertFalse(
            DeliveryRetention.isStale(
                acknowledged = false,
                closed = false,
                ackedAtMillis = null,
                nowMillis = now,
            ),
        )
    }

    @Test
    fun `an incident acked a minute ago stays`() {
        assertFalse(
            DeliveryRetention.isStale(
                acknowledged = true,
                closed = false,
                ackedAtMillis = now - 60_000,
                nowMillis = now,
            ),
        )
    }

    @Test
    fun `an incident closed past the window goes`() {
        assertTrue(
            DeliveryRetention.isStale(
                acknowledged = true,
                closed = true,
                ackedAtMillis = now - DeliveryRetention.WINDOW_MS - 1,
                nowMillis = now,
            ),
        )
    }

    @Test
    fun `the window is seven days`() {
        assertFalse(
            DeliveryRetention.isStale(
                acknowledged = true,
                closed = true,
                ackedAtMillis = now - DeliveryRetention.WINDOW_MS + 1,
                nowMillis = now,
            ),
        )
        assertTrue(
            DeliveryRetention.isStale(
                acknowledged = true,
                closed = true,
                ackedAtMillis = now - DeliveryRetention.WINDOW_MS,
                nowMillis = now,
            ),
        )
    }

    @Test
    fun `a finished incident with no instant is older than anything we wrote`() {
        assertTrue(
            DeliveryRetention.isStale(
                acknowledged = true,
                closed = false,
                ackedAtMillis = null,
                nowMillis = now,
            ),
        )
    }
}
