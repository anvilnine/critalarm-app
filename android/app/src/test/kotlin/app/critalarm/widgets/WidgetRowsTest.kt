package app.critalarm.widgets

import app.critalarm.notifications.CritAlarmFace
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class WidgetRowsTest {
    private val snapshot = WidgetFixtures.snapshot()
    private val open = snapshot.topics[0].incident!!
    private val acked = snapshot.topics[1].incident!!

    private fun manyTopics(n: Int) = snapshot.copy(
        topics = (1..n).map { WidgetTopic("t$it", critical = false, count = 0, incident = null) },
    )

    @Test
    fun `rows that fit follow the height`() {
        assertEquals(1, WidgetRows.rowsThatFit(110))
        assertEquals(3, WidgetRows.rowsThatFit(180))
        assertEquals(4, WidgetRows.rowsThatFit(250))
        assertEquals(8, WidgetRows.rowsThatFit(400))
    }

    @Test
    fun `rows that fit stay between 1 and 8`() {
        assertEquals(1, WidgetRows.rowsThatFit(0))
        assertEquals(8, WidgetRows.rowsThatFit(2_000))
    }

    @Test
    fun `more is what the limit leaves out`() {
        assertEquals(WidgetRows.Rows(snapshot.topics.take(1), 2), WidgetRows.rows(snapshot, 1))
        assertEquals(WidgetRows.Rows(snapshot.topics, 0), WidgetRows.rows(snapshot, 3))
        assertEquals(WidgetRows.Rows(snapshot.topics, 0), WidgetRows.rows(snapshot, 7))
        assertEquals(WidgetRows.Rows(emptyList(), 3), WidgetRows.rows(snapshot, 0))
        assertEquals(WidgetRows.Rows(emptyList(), 3), WidgetRows.rows(snapshot, -1))
    }

    @Test
    fun `a full list gives its last slot to the more line`() {
        val list = WidgetRows.listRows(manyTopics(10), 250)
        assertEquals(3, list.rows.size)
        assertEquals(7, list.more)
        assertEquals("+7 more", WidgetRows.moreText(list.more))
    }

    @Test
    fun `a list that fits shows every row`() {
        val list = WidgetRows.listRows(manyTopics(4), 250)
        assertEquals(4, list.rows.size)
        assertEquals(0, list.more)
    }

    @Test
    fun `the smallest list keeps one row`() {
        val list = WidgetRows.listRows(manyTopics(5), 110)
        assertEquals(1, list.rows.size)
        assertEquals(4, list.more)
    }

    @Test
    fun `state words match iOS`() {
        assertEquals("Ringing", WidgetRows.stateWord(open))
        assertEquals("Awake", WidgetRows.stateWord(acked))
        assertEquals("Quiet", WidgetRows.stateWord(null))
    }

    @Test
    fun `button titles match iOS`() {
        assertEquals("I'm up", WidgetRows.buttonTitle(open))
        assertEquals("Done", WidgetRows.buttonTitle(acked))
        assertNull(WidgetRows.buttonTitle(null))
    }

    @Test
    fun `count text`() {
        assertEquals("3 open", WidgetRows.countText(3))
        assertEquals("All quiet", WidgetRows.countText(0))
    }

    @Test
    fun `faces follow the state`() {
        assertEquals(CritAlarmFace.ALARMED, WidgetRows.face(open))
        assertEquals(CritAlarmFace.ACKED, WidgetRows.face(acked))
        assertEquals(CritAlarmFace.CALM, WidgetRows.face(null))
        assertEquals(CritAlarmFace.ALARMED, WidgetRows.worstFace(snapshot))
        assertEquals(CritAlarmFace.ACKED, WidgetRows.worstFace(snapshot.copy(topics = snapshot.topics.drop(1))))
        assertEquals(CritAlarmFace.CALM, WidgetRows.worstFace(WidgetSnapshot.disconnected(0L)))
    }

    @Test
    fun `since reads the ack for an acked incident and the open otherwise`() {
        assertEquals(1759046100L, WidgetRows.sinceSeconds(open))
        assertEquals(1759042920L, WidgetRows.sinceSeconds(acked))
        assertEquals(1759042800L, WidgetRows.sinceSeconds(acked.copy(ackedAt = null)))
        assertNull(WidgetRows.sinceSeconds(open.copy(openedAt = 0L)))
        assertNull(WidgetRows.sinceSeconds(null))
    }
}
