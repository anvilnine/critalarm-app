package app.critalarm.push

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class CallDeadlineTest {
    @Test
    fun `a call that answers in time gives its answer`() {
        assertEquals("acked", CallDeadline.run(timeoutMs = 1_000L, onTimeout = {}) { "acked" })
    }

    @Test
    fun `a call past the deadline gives nothing and is cut off`() {
        var cutOff = false
        val started = System.currentTimeMillis()
        val answer = CallDeadline.run(timeoutMs = 100L, onTimeout = { cutOff = true }) {
            Thread.sleep(2_000L)
            "acked"
        }
        assertNull(answer)
        assertTrue(cutOff)
        assertTrue(System.currentTimeMillis() - started < 1_000L)
    }

    @Test
    fun `a call that throws gives nothing`() {
        assertNull(CallDeadline.run<String>(timeoutMs = 1_000L, onTimeout = {}) { error("no route") })
    }
}
