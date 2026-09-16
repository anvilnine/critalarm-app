package app.critalarm.notifications

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * One incident, two cards, and every post and cancel keyed the same way.
 *
 * Android keys a notification by tag and id together. AlarmForegroundService
 * posts the alarm card with startForeground, which takes no tag, so a tagged
 * notify of the same id is a second card and a second status bar chip. The
 * whole point of A18 is one card and one chip, so the scan below is what stops
 * a future edit putting the tag back.
 */
class NotificationKeyingTest {
    private val sources = File("src/main/kotlin/app/critalarm")

    @Test
    fun `the alarm card and the status card have different ids`() {
        val incidentId = "inc_9a8b7c"
        assertNotEquals(
            AlarmNotificationFactory.notificationId(incidentId),
            StatusNotificationFactory.notificationId(incidentId),
        )
    }

    @Test
    fun `an id is the same every time it is asked for`() {
        assertEquals(
            AlarmNotificationFactory.notificationId("inc_9a8b7c"),
            AlarmNotificationFactory.notificationId("inc_9a8b7c"),
        )
        assertEquals(
            StatusNotificationFactory.notificationId("inc_9a8b7c"),
            StatusNotificationFactory.notificationId("inc_9a8b7c"),
        )
    }

    @Test
    fun `the sources are where this test thinks they are`() {
        assertTrue(
            "expected Kotlin sources at ${sources.absolutePath}",
            sources.isDirectory && kotlinFiles().isNotEmpty(),
        )
    }

    @Test
    fun `no notify or cancel passes a tag`() {
        // The tag overload takes the tag first. Every tag this app ever passed
        // was the incident id, and a string literal would be one too, so those
        // are what the scan looks for.
        val tagLike = Regex("^(incidentId|payload\\.incidentId|\").*")
        val tagged = mutableListOf<String>()
        for (file in kotlinFiles()) {
            val flattened = file.readText().replace(Regex("\\s+"), "")
            for (call in Regex("\\.(notify|cancel)\\(([^,)]*)[,)]").findAll(flattened)) {
                val first = call.groupValues[2]
                if (!tagLike.matches(first)) continue
                tagged += "${file.name}: ${call.value}"
            }
        }
        assertEquals("tagged notify or cancel calls: $tagged", emptyList<String>(), tagged)
    }

    private fun kotlinFiles() = sources.walkTopDown().filter { it.extension == "kt" }.toList()
}
