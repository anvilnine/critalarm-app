package app.critalarm.notifications

import app.critalarm.storage.TopicTimers
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** Which cards get the bar, how long it is, and where it counts to. */
class StatusCountdownTest {
    private val start = 1_757_740_800_000L
    private val timers = TopicTimers(repeatIntervalS = 30, maxRingS = 1800, deskTimerS = 600)

    @Test
    fun `an unacked card counts the repeat interval`() {
        val countdown = StatusNotificationFactory.countdownFor(
            state = IncidentCardState.OPEN,
            timers = timers,
            startMillis = start,
            deskTimerEndMillis = null,
        )
        assertEquals(StatusNotificationFactory.Countdown(start, start + 30_000L), countdown)
    }

    @Test
    fun `an acked card counts the desk timer`() {
        val countdown = StatusNotificationFactory.countdownFor(
            state = IncidentCardState.ACKED,
            timers = timers,
            startMillis = start,
            deskTimerEndMillis = null,
        )
        assertEquals(StatusNotificationFactory.Countdown(start, start + 600_000L), countdown)
    }

    @Test
    fun `the instant the ack response carried beats the cached duration`() {
        val firesAt = start + 120_000L
        val countdown = StatusNotificationFactory.countdownFor(
            state = IncidentCardState.ACKED,
            timers = timers,
            startMillis = start,
            deskTimerEndMillis = firesAt,
        )
        assertEquals(StatusNotificationFactory.Countdown(start, firesAt), countdown)
    }

    @Test
    fun `an instant already past falls back to the cached duration`() {
        val countdown = StatusNotificationFactory.countdownFor(
            state = IncidentCardState.ACKED,
            timers = timers,
            startMillis = start,
            deskTimerEndMillis = start - 1_000L,
        )
        assertEquals(StatusNotificationFactory.Countdown(start, start + 600_000L), countdown)
    }

    @Test
    fun `closed and expired have no bar`() {
        assertNull(
            StatusNotificationFactory.countdownFor(
                state = IncidentCardState.CLOSED,
                timers = timers,
                startMillis = start,
                deskTimerEndMillis = start + 600_000L,
            ),
        )
        assertNull(
            StatusNotificationFactory.countdownFor(
                state = IncidentCardState.EXPIRED,
                timers = timers,
                startMillis = start,
                deskTimerEndMillis = start + 600_000L,
            ),
        )
    }

    @Test
    fun `no cached timers and no instant means no bar`() {
        assertNull(
            StatusNotificationFactory.countdownFor(
                state = IncidentCardState.OPEN,
                timers = null,
                startMillis = start,
                deskTimerEndMillis = null,
            ),
        )
        assertNull(
            StatusNotificationFactory.countdownFor(
                state = IncidentCardState.ACKED,
                timers = null,
                startMillis = start,
                deskTimerEndMillis = null,
            ),
        )
    }

    @Test
    fun `an acked card with no cached timers still counts the instant it was given`() {
        val firesAt = start + 300_000L
        assertEquals(
            StatusNotificationFactory.Countdown(start, firesAt),
            StatusNotificationFactory.countdownFor(
                state = IncidentCardState.ACKED,
                timers = null,
                startMillis = start,
                deskTimerEndMillis = firesAt,
            ),
        )
    }

    @Test
    fun `an unacked card ignores the desk timer instant`() {
        assertNull(
            StatusNotificationFactory.countdownFor(
                state = IncidentCardState.OPEN,
                timers = null,
                startMillis = start,
                deskTimerEndMillis = start + 600_000L,
            ),
        )
    }
}
