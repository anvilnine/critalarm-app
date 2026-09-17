package app.critalarm.alarm

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Stopping incident B may never silence incident A.
 *
 * The path that found this: B is acked, then expires on the server overnight.
 * A fires, the phone is locked, the service is ringing. The user taps the
 * full-screen intent, the app launches, reconcile walks the acked cards, sees
 * B is expired and cancels it. There is one service for the whole app, so the
 * cancel used to stop the ring for A and take its card with it. Crit Alarm
 * rings until someone acknowledges it, so that is the one bug it cannot have.
 */
class AlarmStopRuleTest {
    @Test
    fun `stopping the only ringing incident stops the service`() {
        assertNull(AlarmStopRule.nextRinging("inc_a", listOf("inc_a")))
    }

    @Test
    fun `stopping the top hands over to the one under it`() {
        // A rang, B arrived and took the speaker, the user stopped B. A was
        // never acknowledged, so it takes the service back rather than going
        // silent for good.
        assertEquals("inc_a", AlarmStopRule.nextRinging("inc_b", listOf("inc_a", "inc_b")))
    }

    @Test
    fun `stopping one underneath leaves the top ringing`() {
        assertEquals("inc_b", AlarmStopRule.nextRinging("inc_a", listOf("inc_a", "inc_b")))
    }

    @Test
    fun `stopping an incident the service is not holding changes nothing`() {
        assertEquals("inc_a", AlarmStopRule.nextRinging("inc_z", listOf("inc_a")))
    }

    @Test
    fun `with nothing ringing there is nothing to hand over to`() {
        assertNull(AlarmStopRule.nextRinging("inc_b", emptyList()))
    }

    @Test
    fun `the id has to match exactly`() {
        assertEquals("inc_a", AlarmStopRule.nextRinging("inc_a2", listOf("inc_a")))
        assertEquals("inc_a", AlarmStopRule.nextRinging("INC_A", listOf("inc_a")))
    }

    @Test
    fun `three deep hands down one at a time`() {
        val held = listOf("inc_a", "inc_b", "inc_c")
        assertEquals("inc_b", AlarmStopRule.nextRinging("inc_c", held))
        assertEquals("inc_a", AlarmStopRule.nextRinging("inc_b", held - "inc_c"))
        assertNull(AlarmStopRule.nextRinging("inc_a", listOf("inc_a")))
    }

    @Test
    fun `a start the service cannot read is ignored while an alarm rings`() {
        assertFalse(AlarmStopRule.stopsOnBadStart(ringingIncidentId = "inc_a"))
    }

    @Test
    fun `a start the service cannot read stops it when nothing rings`() {
        assertTrue(AlarmStopRule.stopsOnBadStart(ringingIncidentId = null))
    }

    /**
     * The rule above is only worth having if every caller asks it. A pure test
     * cannot reach a Service, so this reads the call sites instead.
     *
     * The Stop button on the notification used to stop the service on sight. A
     * card can outlive its own alarm: a late enrichment re-posts the alarm card
     * for an incident that stopped being the ringing one seconds ago, and its
     * Stop then killed a live alarm nobody had acknowledged.
     */
    @Test
    fun `the notification ack route stops one incident and never the service`() {
        val text = source("src/main/kotlin/app/critalarm/actions/IncidentActionReceiver.kt")
        assertTrue(
            "the Stop button must name its incident",
            text.contains("AlarmForegroundService.stopIncident("),
        )
        assertFalse(
            "the Stop button must not stop the service outright",
            text.contains("stopService(Intent("),
        )
    }

    /**
     * The channel has two jobs and only one of them may stop the service
     * outright: `stopRinging` means the noise, whichever incident it belongs
     * to, and is what a screen with no id to acknowledge falls back on.
     * `cancelAlarm` names an incident and goes through the service.
     */
    @Test
    fun `the channel stops one incident everywhere except stopRinging`() {
        val text = source("src/main/kotlin/app/critalarm/alarm/AlarmChannel.kt")
        assertTrue(
            "cancelAlarm must name its incident",
            text.contains("AlarmForegroundService.stopIncident("),
        )
        assertEquals(
            "only stopRinging may stop the service outright",
            1,
            Regex("stopService\\(Intent\\(").findAll(text).count(),
        )
    }

    /**
     * `stopSelf(startId)` stops the service when `startId` is the most recent
     * start, and a malformed start always is, so a junk payload arriving while
     * incident A rang used to kill A.
     */
    @Test
    fun `the service asks the rule before it stops itself on a bad start`() {
        val text = source("src/main/kotlin/app/critalarm/alarm/AlarmForegroundService.kt")
        val guard = text.indexOf("if (AlarmStopRule.stopsOnBadStart(")
        assertTrue("AlarmForegroundService must guard stopSelf with the rule", guard >= 0)
        val stops = Regex("stopSelf\\(").findAll(text).map { it.range.first }.toList()
        assertTrue("stopSelf is called with no guard before it", stops.all { it > guard })
    }

    /** The handover is the service's job, so it has to ask the rule for it. */
    @Test
    fun `the service asks the rule what to ring next`() {
        val text = source("src/main/kotlin/app/critalarm/alarm/AlarmForegroundService.kt")
        assertTrue(text.contains("AlarmStopRule.nextRinging("))
    }

    /**
     * The stop has to run before the cancel.
     *
     * Android refuses to cancel the notification that is holding a service in
     * the foreground. Cancelling the alarm card first therefore did nothing,
     * and then the handover moved the foreground card to the next incident and
     * left the old card up for good.
     */
    @Test
    fun `both stop paths stop the incident before they cancel its card`() {
        for (path in listOf(
            "src/main/kotlin/app/critalarm/actions/IncidentActionReceiver.kt",
            "src/main/kotlin/app/critalarm/alarm/AlarmChannel.kt",
        )) {
            val text = source(path)
            val stop = text.indexOf("AlarmForegroundService.stopIncident(")
            val cancel = text.indexOf("cancel(AlarmNotificationFactory.notificationId(")
            assertTrue("$path must stop the incident", stop >= 0)
            assertTrue("$path must cancel the alarm card", cancel >= 0)
            assertTrue("$path cancels the alarm card before it stops it", stop < cancel)
        }
    }

    private fun source(path: String): String {
        val file = File(path)
        assertTrue("expected ${file.absolutePath}", file.isFile)
        return file.readText()
    }
}
