package app.critalarm.push

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class IncidentContentTest {
    @Test
    fun `newest message supplies the display text`() {
        val content = IncidentContentFetcher.parse(
            """
            {"id":"inc_1","topic":"prod","state":"open","messages":[
              {"id":"m_1","topic":"prod","title":"First","message":"old"},
              {"id":"m_2","topic":"prod","title":"Database down","message":"db01 is down",
               "tags":["warning","db01"],"click":"https://status.example.com"}
            ]}
            """.trimIndent(),
        )!!
        assertEquals("Database down", content.title)
        assertEquals("db01 is down", content.body)
        assertEquals(listOf("warning", "db01"), content.tags)
        assertEquals("https://status.example.com", content.click)
        assertEquals("prod", content.topic)
    }

    @Test
    fun `an incident with no messages has nothing to show`() {
        assertNull(IncidentContentFetcher.parse("""{"id":"inc_1","topic":"prod","messages":[]}"""))
        assertNull(IncidentContentFetcher.parse("not json"))
    }
}
