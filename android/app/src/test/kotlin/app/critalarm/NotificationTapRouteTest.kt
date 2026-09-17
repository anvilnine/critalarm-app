package app.critalarm

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * A tapped notification opens a screen, never "Page Not Found".
 *
 * The tap intents carry two things: extras, which MainActivity reads and turns
 * into a go_router path, and a `critalarm://` data URI, which is only there to
 * keep two PendingIntents apart. There is no intent-filter for that scheme and
 * nothing outside the app sends one.
 *
 * With Flutter's own deep link handling left on, it reads that URI whenever the
 * extras are gone: already taken by an earlier read, or replayed out of the
 * recents list. go_router gets `critalarm://incidents/inc_demo`, has only
 * `/incidents/:id`, and throws GoException. Reproduced on a handset with
 * `am start -n app.critalarm/.MainActivity -d critalarm://incidents/inc_demo`.
 */
class NotificationTapRouteTest {
    private val manifest = File("src/main/AndroidManifest.xml")
    private val activity = File("src/main/kotlin/app/critalarm/MainActivity.kt")

    @Test
    fun `the manifest is where this test thinks it is`() {
        assertTrue("expected ${manifest.absolutePath}", manifest.isFile)
        assertTrue("expected ${activity.absolutePath}", activity.isFile)
    }

    @Test
    fun `Flutter deep link handling is off`() {
        val text = manifest.readText().replace(Regex("\\s+"), " ")
        assertTrue(
            "AndroidManifest must set flutter_deeplinking_enabled",
            text.contains("android:name=\"flutter_deeplinking_enabled\""),
        )
        val value = Regex(
            "android:name=\"flutter_deeplinking_enabled\" android:value=\"([^\"]+)\"",
        ).find(text)?.groupValues?.get(1)
        assertEquals("flutter_deeplinking_enabled must be false", "false", value)
    }

    @Test
    fun `nothing declares an intent filter for the critalarm scheme`() {
        // The day one is added, the URI becomes a real deep link and go_router
        // needs a route that matches it. Until then it is an id, not an address.
        val text = manifest.readText()
        assertTrue(
            "an intent-filter for critalarm:// needs a matching go_router route",
            !text.contains("android:scheme=\"critalarm\""),
        )
    }

    @Test
    fun `MainActivity hands go_router a path and never a URI`() {
        val text = activity.readText()
        val returns = Regex("return \"([^\"]*)\\$\\{?").findAll(text)
            .map { it.groupValues[1] }
            .toList()
        assertTrue("MainActivity must build at least one route", returns.isNotEmpty())
        val bad = returns.filterNot { it.startsWith("/") }
        assertEquals("routes must be paths, not URIs: $bad", emptyList<String>(), bad)
    }
}
