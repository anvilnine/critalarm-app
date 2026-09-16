package app.critalarm.alarm

import java.io.File
import org.junit.Assert.assertFalse
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
    fun `stopping the ringing incident stops the service`() {
        assertTrue(AlarmStopRule.stopsService("inc_a", ringingIncidentId = "inc_a"))
    }

    @Test
    fun `stopping another incident leaves the ring alone`() {
        assertFalse(AlarmStopRule.stopsService("inc_b", ringingIncidentId = "inc_a"))
    }

    @Test
    fun `with nothing ringing there is nothing to stop`() {
        assertFalse(AlarmStopRule.stopsService("inc_b", ringingIncidentId = null))
    }

    @Test
    fun `the id has to match exactly`() {
        assertFalse(AlarmStopRule.stopsService("inc_a", ringingIncidentId = "inc_a2"))
        assertFalse(AlarmStopRule.stopsService("inc_a", ringingIncidentId = "INC_A"))
    }

    /**
     * The rule above is only worth having if every caller asks it. A pure test
     * cannot reach a Service, so this reads the call sites instead.
     */
    @Test
    fun `the channel asks the rule before it stops the service`() {
        assertGuardsStopService(
            "src/main/kotlin/app/critalarm/alarm/AlarmChannel.kt",
        )
    }

    /**
     * The Stop button on the notification goes through here, and it used to
     * stop the service on sight. A card can outlive its own alarm: a late
     * enrichment re-posts the alarm card for an incident that stopped being
     * the ringing one seconds ago, and its Stop then killed a live alarm
     * nobody had acknowledged.
     */
    @Test
    fun `the notification ack route asks the rule before it stops the service`() {
        assertGuardsStopService(
            "src/main/kotlin/app/critalarm/actions/IncidentActionReceiver.kt",
        )
    }

    private fun assertGuardsStopService(path: String) {
        val source = File(path)
        assertTrue("expected ${source.absolutePath}", source.isFile)
        val text = source.readText()
        val guard = text.indexOf("if (AlarmStopRule.stopsService(")
        val stop = text.indexOf("stopService(Intent(")
        assertTrue("$path must guard stopService with AlarmStopRule", guard >= 0)
        assertTrue("$path calls stopService with no guard before it", stop > guard)
    }
}
