package app.critalarm.actions

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ActionResponseRuleTest {
    @Test
    fun `a close the server took ends the incident`() {
        assertTrue(ActionResponseRule.endsTheIncident(200))
        assertTrue(ActionResponseRule.endsTheIncident(204))
        assertTrue(ActionResponseRule.isSettled(200))
    }

    @Test
    fun `no such incident also ends it`() {
        // The demo card's Done button 404s every time. Ending only on a 2xx
        // left an ongoing card up that could not be swiped away either.
        assertTrue(ActionResponseRule.endsTheIncident(404))
        assertTrue(ActionResponseRule.endsTheIncident(410))
    }

    @Test
    fun `no such incident is nothing to retry`() {
        assertTrue(ActionResponseRule.isSettled(404))
        assertTrue(ActionResponseRule.isSettled(410))
    }

    @Test
    fun `a conflict is settled but says nothing about the card`() {
        assertTrue(ActionResponseRule.isSettled(409))
        assertFalse(ActionResponseRule.endsTheIncident(409))
    }

    @Test
    fun `a server fault or a bad token is retried and changes nothing`() {
        for (status in listOf(401, 403, 429, 500, 502, 503)) {
            assertFalse("status $status", ActionResponseRule.isSettled(status))
            assertFalse("status $status", ActionResponseRule.endsTheIncident(status))
        }
    }
}
