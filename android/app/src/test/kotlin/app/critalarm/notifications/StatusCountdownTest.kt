package app.critalarm.notifications

import app.critalarm.storage.TopicTimers
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Which cards get a countdown, how long it is, and where it counts to. */
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

    /**
     * The card counts down with a chronometer, never with a bar.
     *
     * Android advances a chronometer itself, once a second, from the instant in
     * setWhen. ProgressStyle is painted once when the notification is built, so
     * a bar sat frozen at whatever it was worth when the card went up and only
     * moved when something re-posted the card. Ten to twenty re-posts per
     * incident buys a bar that a free-running timer already gives.
     */
    @Test
    fun `the card counts down with a chronometer and not with a bar`() {
        val text = File(
            "src/main/kotlin/app/critalarm/notifications/StatusNotificationFactory.kt",
        ).readText()
        assertTrue("the card must set a chronometer", text.contains("setUsesChronometer(true)"))
        assertTrue(
            "the card must be able to count down",
            text.contains("setChronometerCountDown(true)"),
        )
        assertFalse("ProgressStyle does not advance on its own", text.contains("ProgressStyle()"))
    }
}
