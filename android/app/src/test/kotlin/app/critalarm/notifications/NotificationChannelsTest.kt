package app.critalarm.notifications

import org.junit.Assert.assertEquals
import org.junit.Test

class NotificationChannelsTest {
    @Test
    fun `channel IDs only change with explicit version`() {
        assertEquals("message_standard_v1", NotificationChannels.standardChannelId())
        assertEquals("message_standard_v2", NotificationChannels.standardChannelId(2))
        assertEquals("message_high_v1", NotificationChannels.highChannelId())
        assertEquals("message_high_v2", NotificationChannels.highChannelId(2))
        assertEquals("critical_alarm_v1", NotificationChannels.alarmChannelId())
        assertEquals(NotificationChannels.alarmChannelId(), NotificationChannels.alarmChannelId())
        assertEquals("critical_alarm_v2", NotificationChannels.alarmChannelId(2))
        assertEquals("incident_status_v1", NotificationChannels.cardChannelId())
        assertEquals("incident_status_v2", NotificationChannels.cardChannelId(2))
    }

    @Test
    fun `all four channels are distinct`() {
        val ids = NotificationChannels.allChannelIds()
        assertEquals(4, ids.size)
        assertEquals(4, ids.toSet().size)
    }
}
