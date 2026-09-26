package app.critalarm.localreminders

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LocalReminderHoldRuleTest {

    @Test
    fun `a reminder waits while the service is playing an alarm`() {
        assertTrue(
            LocalReminderHoldRule.holdsReminder(alarmRinging = true, activeIncidentIds = emptyList()),
        )
    }

    @Test
    fun `a reminder waits in the quiet gap before the next ring`() {
        // Stop leaves the incident active, so a re-arm is still coming.
        assertTrue(
            LocalReminderHoldRule.holdsReminder(
                alarmRinging = false,
                activeIncidentIds = listOf("inc_1"),
            ),
        )
    }

    @Test
    fun `a reminder goes out when nothing is under way`() {
        assertFalse(
            LocalReminderHoldRule.holdsReminder(alarmRinging = false, activeIncidentIds = emptyList()),
        )
    }

    @Test
    fun `nothing held is posted while an incident is still open`() {
        assertEquals(
            emptyList<Int>(),
            LocalReminderHoldRule.released(
                heldIds = listOf(7, 3),
                alarmRinging = false,
                activeIncidentIds = listOf("inc_1"),
            ),
        )
    }

    @Test
    fun `a held reminder goes out when the incident expires instead`() {
        val held = listOf(4)
        // Ringing: it waits.
        assertEquals(
            emptyList<Int>(),
            LocalReminderHoldRule.released(
                heldIds = held,
                alarmRinging = true,
                activeIncidentIds = listOf("inc_1"),
            ),
        )
        // `ring_until` passed, or an expire push landed. Either way the
        // service is empty and the incident is no longer active, so the
        // reminder goes out without an ack ever arriving.
        assertEquals(
            listOf(4),
            LocalReminderHoldRule.released(
                heldIds = held,
                alarmRinging = false,
                activeIncidentIds = emptyList(),
            ),
        )
    }

    @Test
    fun `every held reminder is posted after the last ack`() {
        assertEquals(
            listOf(3, 7),
            LocalReminderHoldRule.released(
                heldIds = listOf(7, 3),
                alarmRinging = false,
                activeIncidentIds = emptyList(),
            ),
        )
    }
}
