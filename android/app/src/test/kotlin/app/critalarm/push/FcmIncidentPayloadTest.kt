package app.critalarm.push

import com.google.gson.JsonParser
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Test

class FcmIncidentPayloadTest {
    @Test
    fun `shared payload vectors parse identically`() {
        val root = JsonParser.parseString(fixture().readText()).asJsonObject
        root.getAsJsonArray("payloads").forEach { element ->
            val vector = element.asJsonObject
            val data = vector.getAsJsonObject("data").entrySet().associate { it.key to it.value.asString }
            val parsed = FcmIncidentPayload.fromData(data)
            assertEquals(vector.get("name").asString, vector.get("valid").asBoolean, parsed != null)
        }
    }

    private fun fixture() = sequenceOf(
        File("test/fixtures/android_delivery_cases.json"),
        File("../../test/fixtures/android_delivery_cases.json"),
    ).first { it.exists() }
}
