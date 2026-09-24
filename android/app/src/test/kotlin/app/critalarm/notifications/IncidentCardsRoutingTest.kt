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
    fun `the ringing card is posted before the status card is cancelled`() {
        val cards = source("src/main/kotlin/app/critalarm/notifications/IncidentCards.kt")
        val post = cards.indexOf("postRinging()")
        val cancel = cards.indexOf("manager.cancel(StatusNotificationFactory.notificationId(incidentId))")
        assertTrue("the ringing card must be posted before the status card is cleared", post >= 0 && cancel > post)
    }

    @Test
    fun `the silenced card button is the acknowledge`() {
        val status = source("src/main/kotlin/app/critalarm/notifications/StatusNotificationFactory.kt")
        assertTrue("the silenced card must carry I'm up", status.contains("\"I'm up\""))
        assertTrue("I'm up must be the acknowledge, not the close", status.contains("ACTION_STOP"))
    }

    @Test
    fun `a tap on the status card opens the incident`() {
        val status = source("src/main/kotlin/app/critalarm/notifications/StatusNotificationFactory.kt")
        val launch = status.substringAfter("private fun incidentLaunchIntent(", "")
        assertTrue("the status card must build a launch intent", launch.isNotEmpty())
        assertTrue(
            "the launch intent must carry the incident id MainActivity reads",
            launch.substringBefore("\n\n").contains("putExtra(MainActivity.EXTRA_INCIDENT_ID, incidentId)"),
        )
        assertTrue("the card's content intent must be the launch intent", status.contains("incidentLaunchIntent(context, incidentId)"))
    }

    @Test
    fun `a remote ack card does not print the push arrival as the ack time`() {
        val cards = source("src/main/kotlin/app/critalarm/notifications/IncidentCards.kt")
        assertTrue(
            "the acked card must only print a time this phone recorded",
            cards.contains("val ackTimeKnown = deliveries.locallyAcknowledgedAtMillis(incidentId) != null"),
        )
        val status = source("src/main/kotlin/app/critalarm/notifications/StatusNotificationFactory.kt")
        assertTrue("an unknown ack time must reach the line as null", status.contains("ackedAtMillis.takeIf { ackTimeKnown }"))
        val router = source("src/main/kotlin/app/critalarm/push/PushRouter.kt")
        assertTrue("a remote ack must not count as an ack made here", !router.contains("markLocallyAcknowledged("))
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
