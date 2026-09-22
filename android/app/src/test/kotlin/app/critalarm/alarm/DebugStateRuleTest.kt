package app.critalarm.alarm

import org.junit.Assert.assertEquals
import org.junit.Test

class DebugStateRuleTest {
    private val now = 1_757_462_400_000L

    @Test
    fun `derives every documented phone state`() {
        val cases = listOf(
            DebugStateRule.Input(live = true) to "ringing",
            DebugStateRule.Input(closed = true) to "closed",
            DebugStateRule.Input(acknowledged = true, inLocalAckedSet = true) to "acked here",
            DebugStateRule.Input(acknowledged = true, inLocalAckedSet = false) to "acked elsewhere",
            DebugStateRule.Input(active = true, rearmPending = true) to "silenced",
            DebugStateRule.Input(ringUntilMillis = now - 1) to "expired",
            DebugStateRule.Input() to "unknown",
        )

        for ((input, expected) in cases) {
            assertEquals(expected, DebugStateRule.phoneState(input, now))
        }
    }

    @Test
    fun `earlier state rows win over later rows`() {
        assertEquals(
            "ringing",
            DebugStateRule.phoneState(
                DebugStateRule.Input(
                    live = true,
                    closed = true,
                    acknowledged = true,
                    inLocalAckedSet = true,
                    active = true,
                    rearmPending = true,
                    ringUntilMillis = now - 1,
                ),
                now,
            ),
        )
    }
}
