package app.critalarm.widgets

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class WidgetFreshnessTest {
    private val written = WidgetFixtures.snapshot()

    @Test
    fun `fresh at 899 seconds`() {
        assertFalse(WidgetFreshness.isStale(written, written.updatedAt + 899))
    }

    @Test
    fun `stale at 900 seconds`() {
        assertTrue(WidgetFreshness.isStale(written, written.updatedAt + 900))
    }

    @Test
    fun `updated_at 0 is stale right away`() {
        assertTrue(WidgetFreshness.isStale(written.copy(updatedAt = 0L), 1L))
    }

    @Test
    fun `missing or signed out is never stale`() {
        assertFalse(WidgetFreshness.isStale(null, 10_000_000_000L))
        assertFalse(WidgetFreshness.isStale(WidgetSnapshot.disconnected(0L), 10_000_000_000L))
    }

    @Test
    fun `a fetch nothing overtook is stored as is`() {
        val fetched = written.copy(openCount = 9)
        assertEquals(fetched, WidgetFreshness.afterFetch(fetched, written, changedMeanwhile = false))
    }

    @Test
    fun `a patch during the fetch wins and is left stale`() {
        val fetched = written.copy(openCount = 9)
        assertEquals(
            written.copy(updatedAt = 0L),
            WidgetFreshness.afterFetch(fetched, written, changedMeanwhile = true),
        )
        assertNull(WidgetFreshness.afterFetch(fetched, null, changedMeanwhile = true))
    }
}
