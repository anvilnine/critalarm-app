package app.critalarm.alarm

import android.content.Intent
import app.critalarm.push.IncidentPushKind
import app.critalarm.storage.IncidentDeliveryStore
import app.critalarm.storage.InMemoryPreferences
import app.critalarm.storage.TopicTimers
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * A reboot drops every alarm. What the boot sets again, from what the store
 * kept: the ring chain of an incident still ringing, and nothing for one that
 * was acked, closed or ran out while the phone was off.
 */
class BootRearmTest {
    private val now = 1_757_462_400_000L
    private val minute = 60_000L
    private val ringUntil = now + 30 * minute

    /** The system's alarms. A reboot is a new, empty one. */
    private class FakeAlarms : AlarmChains.SlotAlarms {
        val set = mutableMapOf<Pair<String, Int>, Long>()
        val titles = mutableMapOf<Pair<String, Int>, String?>()
        val bodies = mutableMapOf<Pair<String, Int>, String?>()

        override fun set(incidentId: String, slot: Int, atMillis: Long, title: String?, body: String?): Boolean {
            set[incidentId to slot] = atMillis
            titles[incidentId to slot] = title
            bodies[incidentId to slot] = body
            return true
        }

        override fun cancel(incidentId: String, slot: Int) {
            set.remove(incidentId to slot)
        }

        override fun isSet(incidentId: String, slot: Int) = (incidentId to slot) in set

        fun slotsOf(incidentId: String) = set.filterKeys { it.first == incidentId }.values.sorted()
    }

    /** Device-protected storage: the one thing that outlives the reboot. */
    private val store = IncidentDeliveryStore(InMemoryPreferences())
    private val critical = mutableMapOf<String, Boolean>()
    private val timers = mutableMapOf<String, TopicTimers>()

    private fun chains(alarms: AlarmChains.SlotAlarms) = AlarmChains(
        store = store,
        alarms = alarms,
        criticalOn = { topic -> topic == null || critical[topic] ?: true },
        timersFor = { timers[it] },
        quietHoursHold = { false },
    )

    private val beforeReboot = FakeAlarms()

    /** What a priority-5 push does to the store before it sets the chain. */
    private fun pushRings(incidentId: String, title: String? = "Disk full", body: String? = "db-1 at 99%") {
        store.bumpRingGeneration(incidentId)
        store.activate(incidentId)
        store.rememberRingUntil(incidentId, ringUntil)
        chains(beforeReboot).setRingChain(incidentId, now, kind = IncidentPushKind.OPEN, title = title, body = body)
    }

    @Test
    fun `an open incident gets its whole chain back from the boot`() {
        pushRings("inc_a")
        val bootAt = now + 5 * minute
        val afterReboot = FakeAlarms()

        val result = chains(afterReboot).rearmAfterBoot(bootAt)

        val slots = afterReboot.slotsOf("inc_a")
        assertEquals(ChainRule.chainTimes(bootAt, 30, ringUntil), slots)
        assertEquals(bootAt + 30_000L, slots.first())
        assertTrue(slots.last() < ringUntil)
        assertEquals(49, slots.size)
        assertEquals(mapOf("inc_a" to bootAt + 30_000L), result.firstSlotByIncident)
        assertEquals(slots, store.chainOf("inc_a")?.slots)
        assertTrue(result.windowOver.isEmpty())
    }

    @Test
    fun `the boot chain rings with the title and body the incident last rang with`() {
        pushRings("inc_a", title = "Disk full", body = "db-1 at 99%")
        val afterReboot = FakeAlarms()

        chains(afterReboot).rearmAfterBoot(now + minute)

        assertTrue(afterReboot.titles.values.all { it == "Disk full" })
        assertTrue(afterReboot.bodies.values.all { it == "db-1 at 99%" })
    }

    @Test
    fun `the boot uses the topic's own repeat interval`() {
        pushRings("inc_a")
        store.rememberTopic("inc_a", "prod")
        timers["prod"] = TopicTimers(repeatIntervalS = 60, maxRingS = 1800, deskTimerS = 600)
        val afterReboot = FakeAlarms()

        chains(afterReboot).rearmAfterBoot(now)

        val slots = afterReboot.slotsOf("inc_a")
        assertEquals(now + 60_000L, slots.first())
        assertEquals(29, slots.size)
    }

    @Test
    fun `an acked incident gets no slot and its old chain record goes`() {
        pushRings("inc_a")
        store.markLocallyAcknowledged("inc_a", now + minute)
        val afterReboot = FakeAlarms()

        val result = chains(afterReboot).rearmAfterBoot(now + 2 * minute)

        assertTrue(afterReboot.slotsOf("inc_a").isEmpty())
        assertNull(store.chainOf("inc_a"))
        assertTrue(result.firstSlotByIncident.isEmpty())
    }

    @Test
    fun `a desk timer chain left by I'm up does not come back from the boot`() {
        pushRings("inc_a")
        store.markLocallyAcknowledged("inc_a", now + minute)
        chains(beforeReboot).setDeskChain("inc_a", ackedAtMillis = now + minute, nowMillis = now + minute)
        val afterReboot = FakeAlarms()

        chains(afterReboot).rearmAfterBoot(now + 2 * minute)

        assertTrue(afterReboot.slotsOf("inc_a").isEmpty())
        assertNull(store.chainOf("inc_a"))
    }

    @Test
    fun `a closed incident gets no slot`() {
        pushRings("inc_a")
        store.markClosed("inc_a", now + minute)
        val afterReboot = FakeAlarms()

        chains(afterReboot).rearmAfterBoot(now + 2 * minute)

        assertTrue(afterReboot.set.isEmpty())
    }

    @Test
    fun `a topic switched off before the reboot gets no slot`() {
        pushRings("inc_a")
        store.rememberTopic("inc_a", "prod")
        critical["prod"] = false
        val afterReboot = FakeAlarms()

        chains(afterReboot).rearmAfterBoot(now + minute)

        assertTrue(afterReboot.set.isEmpty())
        assertNull(store.chainOf("inc_a"))
    }

    @Test
    fun `an incident whose ring window ran out while the phone was off is reported, not set`() {
        pushRings("inc_a")
        val afterReboot = FakeAlarms()

        val result = chains(afterReboot).rearmAfterBoot(ringUntil + minute)

        assertTrue(afterReboot.set.isEmpty())
        assertEquals(listOf("inc_a"), result.windowOver)
        assertNull(store.chainOf("inc_a"))
    }

    @Test
    fun `only the incident still ringing comes back when two were open`() {
        pushRings("inc_a")
        pushRings("inc_b")
        store.markLocallyAcknowledged("inc_b", now + minute)
        val afterReboot = FakeAlarms()

        val result = chains(afterReboot).rearmAfterBoot(now + 2 * minute)

        assertEquals(setOf("inc_a"), result.firstSlotByIncident.keys)
        assertFalse(afterReboot.slotsOf("inc_a").isEmpty())
        assertTrue(afterReboot.slotsOf("inc_b").isEmpty())
    }

    @Test
    fun `the onboarding demo, which no server sent, gets nothing`() {
        store.activate("inc_demo")
        val afterReboot = FakeAlarms()

        val result = chains(afterReboot).rearmAfterBoot(now)

        assertTrue(afterReboot.set.isEmpty())
        assertTrue(result.windowOver.isEmpty())
    }

    @Test
    fun `the locked boot always runs`() {
        assertTrue(BootRearmRule.runs(BootRearmRule.Boot.LOCKED, bootCount = 7, rearmedBootCount = 7))
        assertTrue(BootRearmRule.runs(BootRearmRule.Boot.LOCKED, bootCount = null, rearmedBootCount = null))
    }

    @Test
    fun `the boot after the unlock skips what the locked boot already did`() {
        assertFalse(BootRearmRule.runs(BootRearmRule.Boot.UNLOCKED, bootCount = 7, rearmedBootCount = 7))
    }

    @Test
    fun `the boot after the unlock runs when the locked one did not`() {
        assertTrue(BootRearmRule.runs(BootRearmRule.Boot.UNLOCKED, bootCount = 8, rearmedBootCount = 7))
        assertTrue(BootRearmRule.runs(BootRearmRule.Boot.UNLOCKED, bootCount = 8, rearmedBootCount = null))
        assertTrue(BootRearmRule.runs(BootRearmRule.Boot.UNLOCKED, bootCount = null, rearmedBootCount = 7))
    }

    @Test
    fun `the store keeps the boot count across a new store on the same file`() {
        val prefs = InMemoryPreferences()
        IncidentDeliveryStore(prefs).rememberRearmedBoot(12)
        assertEquals(12, IncidentDeliveryStore(prefs).rearmedBootCount())
        assertNull(IncidentDeliveryStore(InMemoryPreferences()).rearmedBootCount())
    }

    @Test
    fun `the two boot broadcasts map to the two boots and nothing else does`() {
        assertEquals(BootRearmRule.Boot.LOCKED, BootRearmRule.Boot.fromAction(Intent.ACTION_LOCKED_BOOT_COMPLETED))
        assertEquals(BootRearmRule.Boot.UNLOCKED, BootRearmRule.Boot.fromAction(Intent.ACTION_BOOT_COMPLETED))
        assertNull(BootRearmRule.Boot.fromAction(Intent.ACTION_MY_PACKAGE_REPLACED))
        assertNull(BootRearmRule.Boot.fromAction(null))
    }
}
