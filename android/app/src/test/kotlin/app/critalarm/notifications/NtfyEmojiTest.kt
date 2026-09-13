package app.critalarm.notifications

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class NtfyEmojiTest {
    @Test
    fun `known shortcodes map to emoji`() {
        assertEquals("⚠️", NtfyEmoji.emojiFor("warning"))
        assertEquals("💀", NtfyEmoji.emojiFor("skull"))
        assertEquals("🚨", NtfyEmoji.emojiFor("rotating_light"))
    }

    @Test
    fun `lookup ignores case and surrounding spaces`() {
        assertEquals("🔥", NtfyEmoji.emojiFor("  FiRe  "))
    }

    @Test
    fun `unknown tags stay plain`() {
        assertNull(NtfyEmoji.emojiFor("db01"))
        val (emoji, plain) = NtfyEmoji.split(listOf("warning", "db01", "fire"))
        assertEquals(listOf("⚠️", "🔥"), emoji)
        assertEquals(listOf("db01"), plain)
    }

    @Test
    fun `emoji tags go in front of the title`() {
        assertEquals("⚠️🔥 Database down", NtfyEmoji.prefixTitle("Database down", listOf("warning", "fire")))
        assertEquals("Database down", NtfyEmoji.prefixTitle("Database down", listOf("db01")))
    }
}
