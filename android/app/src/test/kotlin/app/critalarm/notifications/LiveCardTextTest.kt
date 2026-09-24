package app.critalarm.notifications

import java.time.ZoneId
import java.time.ZonedDateTime
import org.junit.Assert.assertEquals
import org.junit.Test

class LiveCardTextTest {
    private val manila = ZoneId.of("Asia/Manila")

    private fun millis(zone: ZoneId, hour: Int, minute: Int, day: Int = 25) =
        ZonedDateTime.of(2026, 9, day, hour, minute, 0, 0, zone).toInstant().toEpochMilli()

    @Test
    fun `acked line reads the time in the given zone`() {
        assertEquals("Acknowledged at 03:12", LiveCardText.ackedLine(millis(manila, 3, 12), manila))
    }

    @Test
    fun `acked line pads the hour and minute`() {
        assertEquals("Acknowledged at 09:05", LiveCardText.ackedLine(millis(manila, 9, 5), manila))
    }

    @Test
    fun `acked line past midnight in the zone uses that zone's clock`() {
        // 16:30 UTC on the 25th is 00:30 on the 26th in Manila.
        val at = millis(ZoneId.of("UTC"), 16, 30)
        assertEquals("Acknowledged at 00:30", LiveCardText.ackedLine(at, manila))
        assertEquals("Acknowledged at 16:30", LiveCardText.ackedLine(at, ZoneId.of("UTC")))
    }
}
