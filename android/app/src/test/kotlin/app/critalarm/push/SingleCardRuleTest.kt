package app.critalarm.push

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SingleCardRuleTest {
    @Test
    fun `a ringing incident shows the alarm card only`() {
        assertTrue(SingleCardRule.showsAlarmCard(ringing = true))
        assertFalse(SingleCardRule.showsStatusCard(ringing = true))
    }

    @Test
    fun `a stopped incident shows the status card only`() {
        assertFalse(SingleCardRule.showsAlarmCard(ringing = false))
        assertTrue(SingleCardRule.showsStatusCard(ringing = false))
    }

    @Test
    fun `an alarm with no incident behind it leaves no card`() {
        // The onboarding demo. Stop on its notification used to post an acked
        // card for inc_demo: ongoing, so it could not be swiped away, and its
        // Done button POSTed a close for an incident the server never had.
        assertFalse(SingleCardRule.showsStatusCard(ringing = false, handsOver = false))
    }
}
