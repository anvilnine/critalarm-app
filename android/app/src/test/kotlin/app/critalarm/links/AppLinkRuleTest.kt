package app.critalarm.links

import app.critalarm.LaunchTap
import app.critalarm.MainActivity
import app.critalarm.TapRoute
import java.io.File
import java.net.URI
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AppLinkRuleTest {
    private fun forward(link: String): String? {
        val uri = URI(link)
        return AppLinkRule.linkToForward(uri.scheme, uri.host, uri.port, uri.path, link)
    }

    @Test
    fun `the connect link goes over whole, fragment and all`() {
        val link = "https://critalarm.app/connect#url=https%3A%2F%2Fa.example&token=tk_x"
        assertEquals(link, forward(link))
    }

    @Test
    fun `open links go over whole`() {
        for (link in listOf(
            "https://critalarm.app/open/topics/prod",
            "https://critalarm.app/open/incidents/inc_1",
            "https://critalarm.app/open/settings/reliability",
            "https://critalarm.app/open/anything/else",
            "HTTPS://CritAlarm.app/open/topics/prod",
            "https://critalarm.app:443/open/topics/prod",
        )) {
            assertEquals(link, link, forward(link))
        }
    }

    @Test
    fun `the rest of the site is not the app's`() {
        for (link in listOf(
            "https://critalarm.app/",
            "https://critalarm.app/pricing",
            "https://critalarm.app/open",
            "https://critalarm.app/connect/extra",
            "https://critalarm.app/connected",
            "https://critalarm.app/topics/prod",
        )) {
            assertNull(link, forward(link))
        }
    }

    @Test
    fun `another host, scheme or port is not the app's`() {
        for (link in listOf(
            "http://critalarm.app/open/topics/prod",
            "https://www.critalarm.app/open/topics/prod",
            "https://critalarm.app.evil.example/open/topics/prod",
            "https://example.com/connect",
            "https://critalarm.app:8443/open/topics/prod",
            "critalarm://topics/prod",
        )) {
            assertNull(link, forward(link))
        }
        assertNull(AppLinkRule.linkToForward(null, null, -1, null, ""))
    }

    @Test
    fun `a link tap carries the link and no route of its own`() {
        val link = "https://critalarm.app/open/topics/prod"
        val tap = TapRoute.tapFor(3, null, null, null, link)
        assertEquals(mapOf(MainActivity.KEY_TAP_ID to "3", MainActivity.EXTRA_LINK to link), tap)
        // Dart parses the link. Nothing native turns it into a route.
        assertNull(TapRoute.routeFor(tap))
        val launch = LaunchTap { tap }
        assertEquals(tap, launch.tap)
        assertNull(launch.route)
    }

    @Test
    fun `a notification tap keeps its map and its route`() {
        val tap = TapRoute.tapFor(1, "inc_1", "prod", null, null)
        assertEquals(
            mapOf(
                MainActivity.KEY_TAP_ID to "1",
                MainActivity.EXTRA_INCIDENT_ID to "inc_1",
                MainActivity.EXTRA_TOPIC to "prod",
            ),
            tap,
        )
        assertEquals("/incidents/inc_1", TapRoute.routeFor(tap))
        assertEquals("/", TapRoute.routeFor(TapRoute.tapFor(2, null, null, MainActivity.OPEN_HOME, null)))
    }

    private val manifest = File("src/main/AndroidManifest.xml").readText()

    /** The manifest entry of kind [tag] named [name]. */
    private fun entry(tag: String, name: String): String {
        val start = Regex("<$tag\\b[^>]*android:name=\"$name\"").find(manifest)
            ?: error("no <$tag> named $name")
        val end = manifest.indexOf("</$tag>", start.range.first)
        return manifest.substring(start.range.first, end)
    }

    @Test
    fun `the https filter sits on AppLinkActivity only`() {
        val holders = Regex("android:scheme=\"https\"").findAll(manifest).count()
        assertEquals(1, holders)
        val links = entry("activity", ".links.AppLinkActivity")
        assertTrue(links.contains("android:autoVerify=\"true\""))
        assertTrue(links.contains("android:scheme=\"https\""))
        assertTrue(links.contains("android:host=\"${AppLinkRule.HOST}\""))
        assertTrue(links.contains("android:path=\"${AppLinkRule.CONNECT_PATH}\""))
        assertTrue(links.contains("android:pathPrefix=\"${AppLinkRule.OPEN_PREFIX}\""))
        assertTrue(links.contains("android.intent.category.BROWSABLE"))
        assertTrue(links.contains("android:excludeFromRecents=\"true\""))
        val main = entry("activity", ".MainActivity")
        assertFalse(main.contains("android.intent.action.VIEW"))
        assertFalse(main.contains("<data"))
    }

    @Test
    fun `Flutter's own deep linking stays off`() {
        val main = entry("activity", ".MainActivity")
        val flag = Regex(
            "android:name=\"flutter_deeplinking_enabled\"\\s+android:value=\"(\\w+)\"",
        ).find(main)
        assertEquals("false", flag?.groupValues?.get(1))
        val activity = File("src/main/kotlin/app/critalarm/MainActivity.kt").readText()
        assertTrue(activity.contains("override fun shouldHandleDeeplinking(): Boolean = false"))
    }
}
