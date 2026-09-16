package app.critalarm.notifications

import org.junit.Assert.assertEquals
import org.junit.Test

class IncidentFaceTest {
    @Test
    fun `open rings in crit red with the alarmed face`() {
        val state = IncidentCardState.OPEN
        assertEquals(CritAlarmFace.ALARMED, state.face)
        assertEquals("RINGING", state.chipText)
        assertEquals(0xFFF5473A.toInt(), state.accentColor)
    }

    @Test
    fun `acked is awake in cobalt`() {
        val state = IncidentCardState.ACKED
        assertEquals(CritAlarmFace.ACKED, state.face)
        assertEquals("AWAKE", state.chipText)
        assertEquals(0xFF2A3BD8.toInt(), state.accentColor)
    }

    @Test
    fun `closed is calm in yellow`() {
        val state = IncidentCardState.CLOSED
        assertEquals(CritAlarmFace.CALM, state.face)
        assertEquals("CLOSED", state.chipText)
        assertEquals(0xFFFFC93C.toInt(), state.accentColor)
    }

    @Test
    fun `expired is worried in high orange`() {
        val state = IncidentCardState.EXPIRED
        assertEquals(CritAlarmFace.WORRIED, state.face)
        assertEquals("MISSED", state.chipText)
        assertEquals(0xFFFF8A1F.toInt(), state.accentColor)
    }

    @Test
    fun `acked face strokes in white, every other face strokes in ink`() {
        assertEquals(0xFFFFFFFF.toInt(), CritAlarmFace.ACKED.strokeColor)
        assertEquals(0xFF1A140F.toInt(), CritAlarmFace.ALARMED.strokeColor)
        assertEquals(0xFF1A140F.toInt(), CritAlarmFace.CALM.strokeColor)
    }
}
