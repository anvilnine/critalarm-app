package app.critalarm.actions

import com.google.gson.JsonParser
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Test

class IncidentActionRouterTest {
    @Test
    fun `shared action vectors route identically`() {
        val root = JsonParser.parseString(fixture().readText()).asJsonObject
        root.getAsJsonArray("actions").forEach { element ->
            val vector = element.asJsonObject
            val route = IncidentActionRouter.fromTrigger(
                vector.get("trigger").asString,
                vector.get("incident_id").asString,
            )
            val expectedAction = vector.get("action").takeUnless { it.isJsonNull }?.asString
            val expectedPath = vector.get("path").takeUnless { it.isJsonNull }?.asString
            assertEquals(vector.get("name").asString, expectedAction, route?.action?.wireValue)
            assertEquals(vector.get("name").asString, expectedPath, route?.path)
        }
    }

    private fun fixture() = sequenceOf(
        File("test/fixtures/android_delivery_cases.json"),
        File("../../test/fixtures/android_delivery_cases.json"),
    ).first { it.exists() }
}
