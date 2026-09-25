package app.critalarm.widgets

import java.io.File
import org.json.JSONObject

/**
 * The shared fixtures in the repo's `test/fixtures`, read from either working
 * directory Gradle may use, the same way FcmIncidentPayloadTest does.
 */
object WidgetFixtures {
    fun read(name: String): String = sequenceOf(
        File("test/fixtures/$name"),
        File("../../test/fixtures/$name"),
    ).first { it.isFile }.readText()

    /** `test/fixtures/widget_snapshot_v1.json`, parsed. */
    fun snapshot(): WidgetSnapshot = WidgetSnapshotJson.parse(read("widget_snapshot_v1.json"))!!

    /** `test/fixtures/widget_server_v1.json`, the three server answers and the clock. */
    fun server(): JSONObject = JSONObject(read("widget_server_v1.json"))
}
