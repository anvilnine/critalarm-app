package app.critalarm.widgets

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class WidgetSnapshotBuilderTest {
    @Test
    fun `the server sample builds exactly the fixture`() {
        val server = WidgetFixtures.server()
        val built = WidgetSnapshotBuilder.fromServer(
            server.getJSONArray("topics").toString(),
            server.getJSONArray("open").toString(),
            server.getJSONArray("acked").toString(),
            server.getLong("now"),
        )
        assertEquals(WidgetFixtures.snapshot(), built)
    }

    @Test
    fun `unreadable answers give nothing`() {
        assertNull(WidgetSnapshotBuilder.fromServer("nope", "[]", "[]", 1L))
        assertNull(WidgetSnapshotBuilder.fromServer("[]", "{}", "[]", 1L))
        assertNull(WidgetSnapshotBuilder.fromServer("[]", "[]", "", 1L))
    }

    @Test
    fun `no topics is connected and empty`() {
        val built = WidgetSnapshotBuilder.fromServer("[]", "[]", "[]", 5L)
        assertEquals(WidgetSnapshot(5L, connected = true, openCount = 0, topics = emptyList()), built)
    }

    @Test
    fun `times may be seconds, milliseconds or ISO`() {
        assertEquals(1759046100L, WidgetSnapshotBuilder.seconds(1759046100))
        assertEquals(1759046100L, WidgetSnapshotBuilder.seconds(1759046100999L))
        assertEquals(1759046100L, WidgetSnapshotBuilder.seconds("1759046100"))
        assertEquals(1759046100L, WidgetSnapshotBuilder.seconds("2025-09-28T07:55:00Z"))
        assertNull(WidgetSnapshotBuilder.seconds(null))
        assertNull(WidgetSnapshotBuilder.seconds("soon"))
    }
}
