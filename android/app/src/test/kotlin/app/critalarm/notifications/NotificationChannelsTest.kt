package app.critalarm.notifications

import org.junit.Assert.assertEquals
import org.junit.Test

class NotificationChannelsTest {
    @Test
    fun `channel IDs only change with explicit version`() {
        assertEquals("critical_alarm_v1", NotificationChannels.alarmChannelId())
        assertEquals(NotificationChannels.alarmChannelId(), NotificationChannels.alarmChannelId())
        assertEquals("critical_alarm_v2", NotificationChannels.alarmChannelId(2))
        assertEquals("incident_status_v1", NotificationChannels.statusChannelId())
        assertEquals("incident_status_v2", NotificationChannels.statusChannelId(2))
    }
}
