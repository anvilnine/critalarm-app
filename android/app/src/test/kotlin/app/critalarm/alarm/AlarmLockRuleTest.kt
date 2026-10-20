package app.critalarm.alarm

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AlarmLockRuleTest {
    @Test
    fun anAlarmThatOwesAnAckShowsOverTheLockScreen() {
        assertTrue(AlarmLockRule.showsFor("inc_a", owesAck = true))
    }

    @Test
    fun aStartNamingAnIncidentThatDoesNotRingIsRefused() {
        // Any app can start MainActivity with this extra.
        assertFalse(AlarmLockRule.showsFor("inc_made_up", owesAck = false))
        assertFalse(AlarmLockRule.showsFor("", owesAck = true))
        assertFalse(AlarmLockRule.showsFor(null, owesAck = true))
    }

    @Test
    fun acknowledgingTheOnlyAlarmLetsGo() {
        // Dart can get there before the service has stopped.
        assertFalse(
            AlarmLockRule.keepsOnRelease(
                released = "inc_a",
                shownFor = "inc_a",
                ringingNow = "inc_a",
                shownForOwesAck = true,
            ),
        )
        assertFalse(
            AlarmLockRule.keepsOnRelease(
                released = "inc_a",
                shownFor = "inc_a",
                ringingNow = null,
                shownForOwesAck = false,
            ),
        )
    }

    @Test
    fun leavingASilencedAlarmLetsGo() {
        // Back on the ringing screen silences and leaves. The incident still
        // owes an ack, but nobody is on its screen any more.
        assertFalse(
            AlarmLockRule.keepsOnRelease(
                released = "inc_a",
                shownFor = "inc_a",
                ringingNow = null,
                shownForOwesAck = true,
            ),
        )
    }

    @Test
    fun anotherAlarmStillRingingKeepsTheWindow() {
        assertTrue(
            AlarmLockRule.keepsOnRelease(
                released = "inc_b",
                shownFor = "inc_b",
                ringingNow = "inc_a",
                shownForOwesAck = false,
            ),
        )
    }

    @Test
    fun theOldScreenClosingAfterANewAlarmTookTheWindowKeepsIt() {
        assertTrue(
            AlarmLockRule.keepsOnRelease(
                released = "inc_a",
                shownFor = "inc_b",
                ringingNow = null,
                shownForOwesAck = true,
            ),
        )
        // The newer one was answered too: nothing is left to show.
        assertFalse(
            AlarmLockRule.keepsOnRelease(
                released = "inc_a",
                shownFor = "inc_b",
                ringingNow = null,
                shownForOwesAck = false,
            ),
        )
    }

    @Test
    fun anAlarmAnsweredFromTheNotificationLetsGoOnTheNextCheck() {
        assertFalse(AlarmLockRule.keepsOnCheck(ringingNow = null, shownForOwesAck = false))
        assertTrue(AlarmLockRule.keepsOnCheck(ringingNow = "inc_a", shownForOwesAck = false))
        assertTrue(AlarmLockRule.keepsOnCheck(ringingNow = null, shownForOwesAck = true))
    }
}
