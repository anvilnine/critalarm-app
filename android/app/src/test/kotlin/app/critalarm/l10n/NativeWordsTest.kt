package app.critalarm.l10n

import app.critalarm.notifications.IncidentCardState
import app.critalarm.notifications.LiveCardText
import app.critalarm.notifications.NotificationChannels
import app.critalarm.notifications.StatusNotificationFactory
import app.critalarm.push.FcmIncidentPayload
import app.critalarm.push.IncidentContentFetcher
import app.critalarm.push.IncidentPushKind
import app.critalarm.widgets.WidgetRows
import java.io.File
import java.net.URI
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class NativeWordsTest {
    /** Stands in for a translation: every template wrapped, placeholders kept. */
    private val pseudo = NativeWords { "[" + it.english + "]" }

    @Test
    fun `placeholders are filled by name, wherever a translation puts them`() {
        val moved = NativeWords { "{seconds} s: " + it.english.substringBefore(" in") }
        assertEquals(
            "Stopped. Rings again in 30 s. Tap I'm up to end it.",
            NativeWords.English.text(NativeText.CARD_SILENCED, "seconds" to 30),
        )
        assertEquals("30 s: Stopped. Rings again", moved.text(NativeText.CARD_SILENCED, "seconds" to 30))
    }

    @Test
    fun `channel names follow the words and the ids never move`() {
        val english = NotificationChannels.channelWords(NativeWords.English)
        val switched = NotificationChannels.channelWords(pseudo)
        assertEquals(english.map { it.id }, switched.map { it.id })
        assertEquals(
            listOf(
                NotificationChannels.standardChannelId(),
                NotificationChannels.highChannelId(),
                NotificationChannels.alarmChannelId(),
                NotificationChannels.cardChannelId(),
                NotificationChannels.REMINDERS_CHANNEL_ID,
                NotificationChannels.OFFERS_CHANNEL_ID,
            ),
            english.map { it.id },
        )
        assertEquals(
            listOf("Messages", "Urgent messages", "Critical alarms", "Incident status", "Local reminders", "Offers"),
            english.map { it.name },
        )
        assertEquals("Audible on-call incident alarms", english[2].description)
        for ((before, after) in english.zip(switched)) {
            assertNotEquals(before.name, after.name)
            assertEquals("[${before.name}]", after.name)
            assertEquals("[${before.description}]", after.description)
        }
    }

    @Test
    fun `the cards and widgets read their words from the words they are given`() {
        assertEquals("[Acknowledged]", LiveCardText.ackedLine(null, words = pseudo))
        assertEquals("[Stopped. Rings again in 5 s. Tap I'm up to end it.]", StatusNotificationFactory.silencedText(5, pseudo))
        assertEquals("RINGING", IncidentCardState.OPEN.chipText)
        assertEquals("[AWAKE]", IncidentCardState.ACKED.chipText(pseudo))
        assertEquals("[All quiet]", WidgetRows.countText(0, pseudo))
        assertEquals("[3 open]", WidgetRows.countText(3, pseudo))
        assertEquals("[+2 more]", WidgetRows.moreText(2, pseudo))
        val payload = FcmIncidentPayload(
            incidentId = "inc_1",
            server = URI("https://alerts.example.com"),
            kind = IncidentPushKind.OPEN,
            priority = 5,
            title = null,
            body = null,
        )
        val english = IncidentContentFetcher.fallback(payload)
        assertEquals("Critical incident", english.title)
        assertEquals("Immediate attention required", english.body)
        assertEquals("[Critical incident]", IncidentContentFetcher.fallback(payload, pseudo).title)
    }

    @Test
    fun `every entry has its English in the default strings file`() {
        val xml = File("src/main/res/values/strings.xml").readText()
        for (text in NativeText.entries) {
            val name = "native_" + text.name.lowercase()
            val escaped = text.english
                .replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                .replace("'", "\\'").replace("\"", "\\\"")
            assertTrue(
                "${text.name} must be <string name=\"$name\">$escaped</string>",
                xml.contains("<string name=\"$name\">$escaped</string>"),
            )
        }
    }
}
