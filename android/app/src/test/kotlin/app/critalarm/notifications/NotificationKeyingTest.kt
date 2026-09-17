package app.critalarm.notifications

import app.critalarm.push.FcmIncidentPayload
import app.critalarm.push.IncidentPushKind
import java.io.File
import java.net.URI
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * One incident, three cards, and every post and cancel keyed the same way.
 *
 * Android keys a notification by tag and id together. AlarmForegroundService
 * posts the alarm card with startForeground, which takes no tag, so a tagged
 * notify of the same id is a second card and a second status bar chip. The
 * whole point of A18 is one card and one chip, so the scan below is what stops
 * a future edit putting the tag back.
 */
class NotificationKeyingTest {
    private val sources = File("src/main/kotlin/app/critalarm")

    private fun payload(
        incidentId: String?,
        kind: IncidentPushKind = IncidentPushKind.OPEN,
        title: String? = null,
        body: String? = null,
    ) = FcmIncidentPayload(
        incidentId = incidentId,
        server = URI("https://relay.example.com"),
        kind = kind,
        priority = if (kind == IncidentPushKind.P4) 4 else 5,
        title = title,
        body = body,
    )

    @Test
    fun `the three cards have three different ids for one incident`() {
        val incidentId = "inc_9a8b7c"
        val ids = listOf(
            AlarmNotificationFactory.notificationId(incidentId),
            StatusNotificationFactory.notificationId(incidentId),
            MessageNotificationFactory.notificationId(payload(incidentId)),
        )
        // A message card landing on the alarm card's id replaces the
        // full-screen intent and the Stop button while the service keeps
        // ringing, so the shade has nothing left to stop it with.
        assertEquals("ids collide: $ids", 3, ids.toSet().size)
    }

    @Test
    fun `two p4 forwards from one server get two ids`() {
        // A p4 carries no incident id, so the text is all there is to tell two
        // of them apart. Keyed on the server alone, each one replaced the last.
        assertNotEquals(
            MessageNotificationFactory.notificationId(
                payload(null, IncidentPushKind.P4, title = "disk filling up", body = "83 percent"),
            ),
            MessageNotificationFactory.notificationId(
                payload(null, IncidentPushKind.P4, title = "backup finished", body = "in 4 minutes"),
            ),
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
        assertEquals(
            MessageNotificationFactory.notificationId(payload("inc_9a8b7c")),
            MessageNotificationFactory.notificationId(payload("inc_9a8b7c")),
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
        // Counted, not matched on shape. The tagged overloads are
        // notify(tag, id, notification) and cancel(tag, id), so three
        // arguments and two arguments are the tells. An earlier version of
        // this test read the first argument and only knew three spellings of
        // it, so notify(cardTag, id, n) would have walked straight past.
        val flagged = mutableListOf<String>()
        for (file in kotlinFiles()) {
            val code = strippedCode(file.readText())
            for (call in Regex("\\.(notify|cancel)\\s*\\(").findAll(code)) {
                if (receiverIsTypeName(code, call.range.first)) continue
                val name = call.groupValues[1]
                val args = argCount(code, call.range.last + 1)
                val tagged = (name == "notify" && args == 3) || (name == "cancel" && args == 2)
                if (tagged) flagged += "${file.name}: $name with $args arguments"
            }
        }
        assertEquals("tagged notify or cancel calls: $flagged", emptyList<String>(), flagged)
    }

    @Test
    fun `the scan tells a tag apart from a trailing comma`() {
        fun count(source: String): Int {
            val code = strippedCode(source)
            return argCount(code, code.indexOf('(') + 1)
        }
        // The shape the old regex walked past.
        assertEquals(3, count("manager.notify(cardTag, id, n)"))
        assertEquals(2, count("manager.notify(\n  id,\n  create(a, b),\n)"))
        assertEquals(1, count("manager.cancel(idFor(\"x, y\"))"))
    }

    /**
     * True when the call is one of our own helpers rather than the
     * notification manager. `ScheduledAlarmReceiver.cancel(context,
     * incidentId)` is the one in the tree today, and its two arguments are not
     * a tag and an id.
     *
     * Named, not guessed. This used to skip anything starting with a capital,
     * so a local called `Manager` or a helper added later walked straight past
     * the scan that is the point of this file.
     */
    private fun receiverIsTypeName(code: String, dotIndex: Int): Boolean {
        var i = dotIndex - 1
        while (i >= 0 && (code[i].isLetterOrDigit() || code[i] == '_')) i--
        val start = i + 1
        return start < dotIndex && code.substring(start, dotIndex) in OUR_HELPERS
    }

    /**
     * How many arguments the call starting after [afterOpen] passes. Counts
     * the pieces that hold something rather than the commas, because Kotlin
     * lets the last argument carry a trailing comma and most of these calls do.
     */
    private fun argCount(code: String, afterOpen: Int): Int {
        var depth = 1
        var args = 0
        var filled = false
        var i = afterOpen
        while (i < code.length && depth > 0) {
            when (val c = code[i]) {
                '(', '[', '{' -> { depth++; filled = true }
                ')', ']', '}' -> { depth--; if (depth > 0) filled = true }
                ',' -> if (depth > 1) {
                    filled = true
                } else {
                    if (filled) args++
                    filled = false
                }
                else -> if (!c.isWhitespace()) filled = true
            }
            i++
        }
        return if (filled) args + 1 else args
    }

    /**
     * The file with comments dropped and every string and character literal
     * emptied, so a bracket or a comma inside one cannot throw the count off.
     */
    private fun strippedCode(text: String): String {
        val out = StringBuilder()
        var i = 0
        while (i < text.length) {
            val c = text[i]
            when {
                c == '/' && text.startsWith("//", i) -> {
                    while (i < text.length && text[i] != '\n') i++
                }
                c == '/' && text.startsWith("/*", i) -> {
                    i += 2
                    while (i < text.length && !text.startsWith("*/", i)) i++
                    i += 2
                }
                text.startsWith("\"\"\"", i) -> {
                    out.append("\"\"")
                    i += 3
                    while (i < text.length && !text.startsWith("\"\"\"", i)) i++
                    i += 3
                }
                c == '"' -> {
                    out.append("\"\"")
                    i++
                    while (i < text.length && text[i] != '"') {
                        if (text[i] == '\\') i++
                        i++
                    }
                    i++
                }
                c == '\'' -> {
                    out.append('0')
                    i++
                    while (i < text.length && text[i] != '\'') {
                        if (text[i] == '\\') i++
                        i++
                    }
                    i++
                }
                else -> { out.append(c); i++ }
            }
        }
        return out.toString()
    }

    private fun kotlinFiles() = sources.walkTopDown().filter { it.extension == "kt" }.toList()

    private companion object {
        /** Our own types with a `cancel` of their own. Add one when you write one. */
        val OUR_HELPERS = setOf("ScheduledAlarmReceiver")
    }
}
