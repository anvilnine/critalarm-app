package app.critalarm.alarm

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AlarmPlayerRulesTest {
    @Test
    fun offTheMainThreadTheCallIsPostedNotRun() {
        val posted = mutableListOf<() -> Unit>()
        var ran = 0
        AlarmPlayerRules.onMain(isMainThread = false, post = { posted.add(it) }) { ran += 1 }
        assertEquals(0, ran)
        assertEquals(1, posted.size)
        posted.single()()
        assertEquals(1, ran)
    }

    @Test
    fun onTheMainThreadTheCallRunsAtOnce() {
        var ran = 0
        AlarmPlayerRules.onMain(isMainThread = true, post = { error("must not post") }) { ran += 1 }
        assertEquals(1, ran)
    }

    @Test
    fun aStaleCallbackIsDropped() {
        val first = Any()
        val second = Any()
        // A handover replaced the first loop before its onFailed or onPassDone arrived.
        assertFalse(AlarmPlayerRules.isCurrent(first, second))
        // stop() cleared it.
        assertFalse(AlarmPlayerRules.isCurrent(first, null))
        assertTrue(AlarmPlayerRules.isCurrent(second, second))
    }

    @Test
    fun aDeadPlayerIsReplacedOnReRing() {
        // A writer that failed or finished its pass, and no MediaPlayer.
        assertTrue(AlarmPlayerRules.shouldRing(loopAlive = false, mediaPlaying = false))
    }

    @Test
    fun aSoundingAlarmIsLeftAlone() {
        assertFalse(AlarmPlayerRules.shouldRing(loopAlive = true, mediaPlaying = false))
        assertFalse(AlarmPlayerRules.shouldRing(loopAlive = false, mediaPlaying = true))
    }

    /**
     * The seam above only helps if AlarmPlayer uses it. Its public start and
     * stop must hop to main before touching a player.
     */
    @Test
    fun alarmPlayerEntryPointsGoThroughTheMainThreadRule() {
        val source = File("src/main/kotlin/app/critalarm/alarm/AlarmPlayer.kt").readText()
        for (entry in listOf("fun start(topic: String? = null) {", "fun stop() {")) {
            val body = source.substringAfter(entry).substringBefore("\n    }")
            assertTrue("$entry must go through AlarmPlayerRules.onMain", body.contains("AlarmPlayerRules.onMain("))
        }
    }
}
