package app.critalarm.check

import app.critalarm.push.FcmIncidentPayload
import app.critalarm.push.IncidentPushKind
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Which pushes are a weekly check (api.md §5.4), and what happens to them. */
class CheckPushTest {
    private val check = mapOf("kind" to "check", "check_id" to "chk_5c1d", "attempt" to "1")
    private val alarm = mapOf(
        "incident_id" to "inc_9a8b7c",
        "server" to "https://alerts.example.com",
        "kind" to "open",
        "priority" to "5",
        "ring_until" to "1757464200",
    )

    @Test
    fun `the contract's FCM data parses as a check`() {
        val push = CheckPush.fromData(check)
        assertNotNull(push)
        assertEquals("chk_5c1d", push?.checkId)
        assertEquals(1, push?.attempt)
    }

    @Test
    fun `attempt is a note, and a check without one is still a check`() {
        val push = CheckPush.fromData(mapOf("kind" to "check", "check_id" to "chk_1"))
        assertNotNull(push)
        assertNull(push?.attempt)
        assertNull(CheckPush.fromData(check + ("attempt" to "one"))?.attempt)
    }

    @Test
    fun `a check with no id cannot be answered`() {
        assertNull(CheckPush.fromData(mapOf("kind" to "check")))
        assertNull(CheckPush.fromData(mapOf("kind" to "check", "check_id" to "")))
    }

    @Test
    fun `no incident push is a check`() {
        for (kind in IncidentPushKind.entries) {
            assertNull(kind.wireValue, CheckPush.fromData(alarm + ("kind" to kind.wireValue)))
        }
        // An id alone does not make one, and neither does an unknown kind.
        assertNull(CheckPush.fromData(alarm + ("check_id" to "chk_1")))
        assertNull(CheckPush.fromData(mapOf("kind" to "survey", "check_id" to "chk_1")))
        assertNull(CheckPush.fromData(emptyMap()))
    }

    @Test
    fun `an alarm push still parses as the alarm it is`() {
        val payload = FcmIncidentPayload.fromData(alarm)
        assertNotNull(payload)
        assertTrue(payload!!.isIncident)
        assertEquals(5, payload.priority)
        assertEquals(IncidentPushKind.OPEN, payload.kind)
    }

    @Test
    fun `a check is nothing to the incident parser`() {
        // This is what a build from before the check does with one: ignores it.
        assertNull(FcmIncidentPayload.fromData(check))
    }

    @Test
    fun `the id of a check stays out of its text form`() {
        assertFalse(CheckPush.fromData(check).toString().contains("chk_5c1d"))
    }

    @Test
    fun `the router takes the check branch first and leaves`() {
        val route = source("push/PushRouter.kt")
            .substringAfter("fun route(data: Map<String, String>): String? {")
        val branch = route.indexOf("CheckPush.fromData(data)")
        val incident = route.indexOf("FcmIncidentPayload.fromData(data)")
        assertTrue("the router must look for a check", branch >= 0)
        assertTrue("the check branch must come before the incident parser", branch < incident)
        val body = route.substring(branch, incident)
        assertTrue("the check branch must answer", body.contains("WeeklyCheckResponder.answer(context, check)"))
        assertTrue("the check branch must leave the router", body.contains("return null"))
        // Nothing the alarm path does happens before the branch is decided.
        val before = route.substring(0, branch)
        for (call in listOf("events.record", "NotificationChannels", "handleAlarm", "IncidentDeliveryStore")) {
            assertFalse("$call must not run before the check branch", before.contains(call))
        }
    }

    @Test
    fun `answering a check posts nothing and touches no alarm state`() {
        val forbidden = listOf(
            "NotificationManager",
            "NotificationCompat",
            "NotificationChannels",
            ".notify(",
            "startForeground",
            "AlarmForegroundService",
            "AlarmPlayer",
            "IncidentRearm",
            "IncidentCards",
            "IncidentDeliveryStore",
            "IncidentActionReceiver",
            "ScheduledAlarmReceiver",
            "WidgetSnapshot",
            "PushEventLog",
            "AckQueueStore",
            "LocalReminder",
            "MediaPlayer",
            "Vibrator",
            "startActivity",
            "MainActivity",
        )
        for (file in checkSources()) {
            val text = code(file)
            for (name in forbidden) {
                assertFalse("${file.name} must not use $name", text.contains(name))
            }
        }
    }

    @Test
    fun `the id of a check is never logged`() {
        for (file in checkSources()) {
            code(file).lines().filter { it.contains("Log.") }.forEach { line ->
                assertFalse("${file.name}: $line", line.contains("checkId"))
                assertFalse("${file.name}: $line", line.contains("request.url"))
                assertFalse("${file.name}: $line", line.contains("error.message"))
                assertFalse("${file.name}: $line", line.contains("\$error"))
            }
        }
    }

    @Test
    fun `the arrival record is a key nothing else reads`() {
        val main = File("src/main/kotlin/app/critalarm")
        val readers = main.walkTopDown()
            .filter { it.extension == "kt" && it.readText().contains("weekly_check.native") }
            .map { it.name }
            .toList()
        assertEquals(listOf("WeeklyCheckResponder.kt"), readers)
    }

    private fun checkSources() = File("src/main/kotlin/app/critalarm/check")
        .walkTopDown().filter { it.extension == "kt" }.toList()

    /** A source file without its comments, which name what the code leaves alone. */
    private fun code(file: File) = file.readLines()
        .filterNot { it.trim().startsWith("//") || it.trim().startsWith("*") || it.trim().startsWith("/*") }
        .joinToString("\n")

    private fun source(path: String) = File("src/main/kotlin/app/critalarm/$path").readText()
}
