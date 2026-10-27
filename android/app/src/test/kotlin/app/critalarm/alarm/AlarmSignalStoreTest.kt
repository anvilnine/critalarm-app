package app.critalarm.alarm

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Reading the rows Dart writes: a JSON list of topic names per switch. */
class AlarmSignalStoreTest {
    @Test
    fun `a missing row is off for every topic`() {
        assertEquals(emptySet<String>(), AlarmSignalStore.parseTopics(null))
        assertEquals(emptySet<String>(), AlarmSignalStore.parseTopics(""))
    }

    @Test
    fun `a list of names is the topics that are on`() {
        assertEquals(setOf("backups", "deploys"), AlarmSignalStore.parseTopics("""["backups","deploys"]"""))
    }

    @Test
    fun `an empty list is off for every topic`() {
        assertEquals(emptySet<String>(), AlarmSignalStore.parseTopics("[]"))
    }

    @Test
    fun `anything that is not a list of names reads as off`() {
        assertEquals(emptySet<String>(), AlarmSignalStore.parseTopics("""{"backups":true}"""))
        assertEquals(emptySet<String>(), AlarmSignalStore.parseTopics("not json"))
        assertEquals(setOf("backups"), AlarmSignalStore.parseTopics("""["backups",7,null,""]"""))
    }

    @Test
    fun `nothing saved means no switch is on`() {
        assertFalse(AlarmSignalStore.Saved().anyOn)
        assertTrue(AlarmSignalStore.Saved(flashTopics = setOf("backups")).anyOn)
        assertTrue(AlarmSignalStore.Saved(vibrationTopics = setOf("backups")).anyOn)
    }
}
