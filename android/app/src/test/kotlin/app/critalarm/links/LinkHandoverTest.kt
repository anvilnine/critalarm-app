package app.critalarm.links

import app.critalarm.MainActivity
import app.critalarm.TapRoute
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class LinkHandoverTest {
    private val connect = "https://critalarm.app/connect#url=https%3A%2F%2Fa.example&token=tk_x"
    private val topic = "https://critalarm.app/open/topics/prod"

    /** What MainActivity makes of the link extra it found. */
    private fun tapWith(extra: String?, incidentId: String? = null, topicName: String? = null) =
        TapRoute.tapFor(1, incidentId, topicName, null, LinkHandover.take(extra))

    @Before
    fun `nothing is held`() {
        LinkHandover.take(LinkHandover.hold(topic))
    }

    @Test
    fun `a link AppLinkActivity held reaches the tap`() {
        val extra = LinkHandover.hold(connect)
        assertEquals(
            mapOf(MainActivity.KEY_TAP_ID to "1", MainActivity.EXTRA_LINK to connect),
            tapWith(extra),
        )
    }

    @Test
    fun `it is handed over once`() {
        val extra = LinkHandover.hold(topic)
        assertEquals(topic, LinkHandover.take(extra))
        assertNull(LinkHandover.take(extra))
    }

    @Test
    fun `the intent does not carry the link`() {
        val extra = LinkHandover.hold(connect)
        assertNotEquals(connect, extra)
        assertFalse(extra.contains("tk_x"))
        assertFalse(extra.contains("a.example"))
        assertNotEquals(extra, LinkHandover.hold(connect))
    }

    @Test
    fun `a link extra nothing held is dropped`() {
        for (extra in listOf(
            connect,
            topic,
            "critalarm://connect?url=https://example.com&token=x",
            "critalarm://topics/new",
            "",
        )) {
            assertNull(extra, LinkHandover.take(extra))
            assertNull(extra, tapWith(extra)[MainActivity.EXTRA_LINK])
        }
        assertNull(LinkHandover.take(null))
    }

    @Test
    fun `a dropped extra leaves a held link where it was`() {
        val extra = LinkHandover.hold(topic)
        assertNull(LinkHandover.take(topic))
        assertNull(LinkHandover.take("critalarm://connect?url=https://example.com&token=x"))
        assertEquals(topic, LinkHandover.take(extra))
    }

    @Test
    fun `a newer link replaces one nobody collected`() {
        val first = LinkHandover.hold(connect)
        val second = LinkHandover.hold(topic)
        assertNull(LinkHandover.take(first))
        assertEquals(topic, LinkHandover.take(second))
    }

    @Test
    fun `a notification tap routes as before`() {
        val tap = tapWith(null, incidentId = "inc_1", topicName = "prod")
        assertEquals(
            mapOf(
                MainActivity.KEY_TAP_ID to "1",
                MainActivity.EXTRA_INCIDENT_ID to "inc_1",
                MainActivity.EXTRA_TOPIC to "prod",
            ),
            tap,
        )
        assertEquals("/incidents/inc_1", TapRoute.routeFor(tap))
        assertEquals("/topics/prod", TapRoute.routeFor(tapWith(null, topicName = "prod")))
    }

    @Test
    fun `a tap with a link extra nothing held keeps its route and gets no link`() {
        val tap = tapWith(connect, incidentId = "inc_1")
        assertEquals(
            mapOf(MainActivity.KEY_TAP_ID to "1", MainActivity.EXTRA_INCIDENT_ID to "inc_1"),
            tap,
        )
        assertEquals("/incidents/inc_1", TapRoute.routeFor(tap))
    }

    @Test
    fun `a Done tap keeps its marker and gets no link from an extra nothing held`() {
        val tap = TapRoute.tapFor(1, "inc_1", null, null, LinkHandover.take(connect), MainActivity.FROM_DONE)
        assertEquals(
            mapOf(
                MainActivity.KEY_TAP_ID to "1",
                MainActivity.EXTRA_INCIDENT_ID to "inc_1",
                MainActivity.EXTRA_FROM to MainActivity.FROM_DONE,
            ),
            tap,
        )
        assertEquals("/incidents/inc_1?from=done", TapRoute.routeFor(tap))
    }

    private val manifest = File("src/main/AndroidManifest.xml").readText()
    private val mainActivity = File("src/main/kotlin/app/critalarm/MainActivity.kt").readText()
    private val linkActivity = File("src/main/kotlin/app/critalarm/links/AppLinkActivity.kt").readText()

    @Test
    fun `MainActivity takes the link extra off every intent and reads it through the hand-over`() {
        val readTap = mainActivity.substring(
            mainActivity.indexOf("private fun readTap("),
            mainActivity.indexOf("companion object"),
        )
        assertEquals(1, Regex("getStringExtra\\(EXTRA_LINK\\)").findAll(mainActivity).count())
        assertTrue(readTap.contains("LinkHandover.take("))
        val removed = readTap.indexOf("intent.removeExtra(EXTRA_LINK)")
        val nothingToRoute = readTap.indexOf("link == null) return null")
        assertTrue(removed >= 0 && nothingToRoute >= 0)
        assertTrue("the extra comes off before the early return", removed < nothingToRoute)
    }

    @Test
    fun `AppLinkActivity puts only what the hand-over gives it on the intent`() {
        assertTrue(linkActivity.contains("putExtra(MainActivity.EXTRA_LINK, LinkHandover.hold(link))"))
        assertEquals(1, Regex("putExtra\\(").findAll(linkActivity).count())
    }

    /** The held link lives in memory, so both ends have to share a process. */
    @Test
    fun `no component runs in a process of its own`() {
        assertFalse(manifest.contains("android:process"))
    }
}
