package app.critalarm.widgets

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The three widgets exist only as far as the manifest says so. Read as text,
 * the NotificationTapRouteTest way.
 */
class WidgetManifestTest {
    private val manifest = File("src/main/AndroidManifest.xml").readText().replace(Regex("\\s+"), " ")
    private val res = File("src/main/res")

    private fun block(tag: String, name: String): String {
        val start = manifest.indexOf("<$tag android:name=\"$name\"")
        assertTrue("expected a <$tag> for $name", start >= 0)
        val end = manifest.indexOf("</$tag>", start)
        assertTrue("expected </$tag> after $name", end > start)
        return manifest.substring(start, end)
    }

    private val providers = mapOf(
        ".widgets.TopicListWidgetProvider" to "widget_topic_list_info",
        ".widgets.TopicWidgetProvider" to "widget_topic_info",
        ".widgets.OpenCountWidgetProvider" to "widget_open_count_info",
    )

    @Test
    fun `each provider is an exported receiver with the update filter and its info`() {
        for ((name, info) in providers) {
            val receiver = block("receiver", name)
            assertTrue("$name must be exported", receiver.contains("android:exported=\"true\""))
            assertTrue(
                "$name needs APPWIDGET_UPDATE",
                receiver.contains("android.appwidget.action.APPWIDGET_UPDATE"),
            )
            assertTrue(
                "$name needs the provider meta-data",
                receiver.contains("android:name=\"android.appwidget.provider\" android:resource=\"@xml/$info\""),
            )
            assertTrue("missing res/xml/$info.xml", File(res, "xml/$info.xml").isFile)
        }
    }

    @Test
    fun `the topic picker answers APPWIDGET_CONFIGURE`() {
        val activity = block("activity", ".widgets.TopicWidgetConfigActivity")
        assertTrue(activity.contains("android:exported=\"true\""))
        assertTrue(activity.contains("android.appwidget.action.APPWIDGET_CONFIGURE"))
        val info = File(res, "xml/widget_topic_info.xml").readText()
        assertTrue(info.contains("android:configure=\"app.critalarm.widgets.TopicWidgetConfigActivity\""))
        assertTrue(info.contains("android:widgetFeatures=\"reconfigurable\""))
    }

    @Test
    fun `the count widget is offered for the lock screen too`() {
        val info = File(res, "xml/widget_open_count_info.xml").readText()
        assertTrue(info.contains("android:widgetCategory=\"home_screen|keyguard\""))
    }

    @Test
    fun `every widget refreshes on the 30 minute period`() {
        for (info in providers.values) {
            val text = File(res, "xml/$info.xml").readText()
            val period = Regex("android:updatePeriodMillis=\"(\\d+)\"").find(text)?.groupValues?.get(1)
            assertEquals("$info period", "1800000", period)
        }
    }

    @Test
    fun `widget layouts use only views RemoteViews takes on API 28`() {
        val allowed = setOf("LinearLayout", "FrameLayout", "TextView", "ImageView", "Button", "Chronometer", "include")
        val layouts = listOf("widget_topic_list", "widget_topic_row", "widget_topic", "widget_open_count")
        for (layout in layouts) {
            val text = File(res, "layout/$layout.xml").readText()
            val tags = Regex("<([A-Za-z.]+)[\\s>]").findAll(text).map { it.groupValues[1] }.toSet()
            assertEquals("$layout uses $tags", emptySet<String>(), tags - allowed)
        }
    }
}
