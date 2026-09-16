package app.critalarm.push

import app.critalarm.push.LateContentRule.Destination
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * The guards on a fetch that answers after the user has moved on.
 *
 * Both failures were real: a Stop at 2s followed by an alarm-card post at 8s,
 * and a Done at 2s followed by a status-card post at 12s that left an ongoing
 * card whose button answered 409 forever.
 */
class LateContentRuleTest {
    @Test
    fun `a ringing incident still gets the alarm card`() {
        assertEquals(
            Destination.ALARM_CARD,
            LateContentRule.destinationFor(acknowledged = false, closed = false),
        )
    }

    @Test
    fun `an acked incident gets the status card, never the alarm card back`() {
        assertEquals(
            Destination.STATUS_CARD,
            LateContentRule.destinationFor(acknowledged = true, closed = false),
        )
    }

    @Test
    fun `a closed incident gets nothing`() {
        assertEquals(
            Destination.NOWHERE,
            LateContentRule.destinationFor(acknowledged = true, closed = true),
        )
    }

    @Test
    fun `closed wins even when the ack flag never landed`() {
        assertEquals(
            Destination.NOWHERE,
            LateContentRule.destinationFor(acknowledged = false, closed = true),
        )
    }
}
