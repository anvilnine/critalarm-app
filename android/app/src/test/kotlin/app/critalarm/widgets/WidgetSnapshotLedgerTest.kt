package app.critalarm.widgets

import java.util.concurrent.atomic.AtomicLong
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class WidgetSnapshotLedgerTest {
    private val written = WidgetFixtures.snapshot()
    private var saved: String? = WidgetSnapshotJson.write(written)
    private val ledger = WidgetSnapshotLedger(
        load = { saved },
        store = { saved = it },
        changes = AtomicLong(),
        lock = Any(),
    )
    private val fetched = written.copy(updatedAt = written.updatedAt + 1_000)

    @Test
    fun `a fetch nothing overtook is stored`() {
        val before = ledger.changes()
        assertFalse(ledger.writeFetched(fetched, before))
        assertEquals(fetched, ledger.read())
    }

    @Test
    fun `a sign out during a fetch stays signed out`() {
        val before = ledger.changes()
        ledger.write(WidgetSnapshot.disconnected(written.updatedAt + 10))
        assertTrue(ledger.writeFetched(fetched, before))
        assertFalse(ledger.read()!!.connected)
        assertTrue(ledger.read()!!.topics.isEmpty())
    }

    @Test
    fun `a Dart write during a fetch wins`() {
        val before = ledger.changes()
        val dart = written.copy(openCount = 7)
        assertTrue(ledger.writeJson(WidgetSnapshotJson.write(dart)))
        assertTrue(ledger.writeFetched(fetched, before))
        assertEquals(7, ledger.read()!!.openCount)
    }

    @Test
    fun `a patch during a fetch wins`() {
        val before = ledger.changes()
        ledger.patch(written.updatedAt + 20) { snapshot, now ->
            WidgetSnapshotPatch.acked(snapshot, "inc_9a8b7c", written.updatedAt + 20, now)
        }
        assertTrue(ledger.writeFetched(fetched, before))
        assertEquals(WidgetSnapshot.ACKED, ledger.read()!!.topics.first { it.name == "prod" }.incident!!.state)
    }

    @Test
    fun `an unreadable Dart write is refused and changes nothing`() {
        val before = ledger.changes()
        assertFalse(ledger.writeJson("{}"))
        assertEquals(before, ledger.changes())
        assertEquals(written, ledger.read())
    }

    @Test
    fun `a patch leaves a locked snapshot alone`() {
        saved = WidgetFixtures.read("widget_snapshot_v1_locked.json")
        val result = ledger.patch(1_759_046_500L) { _, _ ->
            WidgetPatchResult.Changed(WidgetFixtures.snapshot())
        }
        assertEquals(WidgetPatchResult.Unchanged, result)
        assertTrue(WidgetSnapshotJson.parse(saved)!!.locked)
    }
}
