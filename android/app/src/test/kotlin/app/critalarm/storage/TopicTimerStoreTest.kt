package app.critalarm.storage

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class TopicTimerStoreTest {
    @Test
    fun `parses three integers`() {
        assertEquals(TopicTimers(30, 1800, 600), TopicTimerStore.parse("30|1800|600"))
    }

    @Test
    fun `a missing value is null, not a default`() {
        assertNull(TopicTimerStore.parse(null))
    }

    @Test
    fun `a malformed value is null, not a crash`() {
        assertNull(TopicTimerStore.parse("30|abc|600"))
        assertNull(TopicTimerStore.parse("30|1800"))
        assertNull(TopicTimerStore.parse(""))
        assertNull(TopicTimerStore.parse("30|1800|600|7"))
    }

    @Test
    fun `a non-positive interval is null, because a zero-length bar is a lie`() {
        assertNull(TopicTimerStore.parse("0|1800|600"))
        assertNull(TopicTimerStore.parse("-5|1800|600"))
    }
}
