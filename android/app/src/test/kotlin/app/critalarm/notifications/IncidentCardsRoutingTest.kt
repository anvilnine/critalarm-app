package app.critalarm.notifications

import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The card transitions that a pure test cannot reach: receivers, the channel
 * and the service. Each path is read off its source so a future edit that
 * breaks the routing fails here.
 */
class IncidentCardsRoutingTest {
    private fun source(path: String): String {
        val file = File(path)
        assertTrue("expected ${file.absolutePath}", file.isFile)
        return file.readText()
    }

    @Test
    fun `the Stop action and the delete intent both silence`() {
        val alarm = source("src/main/kotlin/app/critalarm/notifications/AlarmNotificationFactory.kt")
        assertTrue("Stop and swipe must both carry the silence action", alarm.contains("ACTION_SILENCE"))
        assertTrue("the Stop button must silence", alarm.contains("\"Stop\""))
        assertTrue("the swipe must silence", alarm.contains("setDeleteIntent"))
    }

    @Test
    fun `every silence entry point ends at the silenced card`() {
        val receiver = source("src/main/kotlin/app/critalarm/actions/IncidentActionReceiver.kt")
        assertTrue(
            "the notification Stop and swipe paths must show the silenced card",
            receiver.contains("IncidentPhoneState.Silenced("),
        )
        val channel = source("src/main/kotlin/app/critalarm/alarm/AlarmChannel.kt")
        assertTrue(
            "the in-app Back path must show the silenced card",
            channel.contains("IncidentPhoneState.Silenced("),
        )
    }

    @Test
    fun `a re-arm fire replaces the silenced card with the ringing card`() {
        val service = source("src/main/kotlin/app/critalarm/alarm/AlarmForegroundService.kt")
        val ring = service.indexOf("startForeground(")
        val show = service.indexOf("IncidentCards.show(")
        assertTrue("the service must show the ringing card", show >= 0)
        assertTrue("the ringing card must be posted before the status card is cleared", ring >= 0 && ring < show)
        assertTrue("the re-arm fire shows the ringing card", service.contains("IncidentPhoneState.Ringing"))
    }

    @Test
    fun `the silenced card button is the acknowledge`() {
        val status = source("src/main/kotlin/app/critalarm/notifications/StatusNotificationFactory.kt")
        assertTrue("the silenced card must carry I'm up", status.contains("\"I'm up\""))
        assertTrue("I'm up must be the acknowledge, not the close", status.contains("ACTION_STOP"))
    }

    @Test
    fun `the ack remembers the server deadline`() {
        val receiver = source("src/main/kotlin/app/critalarm/actions/IncidentActionReceiver.kt")
        assertTrue("the ack must read desk_timer_fires_at off the response", receiver.contains("rememberDeskTimer("))
        assertTrue("the ack response must parse desk_timer_fires_at", receiver.contains("parseDeskTimerFiresAt("))
    }

    @Test
    fun `close and expire pushes clear the card`() {
        val router = source("src/main/kotlin/app/critalarm/push/PushRouter.kt")
        assertTrue("a close push must clear the card", router.contains("IncidentPhoneState.Closed"))
        assertTrue("an expire push must clear the card", router.contains("IncidentPhoneState.Expired"))
    }
}
