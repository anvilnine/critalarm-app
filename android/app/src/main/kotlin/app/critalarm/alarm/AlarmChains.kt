package app.critalarm.alarm

import android.content.Context
import android.util.Log
import app.critalarm.push.IncidentPushKind
import app.critalarm.push.RingLocks
import app.critalarm.storage.BootStorage
import app.critalarm.storage.IncidentDeliveryStore
import app.critalarm.storage.NativeConnectionStore
import app.critalarm.storage.StoredChain
import app.critalarm.storage.TopicTimerStore
import app.critalarm.storage.TopicTimers

/**
 * Sets, replaces and cancels the chains [ChainRule] describes.
 *
 * Everything that touches Android comes in through the constructor, so the
 * cancel paths can be tested with no device. [AlarmChain.of] builds the real
 * one. Every call takes the incident's lock, the one push arming and every
 * guarded stop take, so a chain is never set between a stop's check and its
 * cancel.
 */
class AlarmChains(
    private val store: IncidentDeliveryStore,
    private val alarms: SlotAlarms,
    private val criticalOn: (topic: String?) -> Boolean,
    private val timersFor: (topic: String) -> TopicTimers?,
    private val quietHoursHold: (nowMillis: Long) -> Boolean,
    /** Logcat on a phone. Nothing in a unit test, where `android.util.Log` is a stub. */
    private val log: (String) -> Unit = {},
) {
    /** One system alarm per slot. */
    interface SlotAlarms {
        /** False when the system refused, which means no exact alarm permission. */
        fun set(incidentId: String, slot: Int, atMillis: Long, title: String?, body: String?): Boolean

        /** Safe to call for a slot that is not set. */
        fun cancel(incidentId: String, slot: Int)

        fun isSet(incidentId: String, slot: Int): Boolean
    }

    /**
     * Sets every ring from [nowMillis] to `ring_until`, replacing any chain
     * the incident had. Answers the first slot's instant, or null when
     * [RearmRule] says no, in which case any old chain is cancelled too.
     */
    fun setRingChain(
        incidentId: String,
        nowMillis: Long,
        kind: IncidentPushKind = IncidentPushKind.REPEAT,
        title: String? = null,
        body: String? = null,
    ): Long? = synchronized(RingLocks.of(incidentId)) {
        val topic = store.topicOf(incidentId)
        val ringUntil = store.ringUntilMillis(incidentId)
        val allowed = RearmRule.canRearm(
            incidentId = incidentId,
            kind = kind,
            criticalOn = criticalOn(topic),
            ackedLocally = store.isAcknowledged(incidentId),
            ringUntilMillis = ringUntil,
            nowMillis = nowMillis,
            quietHoursHold = quietHoursHold(nowMillis),
        )
        if (!allowed || ringUntil == null) {
            cancelChain(incidentId)
            return null
        }
        val intervalS = intervalOf(topic)
        val chain = StoredChain(
            kind = ChainRule.Kind.RING.wire,
            untilMillis = ringUntil,
            intervalS = intervalS,
            slots = ChainRule.chainTimes(nowMillis, intervalS, ringUntil),
        )
        replace(incidentId, chain, title, body)
    }

    /**
     * The content fetch named the incident's topic, which the push did not.
     * The ring chain was set with the default interval and the switch read
     * as on, so it is set again from now when the topic says otherwise.
     */
    fun topicLearned(
        incidentId: String,
        nowMillis: Long,
        title: String? = null,
        body: String? = null,
    ) = synchronized(RingLocks.of(incidentId)) {
        val chain = store.chainOf(incidentId) ?: return@synchronized
        if (ChainRule.Kind.fromWire(chain.kind) != ChainRule.Kind.RING) return@synchronized
        val topic = store.topicOf(incidentId)
        if (intervalOf(topic) == chain.intervalS && criticalOn(topic)) return@synchronized
        setRingChain(incidentId, nowMillis, title = title, body = body)
    }

    /**
     * After "I'm up": the rings that stand in for the server's reopen when
     * the desk timer runs out. Replaces any chain the incident had. Answers
     * the first slot, or null when the incident is not acked here, is
     * closed, rings on a topic that is off, or never came from a server push.
     */
    fun setDeskChain(
        incidentId: String,
        ackedAtMillis: Long,
        nowMillis: Long,
        title: String? = null,
        body: String? = null,
    ): Long? = synchronized(RingLocks.of(incidentId)) {
        val topic = store.topicOf(incidentId)
        val fromServer = store.ringUntilMillis(incidentId) != null
        if (!fromServer || !store.isAcknowledged(incidentId) || store.isClosed(incidentId) ||
            !criticalOn(topic)
        ) {
            cancelChain(incidentId)
            return null
        }
        val timers = topic?.let(timersFor)
        val intervalS = timers?.repeatIntervalS ?: RearmRule.DEFAULT_REPEAT_INTERVAL_S
        val maxRingS = timers?.maxRingS ?: ChainRule.DEFAULT_MAX_RING_S
        val deskEnd = ChainRule.deskEndMillis(
            ackedAtMillis = ackedAtMillis,
            serverFiresAtMillis = store.deskTimerFiresAtMillis(incidentId),
            deskTimerS = timers?.deskTimerS,
        )
        val chain = StoredChain(
            kind = ChainRule.Kind.DESK.wire,
            untilMillis = ChainRule.deskChainUntilMillis(deskEnd, maxRingS),
            intervalS = intervalS,
            slots = ChainRule.deskChainTimes(deskEnd, intervalS, maxRingS)
                .filter { it > nowMillis },
        )
        replace(incidentId, chain, title, body)
    }

    /**
     * The ack answered with the server's own desk timer end, which beats the
     * one counted from the cached topic timer. A desk timer chain is set
     * again from it.
     */
    fun deskTimerLearned(
        incidentId: String,
        nowMillis: Long,
        title: String? = null,
        body: String? = null,
    ) = synchronized(RingLocks.of(incidentId)) {
        val chain = store.chainOf(incidentId) ?: return@synchronized
        if (ChainRule.Kind.fromWire(chain.kind) != ChainRule.Kind.DESK) return@synchronized
        setDeskChain(
            incidentId = incidentId,
            ackedAtMillis = store.acknowledgedAtMillis(incidentId) ?: nowMillis,
            nowMillis = nowMillis,
            title = title,
            body = body,
        )
    }

    /** Removes every slot of the incident's chain, whichever kind it is. */
    fun cancelChain(incidentId: String) = synchronized(RingLocks.of(incidentId)) {
        val chain = store.chainOf(incidentId) ?: return@synchronized
        for (slot in chain.slots.indices) alarms.cancel(incidentId, slot)
        store.clearChain(incidentId)
        log("chain_cancelled incident_id=$incidentId slots=${chain.slots.size}")
    }

    /** Sign-out, an account wipe, a connect to another server. */
    fun cancelAll() = store.chainIncidentIds().forEach(::cancelChain)

    /** The topic was deleted, or its critical switch turned off. */
    fun cancelForTopic(topic: String) {
        if (topic.isEmpty()) return
        store.chainIncidentIds()
            .filter { store.topicOf(it) == topic }
            .forEach(::cancelChain)
    }

    /**
     * The full topic list was just read, with each topic's critical switch.
     * A chain on a topic that is gone or switched off goes. A chain whose
     * topic this phone has not learned yet stays.
     */
    fun syncTopics(criticalByTopic: Map<String, Boolean>) {
        store.chainIncidentIds()
            .filter { incidentId ->
                val topic = store.topicOf(incidentId) ?: return@filter false
                criticalByTopic[topic] != true
            }
            .forEach(::cancelChain)
    }

    /**
     * App start. Drops every chain [ChainRule.keepsChain] says no to, which
     * heals a slot a cancel missed.
     */
    fun sweep(nowMillis: Long) {
        for (incidentId in store.chainIncidentIds()) {
            synchronized(RingLocks.of(incidentId)) {
                val chain = store.chainOf(incidentId)
                val kind = ChainRule.Kind.fromWire(chain?.kind)
                val keep = chain != null && kind != null && ChainRule.keepsChain(
                    kind = kind,
                    active = store.isActive(incidentId),
                    acknowledged = store.isAcknowledged(incidentId),
                    closed = store.isClosed(incidentId),
                    criticalOn = criticalOn(store.topicOf(incidentId)),
                    untilMillis = chain.untilMillis,
                    nowMillis = nowMillis,
                )
                if (!keep) cancelChain(incidentId)
            }
        }
    }

    /**
     * A slot's alarm went off. Answers what the receiver does next, and does
     * the bookkeeping that goes with it: the cancel for [ChainRule.Fired.END],
     * the local reopen for [ChainRule.Fired.REOPEN_AND_RING], and the next
     * stretch of a chain that was cut at [ChainRule.MAX_SLOTS].
     */
    fun onSlotFired(
        incidentId: String,
        slot: Int,
        atMillis: Long,
        nowMillis: Long,
        title: String? = null,
        body: String? = null,
    ): ChainRule.Fired = synchronized(RingLocks.of(incidentId)) {
        val chain = store.chainOf(incidentId)
        val current = chain != null && slot in chain.slots.indices && chain.slots[slot] == atMillis
        val fired = ChainRule.onSlotFired(
            kind = ChainRule.Kind.fromWire(chain?.kind),
            current = current,
            active = store.isActive(incidentId),
            acknowledged = store.isAcknowledged(incidentId),
            closed = store.isClosed(incidentId),
            criticalOn = criticalOn(store.topicOf(incidentId)),
            untilMillis = chain?.untilMillis,
            nowMillis = nowMillis,
            quietHoursHold = quietHoursHold(nowMillis),
        )
        if (chain == null) return@synchronized fired
        when (fired) {
            ChainRule.Fired.END -> cancelChain(incidentId)
            ChainRule.Fired.REOPEN_AND_RING -> {
                // What the server does when the desk timer runs out with
                // nobody at the desk: the incident is open again and rings
                // until the end of a fresh ring window. The generation moves
                // on, as a reopen push moves it, so an answer asked for before
                // this cannot end the ring.
                store.bumpRingGeneration(incidentId)
                store.activate(incidentId, reopen = true)
                store.rememberRingUntil(incidentId, chain.untilMillis)
                store.rememberChain(incidentId, chain.copy(kind = ChainRule.Kind.RING.wire))
                extendIfCut(incidentId, slot, chain, nowMillis, title, body)
            }
            ChainRule.Fired.RING, ChainRule.Fired.SKIP ->
                extendIfCut(incidentId, slot, chain, nowMillis, title, body)
            ChainRule.Fired.STALE -> Unit
        }
        fired
    }

    /**
     * After a reboot, which took every alarm with it. Sets the ring chain
     * again from [nowMillis] for every incident still ringing here, with the
     * title and body it last rang with, and drops the record of every other
     * chain, whose slots the reboot already took. An acked incident gets
     * nothing. [rearmAfterBoot] runs before the first unlock, so it reads only
     * what device-protected storage holds.
     */
    fun rearmAfterBoot(nowMillis: Long): BootRearm {
        val rearmed = mutableMapOf<String, Long>()
        val windowOver = mutableListOf<String>()
        for (incidentId in store.activeIncidentIds()) {
            val at = setRingChain(
                incidentId = incidentId,
                nowMillis = nowMillis,
                kind = IncidentPushKind.REPEAT,
                title = store.titleOf(incidentId),
                body = store.bodyOf(incidentId),
            )
            if (at != null) {
                rearmed[incidentId] = at
                continue
            }
            val ringUntil = store.ringUntilMillis(incidentId)
            if (ringUntil != null && nowMillis >= ringUntil) windowOver += incidentId
        }
        for (incidentId in store.chainIncidentIds()) {
            if (incidentId !in rearmed) cancelChain(incidentId)
        }
        log("boot_rearm chains=${rearmed.size} window_over=${windowOver.size}")
        return BootRearm(rearmed, windowOver)
    }

    /**
     * What [rearmAfterBoot] did: the first slot of every chain it set, by
     * incident, and the incidents whose `ring_until` passed while the phone
     * was off.
     */
    data class BootRearm(val firstSlotByIncident: Map<String, Long>, val windowOver: List<String>)

    /** True when a ring chain still has a slot set after [nowMillis]. */
    fun ringPending(incidentId: String, nowMillis: Long): Boolean {
        val chain = store.chainOf(incidentId) ?: return false
        if (ChainRule.Kind.fromWire(chain.kind) != ChainRule.Kind.RING) return false
        return slotPending(incidentId, chain, nowMillis) != null
    }

    /** The next slot of any chain that is still set, or null. */
    fun nextSlotMillis(incidentId: String, nowMillis: Long): Long? {
        val chain = store.chainOf(incidentId) ?: return null
        return slotPending(incidentId, chain, nowMillis)
    }

    private fun slotPending(incidentId: String, chain: StoredChain, nowMillis: Long): Long? {
        val at = ChainRule.nextSlotAfter(chain.slots, nowMillis) ?: return null
        return at.takeIf { alarms.isSet(incidentId, chain.slots.indexOf(at)) }
    }

    private fun extendIfCut(
        incidentId: String,
        slot: Int,
        chain: StoredChain,
        nowMillis: Long,
        title: String?,
        body: String?,
    ) {
        if (!ChainRule.extendsAfter(slot, chain.slots.size, nowMillis, chain.intervalS, chain.untilMillis)) return
        val next = ChainRule.chainTimes(nowMillis, chain.intervalS, chain.untilMillis)
        replace(incidentId, chain.copy(kind = ChainRule.Kind.RING.wire, slots = next), title, body)
    }

    /**
     * Puts [chain] in place of whatever the incident had: slot by slot over
     * the old slots with the same index, then the old slots past the new end
     * are cancelled. Replace, never add. A refusal takes every slot down, so
     * nothing half set stays behind.
     */
    private fun replace(incidentId: String, chain: StoredChain, title: String?, body: String?): Long? {
        val old = store.chainOf(incidentId)
        if (chain.slots.isEmpty()) {
            cancelChain(incidentId)
            return null
        }
        for ((slot, at) in chain.slots.withIndex()) {
            if (alarms.set(incidentId, slot, at, title, body)) continue
            val count = maxOf(chain.slots.size, old?.slots?.size ?: 0)
            for (each in 0 until count) alarms.cancel(incidentId, each)
            store.clearChain(incidentId)
            log("chain_refused incident_id=$incidentId")
            return null
        }
        old?.let { for (slot in chain.slots.size until it.slots.size) alarms.cancel(incidentId, slot) }
        store.rememberChain(incidentId, chain)
        // A reboot drops the slots and the text on them. The chain set again
        // after one reads it back.
        store.rememberContent(incidentId, title, body)
        log("chain_set incident_id=$incidentId kind=${chain.kind} slots=${chain.slots.size}")
        return chain.slots.first()
    }

    private fun intervalOf(topic: String?): Int =
        topic?.let(timersFor)?.repeatIntervalS ?: RearmRule.DEFAULT_REPEAT_INTERVAL_S
}

/** The real [AlarmChains], on the system AlarmManager and the app's preferences. */
object AlarmChain {
    fun of(context: Context): AlarmChains {
        val app = context.applicationContext ?: context
        val timers = TopicTimerStore(app)
        return AlarmChains(
            store = IncidentDeliveryStore(app),
            alarms = SystemSlotAlarms(app),
            criticalOn = { topic -> criticalOn(app, topic) },
            timersFor = timers::timersFor,
            quietHoursHold = { now ->
                QuietHoursWindow.read(app).holdsRing(
                    minuteOfDay = QuietHoursWindow.minuteOfDay(now),
                    priority = QuietHoursWindow.CRITICAL_PRIORITY,
                )
            },
            log = { Log.i(TAG, it) },
        )
    }

    private const val TAG = "CritAlarmAlarm"

    /**
     * Whether the topic still rings.
     *
     * Dart caches the switch under `topic_critical.<topic>` every time it
     * lists topics. An incident whose topic this device has never listed reads
     * as on: the push that rang it was a priority-5 alarm push, which the
     * server only sends for a critical topic, and the server is still
     * repeating anyway. Before the first unlock the switch comes from the
     * copy in device-protected storage.
     */
    internal fun criticalOn(context: Context, topic: String?): Boolean {
        if (topic.isNullOrEmpty()) return true
        val preferences = BootStorage.flutterPrefs(context)
        val key = "flutter.topic_critical.$topic"
        if (!preferences.contains(key)) return true
        return preferences.getBoolean(key, true)
    }

    private class SystemSlotAlarms(private val context: Context) : AlarmChains.SlotAlarms {
        override fun set(incidentId: String, slot: Int, atMillis: Long, title: String?, body: String?) =
            ScheduledAlarmReceiver.scheduleSlot(
                context = context,
                incidentId = incidentId,
                slot = slot,
                atMillis = atMillis,
                // The incident's own server when the session cannot be read,
                // which is the case before the first unlock after a reboot.
                server = NativeConnectionStore(context).canonicalServer()?.toString()
                    ?: IncidentDeliveryStore(context).serverOf(incidentId).orEmpty(),
                title = title.orEmpty(),
                body = body,
            )

        override fun cancel(incidentId: String, slot: Int) =
            ScheduledAlarmReceiver.cancelSlot(context, incidentId, slot)

        override fun isSet(incidentId: String, slot: Int) =
            ScheduledAlarmReceiver.slotIsSet(context, incidentId, slot)
    }
}
