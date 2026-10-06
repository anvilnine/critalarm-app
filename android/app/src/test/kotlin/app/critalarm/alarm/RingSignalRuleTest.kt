package app.critalarm.alarm

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Whether the alarm service flashes and vibrates, given what it is holding.
 * Both switches are off unless the user turned them on for the topic.
 */
class RingSignalRuleTest {
    private val saved = AlarmSignalStore.Saved(
        flashTopics = setOf("flash-only", "both"),
        vibrationTopics = setOf("vibration-only", "both"),
    )

    @Test
    fun `nothing ringing runs nothing`() {
        assertEquals(RingSignalRule.Wanted.NONE, RingSignalRule.wanted(emptyList(), saved))
    }

    @Test
    fun `one ringing topic runs what that topic has on`() {
        assertEquals(RingSignalRule.Wanted(true, false), RingSignalRule.wanted(listOf("flash-only"), saved))
        assertEquals(RingSignalRule.Wanted(false, true), RingSignalRule.wanted(listOf("vibration-only"), saved))
        assertEquals(RingSignalRule.Wanted(true, true), RingSignalRule.wanted(listOf("both"), saved))
        assertEquals(RingSignalRule.Wanted.NONE, RingSignalRule.wanted(listOf("plain"), saved))
    }

    @Test
    fun `several ringing topics run each one that any of them has on`() {
        assertEquals(
            RingSignalRule.Wanted(true, true),
            RingSignalRule.wanted(listOf("flash-only", "vibration-only"), saved),
        )
        assertEquals(
            RingSignalRule.Wanted(true, false),
            RingSignalRule.wanted(listOf("plain", "flash-only"), saved),
        )
    }

    @Test
    fun `a second alarm with both off does not take them away`() {
        // "both" rang first, "plain" arrived and took the speaker.
        assertEquals(RingSignalRule.Wanted(true, true), RingSignalRule.wanted(listOf("both", "plain"), saved))
    }

    @Test
    fun `stopping the alarm that had them on leaves the other with neither`() {
        assertEquals(RingSignalRule.Wanted.NONE, RingSignalRule.wanted(listOf("plain"), saved))
    }

    @Test
    fun `an incident whose topic is not known yet counts as off`() {
        assertEquals(RingSignalRule.Wanted.NONE, RingSignalRule.wanted(listOf(null), saved))
        assertEquals(RingSignalRule.Wanted(true, false), RingSignalRule.wanted(listOf(null, "flash-only"), saved))
    }

    @Test
    fun `with no switch on anywhere nothing runs`() {
        assertEquals(RingSignalRule.Wanted.NONE, RingSignalRule.wanted(listOf("both"), AlarmSignalStore.Saved()))
    }

    @Test
    fun `the topic is asked for only when it is unknown and a switch is on somewhere`() {
        assertTrue(RingSignalRule.shouldLearnTopic(null, saved))
        assertFalse(RingSignalRule.shouldLearnTopic("plain", saved))
        assertFalse(RingSignalRule.shouldLearnTopic(null, AlarmSignalStore.Saved()))
    }

    @Test
    fun `the flash is one a second, on for half of it`() {
        assertEquals(1.0, RingSignalRule.flashesPerSecond, 0.0)
        assertEquals(RingSignalRule.FLASH_ON_MS, RingSignalRule.FLASH_OFF_MS)
    }

    @Test
    fun `the flash stays well under three a second`() {
        // Three flashes a second or more can set off a photosensitive seizure.
        assertTrue(RingSignalRule.flashesPerSecond <= 1.5)
    }

    @Test
    fun `the vibration is full strength and repeats from the start`() {
        assertArrayEquals(longArrayOf(700L, 300L), RingSignalRule.VIBRATION_TIMINGS_MS)
        assertArrayEquals(intArrayOf(255, 0), RingSignalRule.VIBRATION_AMPLITUDES)
        assertEquals(0, RingSignalRule.VIBRATION_REPEAT_FROM)
    }

    @Test
    fun `the pattern without a strength is the same on and off times`() {
        // That form starts with a wait, so it leads with a wait of nothing.
        assertArrayEquals(longArrayOf(0L, 700L, 300L), RingSignalRule.VIBRATION_ON_OFF_TIMINGS_MS)
    }
}
