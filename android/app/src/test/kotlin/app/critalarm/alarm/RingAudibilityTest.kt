package app.critalarm.alarm

import android.app.NotificationManager
import app.critalarm.storage.InMemoryPreferences
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** W4: a setup test must never say the phone rang when nobody could hear it. */
class RingAudibilityTest {
    private val all = NotificationManager.INTERRUPTION_FILTER_ALL
    private val alarmsOnly = NotificationManager.INTERRUPTION_FILTER_ALARMS
    private val priority = NotificationManager.INTERRUPTION_FILTER_PRIORITY
    private val totalSilence = NotificationManager.INTERRUPTION_FILTER_NONE

    @Test
    fun `a ring at volume with no Do Not Disturb, or one that lets alarms through, is heard`() {
        for (filter in listOf(all, alarmsOnly, priority)) {
            assertTrue(RingAudibility.audible(alarmVolume = 7, streamMuted = false, interruptionFilter = filter))
        }
    }

    @Test
    fun `volume 0, a muted stream, or total silence is not heard`() {
        assertFalse(RingAudibility.audible(alarmVolume = 0, streamMuted = false, interruptionFilter = all))
        assertFalse(RingAudibility.audible(alarmVolume = 7, streamMuted = true, interruptionFilter = all))
        assertFalse(RingAudibility.audible(alarmVolume = 7, streamMuted = false, interruptionFilter = totalSilence))
    }

    @Test
    fun `a muted ring is recorded per incident and a later heard ring clears it`() {
        val prefs = InMemoryPreferences()
        RingAudibility.record(prefs, listOf("inc_demo", "inc_1"), audible = false)
        assertTrue(RingAudibility.wasMuted(prefs, "inc_demo"))
        assertTrue(RingAudibility.wasMuted(prefs, "inc_1"))
        assertFalse(RingAudibility.wasMuted(prefs, "inc_2"))

        RingAudibility.record(prefs, listOf("inc_demo"), audible = true)
        assertFalse(RingAudibility.wasMuted(prefs, "inc_demo"))
        assertTrue(RingAudibility.wasMuted(prefs, "inc_1"))
    }

    @Test
    fun `the muted set stays small`() {
        var muted = emptySet<String>()
        for (n in 0 until RingAudibility.MAX_MUTED + 10) {
            muted = RingAudibility.mutedAfter(muted, listOf("inc_$n"), audible = false)
        }
        assertEquals(RingAudibility.MAX_MUTED, muted.size)
    }
}
