package app.critalarm.taps

import app.critalarm.LaunchTap
import app.critalarm.MainActivity
import app.critalarm.TapRoute
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * What MainActivity does with a start, from the gate's verdict on: the lock
 * screen flags and the route Flutter starts on.
 */
class TapLockRuleTest {
    private val key = ByteArray(TapKeyFile.SIZE) { (it * 7).toByte() }

    /**
     * The routing extras MainActivity's readers see after the gate: all of
     * them for a good mark, none otherwise (TapGate.admit strips them).
     */
    private fun afterGate(values: Map<String, String?>, verdict: TapVerdict): Map<String, String?> =
        if (verdict == TapVerdict.SIGNED) TapSignature.FIELDS.associateWith { values[it] } else emptyMap()

    private fun alarmStart(incidentId: String) = mapOf(
        MainActivity.EXTRA_ALARM_INCIDENT_ID to incidentId,
        MainActivity.EXTRA_INCIDENT_ID to incidentId,
    )

    /** The same steps MainActivity takes: verdict, then the lock rule. */
    private fun showsOverLock(values: Map<String, String?>, mark: String?, owesAck: (String) -> Boolean): Boolean {
        val signed = TapSignature.verdict(values, mark) { key } == TapVerdict.SIGNED
        val kept = afterGate(values, if (signed) TapVerdict.SIGNED else TapVerdict.REFUSED)
        return TapLockRule.showsFor(signed, kept[MainActivity.EXTRA_ALARM_INCIDENT_ID], owesAck)
    }

    /** The same steps onCreate takes to the route Flutter is handed. */
    private fun initialRoute(values: Map<String, String?>, mark: String?): String {
        val verdict = TapSignature.verdict(values, mark) { key }
        val kept = afterGate(values, verdict)
        val launch = LaunchTap {
            val incidentId = kept[MainActivity.EXTRA_ALARM_INCIDENT_ID] ?: kept[MainActivity.EXTRA_INCIDENT_ID]
            val topic = kept[MainActivity.EXTRA_TOPIC]
            val open = kept[MainActivity.EXTRA_OPEN]
            if (incidentId == null && topic == null && open == null) {
                null
            } else {
                TapRoute.tapFor(1, incidentId, topic, open, null, kept[MainActivity.EXTRA_FROM])
            }
        }
        return TapRoute.initialRoute(launch.route)
    }

    @Test
    fun `a forged start for a real ringing incident does not turn the lock flags on`() {
        val ringing = alarmStart("inc_ringing")
        assertFalse(showsOverLock(ringing, null) { true })
        assertFalse(showsOverLock(ringing, "0".repeat(64)) { true })
        // A mark copied from another incident's alarm.
        val other = TapSignature.sign(key, alarmStart("inc_other"))
        assertFalse(showsOverLock(ringing, other) { true })
    }

    @Test
    fun `a forged start does not ask whether the incident owes an ack`() {
        var asked = false
        assertFalse(TapLockRule.showsFor(signed = false, incidentId = "inc_a") { asked = true; true })
        assertFalse(asked)
    }

    @Test
    fun `a signed start for a ringing incident turns the lock flags on`() {
        val ringing = alarmStart("inc_ringing")
        assertTrue(showsOverLock(ringing, TapSignature.sign(key, ringing)) { it == "inc_ringing" })
    }

    @Test
    fun `a signed start for an incident that owes no ack still does not`() {
        val answered = alarmStart("inc_answered")
        assertFalse(showsOverLock(answered, TapSignature.sign(key, answered)) { false })
        assertFalse(TapLockRule.showsFor(signed = true, incidentId = "") { true })
        assertFalse(TapLockRule.showsFor(signed = true, incidentId = null) { true })
    }

    @Test
    fun `a forged route never reaches the initial route`() {
        // Flutter's own extra is not a routing extra: the start is a plain one.
        val plain = mapOf(TapSignature.FLUTTER_ROUTE to "/paywall")
        assertEquals(TapVerdict.NONE, TapSignature.verdict(plain, null) { key })
        assertEquals(TapRoute.HOME, initialRoute(plain, null))
        assertEquals(TapRoute.HOME, TapRoute.initialRoute(null))
    }

    @Test
    fun `each forged routing extra opens Home`() {
        val forged = listOf(
            mapOf(MainActivity.EXTRA_INCIDENT_ID to "inc_a"),
            mapOf(MainActivity.EXTRA_ALARM_INCIDENT_ID to "inc_a"),
            mapOf(MainActivity.EXTRA_TOPIC to "new"),
            mapOf(MainActivity.EXTRA_OPEN to MainActivity.OPEN_PAYWALL),
            mapOf(MainActivity.EXTRA_INCIDENT_ID to "inc_a", MainActivity.EXTRA_FROM to MainActivity.FROM_DONE),
            mapOf(MainActivity.EXTRA_INCIDENT_ID to "inc_a", TapSignature.FLUTTER_ROUTE to "/settings"),
        )
        for (values in forged) {
            assertEquals(values.toString(), TapRoute.HOME, initialRoute(values, null))
            assertEquals(TapVerdict.REFUSED, TapSignature.verdict(values, null) { key })
        }
    }

    @Test
    fun `signed taps land where they did`() {
        val incident = mapOf(MainActivity.EXTRA_INCIDENT_ID to "inc_a")
        assertEquals("/incidents/inc_a", initialRoute(incident, TapSignature.sign(key, incident)))
        val done = incident + (MainActivity.EXTRA_FROM to MainActivity.FROM_DONE)
        assertEquals("/incidents/inc_a?from=done", initialRoute(done, TapSignature.sign(key, done)))
        val topic = mapOf(MainActivity.EXTRA_TOPIC to "prod")
        assertEquals("/topics/prod", initialRoute(topic, TapSignature.sign(key, topic)))
        val paywall = mapOf(MainActivity.EXTRA_OPEN to MainActivity.OPEN_PAYWALL)
        assertEquals("/paywall", initialRoute(paywall, TapSignature.sign(key, paywall)))
    }

    @Test
    fun `a plain launch has no tap and opens Home`() {
        val launch = LaunchTap { null }
        assertNull(launch.route)
        assertEquals(TapRoute.HOME, TapRoute.initialRoute(launch.route))
    }
}
