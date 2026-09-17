package app.critalarm.push

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * `POST /v1/incidents/{id}/ack` answers the incident plus
 * `desk_timer_fires_at` (api.md §3.2). Reading it is what stops the bar
 * counting a fresh full timer after a 409, where another device acked minutes
 * ago and the reopen is already close.
 */
class DeskTimerFiresAtTest {
    @Test
    fun `unix seconds become milliseconds`() {
        assertEquals(
            1_757_740_800_000L,
            IncidentContentFetcher.parseDeskTimerFiresAt(
                """{"id":"inc_1","state":"acked","desk_timer_fires_at":1757740800}""",
            ),
        )
    }

    @Test
    fun `unix milliseconds are left alone`() {
        assertEquals(
            1_757_740_800_123L,
            IncidentContentFetcher.parseDeskTimerFiresAt(
                """{"id":"inc_1","desk_timer_fires_at":1757740800123}""",
            ),
        )
    }

    @Test
    fun `an iso string parses`() {
        assertEquals(
            1_757_740_800_000L,
            IncidentContentFetcher.parseDeskTimerFiresAt(
                """{"id":"inc_1","desk_timer_fires_at":"2025-09-13T05:20:00Z"}""",
            ),
        )
    }

    @Test
    fun `a 409 body carries no field, so there is nothing to read`() {
        assertNull(
            IncidentContentFetcher.parseDeskTimerFiresAt("""{"error":"invalid state"}"""),
        )
    }

    @Test
    fun `null, junk and a broken body all read as no answer`() {
        assertNull(IncidentContentFetcher.parseDeskTimerFiresAt("""{"desk_timer_fires_at":null}"""))
        assertNull(IncidentContentFetcher.parseDeskTimerFiresAt("""{"desk_timer_fires_at":"soon"}"""))
        assertNull(IncidentContentFetcher.parseDeskTimerFiresAt("""{"desk_timer_fires_at":0}"""))
        assertNull(IncidentContentFetcher.parseDeskTimerFiresAt("not json"))
    }
}
