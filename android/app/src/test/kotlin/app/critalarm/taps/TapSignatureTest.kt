package app.critalarm.taps

import app.critalarm.MainActivity
import app.critalarm.localreminders.LocalReminderAlarms
import app.critalarm.localreminders.LocalReminderTapIntent
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class TapSignatureTest {
    private val key = ByteArray(TapKeyFile.SIZE) { it.toByte() }
    private val otherKey = ByteArray(TapKeyFile.SIZE) { (it + 1).toByte() }

    /** Every routing extra set, the way no single intent sets them, so each one is covered. */
    private val everything: Map<String, String?> = mapOf(
        MainActivity.EXTRA_ALARM_INCIDENT_ID to "inc_a",
        MainActivity.EXTRA_INCIDENT_ID to "inc_a",
        MainActivity.EXTRA_TOPIC to "prod",
        MainActivity.EXTRA_OPEN to MainActivity.OPEN_HOME,
        MainActivity.EXTRA_FROM to MainActivity.FROM_DONE,
        LocalReminderAlarms.EXTRA_ID to "42",
        LocalReminderTapIntent.EXTRA_KIND to "plan_heads_up",
        LocalReminderTapIntent.EXTRA_ACTION to "open",
        LocalReminderTapIntent.EXTRA_PAYLOAD to "{\"url\":\"https://example.com\"}",
    )

    private val alarm: Map<String, String?> = mapOf(
        MainActivity.EXTRA_ALARM_INCIDENT_ID to "inc_a",
        MainActivity.EXTRA_INCIDENT_ID to "inc_a",
    )

    @Test
    fun `a signed intent's extras pass`() {
        val mark = TapSignature.sign(key, everything)
        assertTrue(TapSignature.matches(key, everything, mark))
        assertEquals(TapVerdict.SIGNED, TapSignature.verdict(everything, mark) { key })
    }

    @Test
    fun `the same extras always give the same mark`() {
        // A PendingIntent rebuilt with FLAG_UPDATE_CURRENT replaces the
        // extras of one already posted, so the mark has to be stable.
        assertEquals(TapSignature.sign(key, alarm), TapSignature.sign(key, alarm))
    }

    @Test
    fun `each extra changed by one character fails`() {
        val mark = TapSignature.sign(key, everything)
        for (name in TapSignature.FIELDS) {
            val value = everything.getValue(name)!!
            val changed = value.dropLast(1) + (value.last() + 1)
            val forged = everything + (name to changed)
            assertFalse("$name changed still matched", TapSignature.matches(key, forged, mark))
            val longer = everything + (name to value + "x")
            assertFalse("$name lengthened still matched", TapSignature.matches(key, longer, mark))
        }
    }

    @Test
    fun `each extra removed or added fails`() {
        val mark = TapSignature.sign(key, everything)
        for (name in TapSignature.FIELDS) {
            assertFalse(name, TapSignature.matches(key, everything - name, mark))
        }
        val alarmMark = TapSignature.sign(key, alarm)
        for (name in TapSignature.FIELDS - alarm.keys) {
            assertFalse(name, TapSignature.matches(key, alarm + (name to "x"), alarmMark))
        }
    }

    @Test
    fun `an extra moved to another slot fails`() {
        val topicTap = mapOf(MainActivity.EXTRA_TOPIC to "new")
        val mark = TapSignature.sign(key, topicTap)
        for (name in TapSignature.FIELDS - MainActivity.EXTRA_TOPIC) {
            assertFalse(name, TapSignature.matches(key, mapOf(name to "new"), mark))
        }
        // A plain incident tap's mark does not carry over to an alarm start.
        val incidentTap = mapOf(MainActivity.EXTRA_INCIDENT_ID to "inc_a")
        val incidentMark = TapSignature.sign(key, incidentTap)
        assertFalse(
            TapSignature.matches(key, mapOf(MainActivity.EXTRA_ALARM_INCIDENT_ID to "inc_a"), incidentMark),
        )
        assertFalse(TapSignature.matches(key, alarm, incidentMark))
    }

    @Test
    fun `a value split across two extras fails`() {
        val joined = mapOf(MainActivity.EXTRA_TOPIC to "ab", MainActivity.EXTRA_OPEN to "")
        val split = mapOf(MainActivity.EXTRA_TOPIC to "a", MainActivity.EXTRA_OPEN to "b")
        assertFalse(TapSignature.matches(key, split, TapSignature.sign(key, joined)))
    }

    @Test
    fun `an empty extra is not a missing one`() {
        val empty = mapOf(MainActivity.EXTRA_INCIDENT_ID to "inc_a", MainActivity.EXTRA_TOPIC to "")
        val missing = mapOf(MainActivity.EXTRA_INCIDENT_ID to "inc_a")
        assertNotEquals(TapSignature.sign(key, empty), TapSignature.sign(key, missing))
    }

    @Test
    fun `a missing mark fails`() {
        assertFalse(TapSignature.matches(key, alarm, null))
        assertEquals(TapVerdict.REFUSED, TapSignature.verdict(alarm, null) { key })
        assertEquals(TapVerdict.REFUSED, TapSignature.verdict(alarm, "") { key })
    }

    @Test
    fun `a mark made under another key fails`() {
        val mark = TapSignature.sign(otherKey, alarm)
        assertEquals(TapVerdict.REFUSED, TapSignature.verdict(alarm, mark) { key })
    }

    @Test
    fun `no key in hand refuses`() {
        val mark = TapSignature.sign(key, alarm)
        assertEquals(TapVerdict.REFUSED, TapSignature.verdict(alarm, mark) { null })
    }

    @Test
    fun `a plain launch is not checked and does not touch the key`() {
        var asked = false
        val plain = mapOf(MainActivity.EXTRA_LINK to "pass", TapSignature.FLUTTER_ROUTE to "/paywall")
        assertEquals(TapVerdict.NONE, TapSignature.verdict(plain, null) { asked = true; key })
        assertFalse(asked)
    }

    @Test
    fun `the mark is never a routing extra`() {
        assertFalse(TapSignature.EXTRA in TapSignature.FIELDS)
        assertFalse(TapSignature.FLUTTER_ROUTE in TapSignature.FIELDS)
        assertFalse(MainActivity.EXTRA_LINK in TapSignature.FIELDS)
    }
}
