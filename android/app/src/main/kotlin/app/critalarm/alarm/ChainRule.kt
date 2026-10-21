package app.critalarm.alarm

/**
 * The phone's own rings for one incident, set ahead of time and held by the
 * system, so the alarm keeps coming back with no server and no network.
 *
 * Two kinds of chain:
 *
 * - [Kind.RING]: set on the first ring of an incident, one slot every
 *   `repeat_interval_s` from now until `ring_until`. Every alarm push from the
 *   server sets it again from now, replacing the old one. Only "I'm up", "At
 *   my desk" or a word from the server ends it.
 * - [Kind.DESK]: set by "I'm up". It starts when the desk timer ends and runs
 *   for one ring window (`max_ring_s`), the way the server reopens the
 *   incident when the desk timer runs out. "At my desk" or the wake-up
 *   challenge ends it.
 *
 * Every rule here is pure. [AlarmChains] reads the inputs and makes the
 * platform calls.
 */
object ChainRule {
    enum class Kind(val wire: String) {
        RING("ring"),
        DESK("desk"),
        ;

        companion object {
            fun fromWire(wire: String?): Kind? = entries.firstOrNull { it.wire == wire }
        }
    }

    /** What every topic is created with (api.md §3.1). */
    const val DEFAULT_MAX_RING_S = 1800

    /** What every topic is created with (api.md §3.1). */
    const val DEFAULT_DESK_TIMER_S = 600

    /**
     * The most slots one chain holds. The defaults need 60. Android lets an
     * app hold 500 alarms, shared with the Local Reminders, so a short
     * interval on a long ring window stops here and the last slot sets the
     * rest when it fires ([extendsAfter]).
     */
    const val MAX_SLOTS = 120

    /**
     * Every ring the phone sets for itself after [nowMillis]: one every
     * [repeatIntervalS] seconds, the first one interval out, and none at or
     * past [ringUntilMillis]. Empty when there is no `ring_until` (the
     * onboarding demo) or it has passed.
     */
    fun chainTimes(nowMillis: Long, repeatIntervalS: Int, ringUntilMillis: Long?): List<Long> {
        val until = ringUntilMillis ?: return emptyList()
        val step = stepMillis(repeatIntervalS)
        return slotTimes(firstAtMillis = nowMillis + step, stepMillis = step, untilMillis = until)
    }

    /**
     * The desk timer chain: the first ring the moment the desk timer ends,
     * then one every [repeatIntervalS] seconds for [maxRingS] seconds.
     */
    fun deskChainTimes(deskEndMillis: Long, repeatIntervalS: Int, maxRingS: Int): List<Long> =
        slotTimes(
            firstAtMillis = deskEndMillis,
            stepMillis = stepMillis(repeatIntervalS),
            untilMillis = deskChainUntilMillis(deskEndMillis, maxRingS),
        )

    /** Where the desk timer chain stops: one ring window after the desk timer ends. */
    fun deskChainUntilMillis(deskEndMillis: Long, maxRingS: Int): Long =
        deskEndMillis + (if (maxRingS > 0) maxRingS else DEFAULT_MAX_RING_S) * 1000L

    /**
     * When the desk timer ends. The instant the server sent back with the ack
     * wins, because a 409 or a late ack means part of the wait is spent.
     * Without it the topic's cached desk timer counts from the ack.
     */
    fun deskEndMillis(ackedAtMillis: Long, serverFiresAtMillis: Long?, deskTimerS: Int?): Long {
        if (serverFiresAtMillis != null && serverFiresAtMillis > 0L) return serverFiresAtMillis
        val seconds = if (deskTimerS != null && deskTimerS > 0) deskTimerS else DEFAULT_DESK_TIMER_S
        return ackedAtMillis + seconds * 1000L
    }

    /**
     * The request code of one slot's alarm. The slot's intent also carries
     * its own data address, so two slots never share an alarm even when two
     * codes collide.
     */
    fun requestCode(incidentId: String, slot: Int): Int = 31 * incidentId.hashCode() + slot + 1

    /** What a slot that just fired does. */
    enum class Fired {
        /** Ring, as a push would. */
        RING,

        /**
         * The desk timer ran out with nobody at the desk. Open the incident
         * again on this phone, as the server does, and ring.
         */
        REOPEN_AND_RING,

        /** Quiet hours hold this one. The chain stays for the slots after it. */
        SKIP,

        /** The incident needs no more rings from this phone. Drop the chain. */
        END,

        /** A slot from a chain that was replaced since. Do nothing. */
        STALE,
    }

    /**
     * The gate a fired slot goes through. The chain was set minutes ago, and
     * a lot can happen since: an ack, a close, the critical switch turned
     * off, quiet hours starting. Whatever cancel missed is caught here.
     */
    fun onSlotFired(
        kind: Kind?,
        current: Boolean,
        active: Boolean,
        acknowledged: Boolean,
        closed: Boolean,
        criticalOn: Boolean,
        untilMillis: Long?,
        nowMillis: Long,
        quietHoursHold: Boolean,
    ): Fired {
        if (!current || kind == null) return Fired.STALE
        if (!keepsChain(kind, active, acknowledged, closed, criticalOn, untilMillis, nowMillis)) {
            return Fired.END
        }
        if (quietHoursHold) return Fired.SKIP
        return when (kind) {
            Kind.RING -> Fired.RING
            Kind.DESK -> Fired.REOPEN_AND_RING
        }
    }

    /**
     * Whether a chain still belongs on the phone. The app start sweep drops
     * every chain this says no to, which heals a slot a cancel missed.
     *
     * A ring chain needs an open incident nobody acked here. A desk timer
     * chain needs one that was acked here and not closed. Both need the
     * topic's critical switch on and their window still open.
     */
    fun keepsChain(
        kind: Kind,
        active: Boolean,
        acknowledged: Boolean,
        closed: Boolean,
        criticalOn: Boolean,
        untilMillis: Long?,
        nowMillis: Long,
    ): Boolean {
        if (closed || !criticalOn) return false
        val until = untilMillis ?: return false
        if (nowMillis >= until) return false
        return when (kind) {
            Kind.RING -> active && !acknowledged
            Kind.DESK -> acknowledged
        }
    }

    /**
     * True when the slot that just fired was the last one set and the window
     * goes on past it. The chain was cut at [MAX_SLOTS], so it is set again
     * from now.
     */
    fun extendsAfter(slot: Int, slotCount: Int, nowMillis: Long, repeatIntervalS: Int, untilMillis: Long?): Boolean =
        slot == slotCount - 1 && chainTimes(nowMillis, repeatIntervalS, untilMillis).isNotEmpty()

    /** The next slot after [nowMillis], or null when every slot has fired. */
    fun nextSlotAfter(slots: List<Long>, nowMillis: Long): Long? = slots.firstOrNull { it > nowMillis }

    private fun stepMillis(repeatIntervalS: Int): Long =
        (if (repeatIntervalS > 0) repeatIntervalS else RearmRule.DEFAULT_REPEAT_INTERVAL_S) * 1000L

    private fun slotTimes(firstAtMillis: Long, stepMillis: Long, untilMillis: Long): List<Long> {
        val times = mutableListOf<Long>()
        var at = firstAtMillis
        while (at < untilMillis && times.size < MAX_SLOTS) {
            times.add(at)
            at += stepMillis
        }
        return times
    }
}
