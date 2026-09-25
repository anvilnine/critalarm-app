package app.critalarm.notifications

import java.time.ZoneId
import java.time.ZonedDateTime
import java.util.Locale
import org.junit.Assert.assertEquals
import org.junit.Test

class LiveCardTextTest {
    private val manila = ZoneId.of("Asia/Manila")

    private fun millis(zone: ZoneId, hour: Int, minute: Int, day: Int = 25) =
        ZonedDateTime.of(2026, 9, day, hour, minute, 0, 0, zone).toInstant().toEpochMilli()

    private fun line(at: Long?, zone: ZoneId = manila, is24Hour: Boolean = true) =
        LiveCardText.ackedLine(at, zone, LiveCardText.patternFor(is24Hour), Locale.US)

    @Test
    fun `acked line reads the time in the given zone`() {
        assertEquals("Acknowledged at 03:12", line(millis(manila, 3, 12)))
    }

    @Test
    fun `acked line pads the hour and minute`() {
        assertEquals("Acknowledged at 09:05", line(millis(manila, 9, 5)))
    }

    @Test
    fun `acked line past midnight in the zone uses that zone's clock`() {
        // 16:30 UTC on the 25th is 00:30 on the 26th in Manila.
        val at = millis(ZoneId.of("UTC"), 16, 30)
        assertEquals("Acknowledged at 00:30", line(at))
        assertEquals("Acknowledged at 16:30", line(at, ZoneId.of("UTC")))
    }

    @Test
    fun `acked line follows a 12 hour phone`() {
        assertEquals("Acknowledged at 3:12 PM", line(millis(manila, 15, 12), is24Hour = false))
        assertEquals("Acknowledged at 12:30 AM", line(millis(manila, 0, 30), is24Hour = false))
    }

    @Test
    fun `acked line on a 24 hour phone keeps the 24 hour clock`() {
        assertEquals("Acknowledged at 15:12", line(millis(manila, 15, 12), is24Hour = true))
    }

    @Test
    fun `an ack time this phone does not know reads Acknowledged alone`() {
        assertEquals("Acknowledged", line(null))
        assertEquals("Acknowledged", line(null, is24Hour = false))
    }
}
