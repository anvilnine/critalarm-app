package app.critalarm.reminders

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ReminderHoldRuleTest {

    @Test
    fun `a reminder waits while the service is playing an alarm`() {
        assertTrue(
            ReminderHoldRule.holdsReminder(alarmRinging = true, activeIncidentIds = emptyList()),
        )
    }

    @Test
    fun `a reminder waits in the quiet gap before the next ring`() {
        // Stop leaves the incident active, so a re-arm is still coming.
        assertTrue(
            ReminderHoldRule.holdsReminder(
                alarmRinging = false,
                activeIncidentIds = listOf("inc_1"),
            ),
        )
    }

    @Test
    fun `a reminder goes out when nothing is under way`() {
        assertFalse(
            ReminderHoldRule.holdsReminder(alarmRinging = false, activeIncidentIds = emptyList()),
        )
    }

    @Test
    fun `nothing held is posted while an incident is still open`() {
        assertEquals(
            emptyList<Int>(),
            ReminderHoldRule.released(
                heldIds = listOf(7, 3),
                alarmRinging = false,
                activeIncidentIds = listOf("inc_1"),
            ),
        )
    }

    @Test
    fun `every held reminder is posted after the last ack`() {
        assertEquals(
            listOf(3, 7),
            ReminderHoldRule.released(
                heldIds = listOf(7, 3),
                alarmRinging = false,
                activeIncidentIds = emptyList(),
            ),
        )
    }
}
