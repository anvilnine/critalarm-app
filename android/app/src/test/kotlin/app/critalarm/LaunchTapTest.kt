package app.critalarm

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class LaunchTapTest {
    /** Hands the tap over once, then nothing, the way readTap strips extras. */
    private fun readOnce(tap: Map<String, String>?): () -> Map<String, String>? {
        var left = tap
        return {
            val next = left
            left = null
            next
        }
    }

    @Test
    fun `the route stays the same however often it is asked for`() {
        val reads = mutableListOf<Int>()
        val reader = readOnce(mapOf(MainActivity.EXTRA_TOPIC to "prod", MainActivity.KEY_TAP_ID to "1"))
        val launch = LaunchTap { reads += 1; reader() }
        assertEquals("/topics/prod", launch.route)
        assertEquals("/topics/prod", launch.route)
        assertEquals("1", launch.tap?.get(MainActivity.KEY_TAP_ID))
        assertEquals(1, reads.size)
    }

    @Test
    fun `the count widget tap opens Home`() {
        val launch = LaunchTap(readOnce(mapOf(MainActivity.EXTRA_OPEN to MainActivity.OPEN_HOME)))
        assertEquals("/", launch.route)
    }

    @Test
    fun `a plain launch has no route`() {
        val launch = LaunchTap { null }
        assertNull(launch.tap)
        assertNull(launch.route)
    }
}
