package app.critalarm.push

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class StateKindRuleTest {
    private fun push(kind: String, withPriority: Boolean = false) = FcmIncidentPayload.fromData(
        buildMap {
            put("incident_id", "inc_9a8b7c")
            put("server", "https://alerts.example.com")
            put("kind", kind)
            if (withPriority) put("priority", "5")
        },
    )

    @Test
    fun `ack close and expire parse with no priority`() {
        for (kind in listOf("ack", "close", "expire")) {
            val parsed = push(kind)
            assertEquals(kind, kind, parsed?.kind?.wireValue)
            assertTrue(kind, parsed!!.kind.isStateChange)
        }
    }

    @Test
    fun `a state push is never an incident, so nothing rings`() {
        for (kind in listOf("ack", "close", "expire")) {
            val parsed = push(kind)!!
            assertFalse(kind, parsed.isIncident)
            assertFalse(kind, StateKindRule.rings(parsed.kind))
        }
    }

    @Test
    fun `a state push with no incident id is dropped`() {
        val parsed = FcmIncidentPayload.fromData(
            mapOf("server" to "https://alerts.example.com", "kind" to "ack"),
        )
        assertNull(parsed)
    }

    @Test
    fun `ack hands the card to the acked state`() {
        assertEquals(StateKindRule.Card.ACKED, StateKindRule.cardFor(IncidentPushKind.ACK))
        assertTrue(StateKindRule.marksAcknowledgedOnly(IncidentPushKind.ACK))
    }

    @Test
    fun `close and expire take the card down`() {
        for (kind in listOf(IncidentPushKind.CLOSE, IncidentPushKind.EXPIRE)) {
            assertEquals(kind.wireValue, StateKindRule.Card.NONE, StateKindRule.cardFor(kind))
            assertFalse(kind.wireValue, StateKindRule.marksAcknowledgedOnly(kind))
        }
    }

    @Test
    fun `a ringing kind is not a state change`() {
        for (kind in listOf(IncidentPushKind.OPEN, IncidentPushKind.REPEAT, IncidentPushKind.REOPEN)) {
            assertFalse(kind.wireValue, StateKindRule.applies(kind))
            assertNull(kind.wireValue, StateKindRule.cardFor(kind))
        }
    }

    @Test
    fun `ring_until arrives as epoch seconds and is kept in millis`() {
        val parsed = FcmIncidentPayload.fromData(
            mapOf(
                "incident_id" to "inc_9a8b7c",
                "server" to "https://alerts.example.com",
                "kind" to "open",
                "priority" to "5",
                "ring_until" to "1757464200",
            ),
        )!!
        assertEquals(1_757_464_200_000L, parsed.ringUntilMillis)
    }

    @Test
    fun `no ring_until reads as absent, never as zero`() {
        assertNull(push("open", withPriority = true)!!.ringUntilMillis)
    }
}
