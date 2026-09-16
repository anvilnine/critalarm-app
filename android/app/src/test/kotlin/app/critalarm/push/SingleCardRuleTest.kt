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
}
