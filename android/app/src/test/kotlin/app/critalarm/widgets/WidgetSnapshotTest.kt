package app.critalarm.widgets

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import com.google.gson.JsonParser
import org.junit.Test

class WidgetSnapshotTest {
    @Test
    fun `the fixture parses`() {
        val snapshot = WidgetFixtures.snapshot()
        assertEquals(1759046400L, snapshot.updatedAt)
        assertEquals(true, snapshot.connected)
        assertEquals(3, snapshot.openCount)
        assertEquals(listOf("prod", "backups", "staging"), snapshot.topics.map { it.name })
        val prod = snapshot.topics[0]
        assertEquals(true, prod.critical)
        assertEquals(2, prod.count)
        assertEquals(WidgetIncident("inc_9a8b7c", "open", "Database down", 1759046100L, null), prod.incident)
        assertEquals(1759042920L, snapshot.topics[1].incident?.ackedAt)
        assertNull(snapshot.topics[2].incident)
    }

    @Test
    fun `writing and reading gives the same snapshot`() {
        val snapshot = WidgetFixtures.snapshot()
        assertEquals(snapshot, WidgetSnapshotJson.parse(WidgetSnapshotJson.write(snapshot)))
    }

    @Test
    fun `what is written matches the fixture key for key`() {
        val written = JsonParser.parseString(WidgetSnapshotJson.write(WidgetFixtures.snapshot()))
        val fixture = JsonParser.parseString(WidgetFixtures.read("widget_snapshot_v1.json"))
        assertEquals(fixture, written)
    }

    @Test
    fun `another version reads as missing`() {
        val json = WidgetFixtures.read("widget_snapshot_v1.json").replace("\"v\": 1", "\"v\": 2")
        assertNull(WidgetSnapshotJson.parse(json))
    }

    @Test
    fun `garbage reads as missing`() {
        assertNull(WidgetSnapshotJson.parse(null))
        assertNull(WidgetSnapshotJson.parse(""))
        assertNull(WidgetSnapshotJson.parse("not json"))
        assertNull(WidgetSnapshotJson.parse("{\"v\":1}"))
    }

    @Test
    fun `the disconnected shape`() {
        assertEquals(
            JsonParser.parseString("""{"v":1,"updated_at":1759046400,"connected":false,"open_count":0,"topics":[]}"""),
            JsonParser.parseString(WidgetSnapshotJson.write(WidgetSnapshot.disconnected(1759046400L))),
        )
    }
}
