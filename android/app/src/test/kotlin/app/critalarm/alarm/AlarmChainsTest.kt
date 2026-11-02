package app.critalarm.alarm

import app.critalarm.push.IncidentPushKind
import app.critalarm.storage.IncidentDeliveryStore
import app.critalarm.storage.InMemoryPreferences
import app.critalarm.storage.TopicTimers
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The chain as the phone holds it: what is set after each push, and that
 * every way out of an incident leaves no slot behind.
 */
class AlarmChainsTest {
    private val now = 1_757_462_400_000L
    private val minute = 60_000L
    private val ringUntil = now + 30 * minute

    private class FakeAlarms : AlarmChains.SlotAlarms {
        val set = mutableMapOf<Pair<String, Int>, Long>()
        var refuse = false
        var setCalls = 0

        override fun set(incidentId: String, slot: Int, atMillis: Long, title: String?, body: String?): Boolean {
            setCalls++
            if (refuse) return false
            set[incidentId to slot] = atMillis
            return true
        }

        override fun cancelSlot(incidentId: String, slot: Int) {
            set.remove(incidentId to slot)
        }

        override fun isSet(incidentId: String, slot: Int) = (incidentId to slot) in set

        fun slotsOf(incidentId: String) = set.filterKeys { it.first == incidentId }.values.sorted()
    }

    private val store = IncidentDeliveryStore(InMemoryPreferences())
    private val alarms = FakeAlarms()
    private val critical = mutableMapOf<String, Boolean>()
    private val timers = mutableMapOf<String, TopicTimers>()
    private var quiet = false
    private val chains = AlarmChains(
        store = store,
        alarms = alarms,
        criticalOn = { topic -> topic == null || critical[topic] ?: true },
        timersFor = { timers[it] },
        quietHoursHold = { quiet },
    )

    /** What a priority-5 push does to the store before it sets the chain. */
    private fun pushRings(incidentId: String, at: Long = now, kind: IncidentPushKind = IncidentPushKind.OPEN) {
        store.bumpRingGeneration(incidentId)
        store.activate(incidentId, reopen = kind == IncidentPushKind.REOPEN)
        store.rememberRingUntil(incidentId, ringUntil)
        chains.setRingChain(incidentId, at, kind = kind)
    }

    private fun imUp(incidentId: String, at: Long) {
        store.markLocallyAcknowledged(incidentId, at)
        chains.setDeskChain(incidentId, ackedAtMillis = at, nowMillis = at)
    }

    @Test
    fun `the first ring sets every ring to ring_until`() {
        pushRings("inc_a")

        val slots = alarms.slotsOf("inc_a")
        assertEquals(59, slots.size)
        assertEquals(now + 30_000L, slots.first())
        assertTrue(slots.last() < ringUntil)
        assertEquals(slots, store.chainOf("inc_a")?.slots)
    }

    @Test
    fun `a server push sets the chain again from now and never doubles it`() {
        pushRings("inc_a")
        pushRings("inc_a", at = now + 30_000L, kind = IncidentPushKind.REPEAT)

        val slots = alarms.slotsOf("inc_a")
        assertEquals(58, slots.size)
        assertEquals(now + 60_000L, slots.first())
        assertEquals(slots.toSet().size, slots.size)
        assertEquals(slots, store.chainOf("inc_a")?.slots)
    }

    @Test
    fun `a push late in the window leaves no slot of the longer chain behind`() {
        pushRings("inc_a")
        pushRings("inc_a", at = ringUntil - 2 * minute, kind = IncidentPushKind.REPEAT)

        assertEquals(3, alarms.slotsOf("inc_a").size)
        assertEquals(3, alarms.set.size)
    }

    @Test
    fun `the topic's own interval spaces the chain`() {
        store.rememberTopic("inc_a", "prod")
        timers["prod"] = TopicTimers(repeatIntervalS = 60, maxRingS = 1800, deskTimerS = 600)
        pushRings("inc_a")

        assertEquals(29, alarms.slotsOf("inc_a").size)
    }

    @Test
    fun `learning the topic sets the chain again on its interval`() {
        pushRings("inc_a")
        store.rememberTopic("inc_a", "prod")
        timers["prod"] = TopicTimers(repeatIntervalS = 300, maxRingS = 1800, deskTimerS = 600)

        chains.topicLearned("inc_a", now)

        assertEquals(5, alarms.slotsOf("inc_a").size)
    }

    @Test
    fun `learning a topic whose switch is off drops the chain`() {
        pushRings("inc_a")
        store.rememberTopic("inc_a", "prod")
        critical["prod"] = false

        chains.topicLearned("inc_a", now)

        assertTrue(alarms.set.isEmpty())
        assertNull(store.chainOf("inc_a"))
    }

    @Test
    fun `a refused alarm leaves nothing half set`() {
        pushRings("inc_a")
        alarms.refuse = true
        pushRings("inc_a", at = now + 30_000L, kind = IncidentPushKind.REPEAT)

        assertTrue(alarms.set.isEmpty())
        assertNull(store.chainOf("inc_a"))
    }

    @Test
    fun `the onboarding demo has no ring_until and gets no chain`() {
        store.activate("inc_demo")
        assertNull(chains.setRingChain("inc_demo", now))
        assertTrue(alarms.set.isEmpty())
    }

    @Test
    fun `quiet hours at the first ring set nothing, as the re-arm did`() {
        quiet = true
        pushRings("inc_a")
        assertTrue(alarms.set.isEmpty())
    }

    // Every cancel path.

    @Test
    fun `I'm up removes every ring of the chain`() {
        pushRings("inc_a")
        chains.cancelChain("inc_a")
        store.markLocallyAcknowledged("inc_a", now)

        assertTrue(alarms.slotsOf("inc_a").isEmpty())
    }

    @Test
    fun `At my desk removes every slot of the desk timer chain`() {
        pushRings("inc_a")
        imUp("inc_a", now + minute)
        assertTrue(alarms.slotsOf("inc_a").isNotEmpty())

        chains.cancelChain("inc_a")

        assertTrue(alarms.set.isEmpty())
        assertNull(store.chainOf("inc_a"))
    }

    @Test
    fun `an ack from another phone removes every slot`() {
        pushRings("inc_a")
        // PushRouter.applyStateChange cancels before it marks the ack.
        chains.cancelChain("inc_a")
        store.markAcknowledged("inc_a", now)
        assertTrue(alarms.set.isEmpty())
    }

    @Test
    fun `the server's ack for this phone's own I'm up keeps the desk timer chain`() {
        pushRings("inc_a")
        imUp("inc_a", now + minute)
        val deskSlots = alarms.slotsOf("inc_a")
        assertTrue(deskSlots.isNotEmpty())

        // PushRouter.applyStateChange, for the ack push that follows the tap.
        val kept = chains.onStatePush("inc_a", IncidentPushKind.ACK)
        store.markAcknowledged("inc_a", now + minute)

        assertTrue(kept)
        assertEquals(deskSlots, alarms.slotsOf("inc_a"))
        assertEquals(ChainRule.Kind.DESK.wire, store.chainOf("inc_a")?.kind)
    }

    @Test
    fun `an ack push for a ring chain, from another phone, removes every slot`() {
        pushRings("inc_a")

        val kept = chains.onStatePush("inc_a", IncidentPushKind.ACK)

        assertFalse(kept)
        assertTrue(alarms.set.isEmpty())
        assertNull(store.chainOf("inc_a"))
    }

    @Test
    fun `a close or expire push removes the desk timer chain too`() {
        for (kind in listOf(IncidentPushKind.CLOSE, IncidentPushKind.EXPIRE)) {
            val id = "inc_${kind.wireValue}"
            pushRings(id)
            imUp(id, now + minute)
            assertTrue(alarms.slotsOf(id).isNotEmpty())

            assertFalse(chains.onStatePush(id, kind))
            assertTrue(kind.wireValue, alarms.slotsOf(id).isEmpty())
        }
    }

    @Test
    fun `a slot that fires past ring_until ends the chain`() {
        pushRings("inc_a")
        val chain = store.chainOf("inc_a")!!
        val fired = chains.onSlotFired("inc_a", chain.slots.lastIndex, chain.slots.last(), nowMillis = ringUntil)

        assertEquals(ChainRule.Fired.END, fired)
        assertTrue(alarms.set.isEmpty())
    }

    @Test
    fun `a slot that fires after an ack the cancel missed ends the chain`() {
        pushRings("inc_a")
        store.markLocallyAcknowledged("inc_a", now)
        val chain = store.chainOf("inc_a")!!

        assertEquals(ChainRule.Fired.END, chains.onSlotFired("inc_a", 0, chain.slots[0], chain.slots[0]))
        assertTrue(alarms.set.isEmpty())
    }

    @Test
    fun `turning Critical off removes every slot on that topic and no other`() {
        store.rememberTopic("inc_a", "prod")
        store.rememberTopic("inc_b", "staging")
        pushRings("inc_a")
        pushRings("inc_b")

        chains.cancelForTopic("prod")

        assertTrue(alarms.slotsOf("inc_a").isEmpty())
        assertEquals(59, alarms.slotsOf("inc_b").size)
    }

    @Test
    fun `a topic list without the topic, or with its switch off, removes its slots`() {
        store.rememberTopic("inc_a", "prod")
        store.rememberTopic("inc_b", "staging")
        store.rememberTopic("inc_c", "deleted")
        pushRings("inc_a")
        pushRings("inc_b")
        pushRings("inc_c")
        pushRings("inc_unknown")

        chains.syncTopics(mapOf("prod" to true, "staging" to false))

        assertEquals(59, alarms.slotsOf("inc_a").size)
        assertTrue(alarms.slotsOf("inc_b").isEmpty())
        assertTrue(alarms.slotsOf("inc_c").isEmpty())
        // Not learned yet: the push that rang it came from a critical topic.
        assertEquals(59, alarms.slotsOf("inc_unknown").size)
    }

    @Test
    fun `the switch turned off is also caught when the next slot fires`() {
        store.rememberTopic("inc_a", "prod")
        pushRings("inc_a")
        critical["prod"] = false
        val chain = store.chainOf("inc_a")!!

        assertEquals(ChainRule.Fired.END, chains.onSlotFired("inc_a", 0, chain.slots[0], chain.slots[0]))
        assertTrue(alarms.set.isEmpty())
    }

    @Test
    fun `sign-out and reset remove every slot of every incident`() {
        pushRings("inc_a")
        pushRings("inc_b")
        imUp("inc_b", now + minute)

        chains.cancelAll()

        assertTrue(alarms.set.isEmpty())
        assertTrue(store.chainIncidentIds().isEmpty())
    }

    @Test
    fun `the start sweep removes the slots of incidents that are over and keeps the rest`() {
        pushRings("inc_open")
        pushRings("inc_acked")
        pushRings("inc_closed")
        pushRings("inc_desk")
        pushRings("inc_past")
        // Each of these had its cancel missed.
        store.markAcknowledged("inc_acked", now)
        store.markClosed("inc_closed", now)
        imUp("inc_desk", now)
        store.deactivate("inc_past")

        chains.sweep(now + minute)

        assertEquals(59, alarms.slotsOf("inc_open").size)
        assertTrue(alarms.slotsOf("inc_acked").isEmpty())
        assertTrue(alarms.slotsOf("inc_closed").isEmpty())
        assertTrue(alarms.slotsOf("inc_past").isEmpty())
        assertEquals(60, alarms.slotsOf("inc_desk").size)
    }

    @Test
    fun `the start sweep removes a chain whose window has passed`() {
        pushRings("inc_a")
        chains.sweep(ringUntil)
        assertTrue(alarms.set.isEmpty())
    }

    // The desk timer chain.

    @Test
    fun `I'm up swaps the ring chain for one that starts when the desk timer ends`() {
        pushRings("inc_a")
        imUp("inc_a", now + minute)

        val slots = alarms.slotsOf("inc_a")
        assertEquals(now + minute + 10 * minute, slots.first())
        assertEquals(60, slots.size)
        assertEquals(ChainRule.Kind.DESK.wire, store.chainOf("inc_a")?.kind)
    }

    @Test
    fun `the desk timer chain follows the topic's timers`() {
        store.rememberTopic("inc_a", "prod")
        timers["prod"] = TopicTimers(repeatIntervalS = 60, maxRingS = 600, deskTimerS = 300)
        pushRings("inc_a")
        imUp("inc_a", now)

        val slots = alarms.slotsOf("inc_a")
        assertEquals(now + 5 * minute, slots.first())
        assertEquals(10, slots.size)
    }

    @Test
    fun `the server's desk timer end replaces the counted one`() {
        pushRings("inc_a")
        imUp("inc_a", now)
        store.rememberDeskTimerFiresAt("inc_a", now + 7 * minute)

        chains.deskTimerLearned("inc_a", now)

        val slots = alarms.slotsOf("inc_a")
        assertEquals(now + 7 * minute, slots.first())
        assertEquals(60, slots.size)
    }

    @Test
    fun `no desk timer chain for an incident not acked here or closed`() {
        pushRings("inc_a")
        assertNull(chains.setDeskChain("inc_a", now, now))
        assertTrue(alarms.slotsOf("inc_a").isEmpty())

        pushRings("inc_b")
        store.markClosed("inc_b", now)
        assertNull(chains.setDeskChain("inc_b", now, now))
        assertTrue(alarms.slotsOf("inc_b").isEmpty())
    }

    @Test
    fun `the desk timer running out reopens the incident here and keeps ringing`() {
        pushRings("inc_a")
        imUp("inc_a", now)
        val before = store.ringGeneration("inc_a")
        val chain = store.chainOf("inc_a")!!

        val fired = chains.onSlotFired("inc_a", 0, chain.slots[0], chain.slots[0])

        assertEquals(ChainRule.Fired.REOPEN_AND_RING, fired)
        assertTrue(store.isActive("inc_a"))
        assertFalse(store.isAcknowledged("inc_a"))
        assertTrue(store.ringGeneration("inc_a") > before)
        assertEquals(chain.untilMillis, store.ringUntilMillis("inc_a"))
        assertEquals(ChainRule.Kind.RING.wire, store.chainOf("inc_a")?.kind)
        // The next slot of the same chain now rings as an open incident.
        assertEquals(ChainRule.Fired.RING, chains.onSlotFired("inc_a", 1, chain.slots[1], chain.slots[1]))
    }

    @Test
    fun `At my desk before the desk timer ends stops the desk timer chain`() {
        pushRings("inc_a")
        imUp("inc_a", now)
        chains.cancelChain("inc_a")
        store.markClosed("inc_a", now + minute)

        assertTrue(alarms.set.isEmpty())
        chains.sweep(now + 11 * minute)
        assertNull(store.chainOf("inc_a"))
    }

    @Test
    fun `a slot from a chain that was replaced does nothing`() {
        pushRings("inc_a")
        val old = store.chainOf("inc_a")!!
        pushRings("inc_a", at = now + 10_000L, kind = IncidentPushKind.REPEAT)

        assertEquals(ChainRule.Fired.STALE, chains.onSlotFired("inc_a", 0, old.slots[0], old.slots[0]))
        assertNotNull(store.chainOf("inc_a"))
    }

    @Test
    fun `the last slot of a cut chain sets the next stretch`() {
        timers["fast"] = TopicTimers(repeatIntervalS = 5, maxRingS = 7200, deskTimerS = 600)
        store.rememberTopic("inc_a", "fast")
        store.activate("inc_a")
        store.rememberRingUntil("inc_a", now + 120 * minute)
        chains.setRingChain("inc_a", now)
        val chain = store.chainOf("inc_a")!!
        assertEquals(ChainRule.MAX_SLOTS, chain.slots.size)

        val last = chain.slots.last()
        chains.onSlotFired("inc_a", chain.slots.lastIndex, last, last)

        assertEquals(last + 5_000L, store.chainOf("inc_a")!!.slots.first())
        assertEquals(ChainRule.MAX_SLOTS, alarms.set.size)
    }

    @Test
    fun `a ring is pending only while a ring chain has a slot ahead`() {
        pushRings("inc_a")
        assertTrue(chains.ringPending("inc_a", now))
        imUp("inc_a", now)
        assertFalse(chains.ringPending("inc_a", now))
        assertNotNull(chains.nextSlotMillis("inc_a", now))
    }
}
