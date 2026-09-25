package app.critalarm.widgets

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The four patch operations. `ios/RunnerTests/WidgetSnapshotTests.swift` has
 * the same cases under the same names, so the two platforms stay in step.
 *
 * Fixture: prod (open inc_9a8b7c, count 2), backups (acked inc_4d5e6f,
 * count 1), staging (quiet).
 */
class WidgetSnapshotPatchTest {
    private val fixture = WidgetFixtures.snapshot()
    private val now = 1759047000L

    private fun changed(result: WidgetPatchResult): WidgetSnapshot {
        assertTrue("expected Changed, got $result", result is WidgetPatchResult.Changed)
        return (result as WidgetPatchResult.Changed).snapshot
    }

    private fun partial(result: WidgetPatchResult): WidgetSnapshot? {
        assertTrue("expected NeedsFetch, got $result", result is WidgetPatchResult.NeedsFetch)
        return (result as WidgetPatchResult.NeedsFetch).partial
    }

    private fun WidgetSnapshot.topic(name: String) = topics.first { it.name == name }

    // opened

    @Test
    fun `opened on a missing snapshot is unchanged`() {
        assertEquals(
            WidgetPatchResult.Unchanged,
            WidgetSnapshotPatch.opened(null, "inc_new", "staging", "x", now, now),
        )
    }

    @Test
    fun `opened on a signed out snapshot is unchanged`() {
        assertEquals(
            WidgetPatchResult.Unchanged,
            WidgetSnapshotPatch.opened(WidgetSnapshot.disconnected(1L), "inc_new", "staging", "x", now, now),
        )
    }

    @Test
    fun `opened a new id on a quiet topic shows it`() {
        val next = changed(WidgetSnapshotPatch.opened(fixture, "inc_new", "staging", "Queue stuck", now, now))
        assertEquals(WidgetIncident("inc_new", "open", "Queue stuck", now, null), next.topic("staging").incident)
        assertEquals(1, next.topic("staging").count)
        assertEquals(4, next.openCount)
        assertEquals(now, next.updatedAt)
        assertEquals(listOf("prod", "staging", "backups"), next.topics.map { it.name })
    }

    @Test
    fun `opened a known id is unchanged`() {
        assertEquals(
            WidgetPatchResult.Unchanged,
            WidgetSnapshotPatch.opened(fixture, "inc_9a8b7c", "prod", "Database down", now, now),
        )
    }

    @Test
    fun `opened with no topic needs a fetch`() {
        assertNull(partial(WidgetSnapshotPatch.opened(fixture, "inc_new", null, "x", now, now)))
    }

    @Test
    fun `opened on an unknown topic needs a fetch`() {
        assertNull(partial(WidgetSnapshotPatch.opened(fixture, "inc_new", "nope", "x", now, now)))
    }

    @Test
    fun `opened on a topic with unnamed incidents needs a fetch`() {
        assertNull(partial(WidgetSnapshotPatch.opened(fixture, "inc_new", "prod", "x", now, now)))
    }

    @Test
    fun `opened a newer id wins over an acked one`() {
        val next = changed(WidgetSnapshotPatch.opened(fixture, "inc_new", "backups", "x", now, now))
        assertEquals("inc_new", next.topic("backups").incident?.id)
        assertEquals(2, next.topic("backups").count)
        assertEquals(listOf("backups", "prod", "staging"), next.topics.map { it.name })
    }

    @Test
    fun `opened title falls back to the topic and is cut to 120`() {
        val blank = changed(WidgetSnapshotPatch.opened(fixture, "inc_new", "staging", "  ", now, now))
        assertEquals("staging", blank.topic("staging").incident?.title)
        val long = changed(WidgetSnapshotPatch.opened(fixture, "inc_new", "staging", "a".repeat(200), now, now))
        assertEquals(120, long.topic("staging").incident?.title?.length)
    }

    // reopened

    @Test
    fun `reopened an acked id is open again`() {
        val next = changed(WidgetSnapshotPatch.reopened(fixture, "inc_4d5e6f", now))
        assertEquals("open", next.topic("backups").incident?.state)
        assertNull(next.topic("backups").incident?.ackedAt)
        assertEquals(1, next.topic("backups").count)
        assertEquals(3, next.openCount)
        assertEquals(listOf("backups", "prod", "staging"), next.topics.map { it.name })
    }

    @Test
    fun `reopened an open id is unchanged`() {
        assertEquals(WidgetPatchResult.Unchanged, WidgetSnapshotPatch.reopened(fixture, "inc_9a8b7c", now))
    }

    @Test
    fun `reopened an unknown id needs a fetch`() {
        assertNull(partial(WidgetSnapshotPatch.reopened(fixture, "inc_nope", now)))
    }

    @Test
    fun `reopened on a missing snapshot is unchanged`() {
        assertEquals(WidgetPatchResult.Unchanged, WidgetSnapshotPatch.reopened(null, "inc_4d5e6f", now))
    }

    // acked

    @Test
    fun `acked the only incident on a topic changes it`() {
        val opened = changed(WidgetSnapshotPatch.opened(fixture, "inc_new", "staging", "x", now, now))
        val next = changed(WidgetSnapshotPatch.acked(opened, "inc_new", now + 5, now + 10))
        assertEquals(WidgetIncident("inc_new", "acked", "x", now, now + 5), next.topic("staging").incident)
        assertEquals(now + 10, next.updatedAt)
        assertEquals(listOf("prod", "backups", "staging"), next.topics.map { it.name })
    }

    @Test
    fun `acked on a topic with other incidents writes the change and needs a fetch`() {
        val next = partial(WidgetSnapshotPatch.acked(fixture, "inc_9a8b7c", now, now))!!
        assertEquals("acked", next.topic("prod").incident?.state)
        assertEquals(now, next.topic("prod").incident?.ackedAt)
        assertEquals(2, next.topic("prod").count)
    }

    @Test
    fun `acked keeps an acked_at already known`() {
        assertEquals(WidgetPatchResult.Unchanged, WidgetSnapshotPatch.acked(fixture, "inc_4d5e6f", now, now))
    }

    @Test
    fun `acked an unknown id needs a fetch`() {
        assertNull(partial(WidgetSnapshotPatch.acked(fixture, "inc_nope", now, now)))
    }

    @Test
    fun `acked on a missing snapshot is unchanged`() {
        assertEquals(WidgetPatchResult.Unchanged, WidgetSnapshotPatch.acked(null, "inc_9a8b7c", now, now))
    }

    // ended

    @Test
    fun `ended the only incident quiets the topic`() {
        val next = changed(WidgetSnapshotPatch.ended(fixture, "inc_4d5e6f", now))
        assertNull(next.topic("backups").incident)
        assertEquals(0, next.topic("backups").count)
        assertEquals(2, next.openCount)
        assertEquals(listOf("prod", "backups", "staging"), next.topics.map { it.name })
    }

    @Test
    fun `ended with other incidents left writes the change and needs a fetch`() {
        val next = partial(WidgetSnapshotPatch.ended(fixture, "inc_9a8b7c", now))!!
        assertNull(next.topic("prod").incident)
        assertEquals(1, next.topic("prod").count)
        assertEquals(2, next.openCount)
    }

    @Test
    fun `ended an unknown id needs a fetch`() {
        assertNull(partial(WidgetSnapshotPatch.ended(fixture, "inc_nope", now)))
    }

    @Test
    fun `ended on a missing snapshot is unchanged`() {
        assertEquals(WidgetPatchResult.Unchanged, WidgetSnapshotPatch.ended(null, "inc_9a8b7c", now))
    }
}
