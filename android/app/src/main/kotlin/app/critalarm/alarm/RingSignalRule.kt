package app.critalarm.alarm

/**
 * What runs on top of the sound while the alarm service rings, and how.
 *
 * Kept apart from Android so it is tested on the JVM. [RingSignals] does the
 * work on the phone.
 */
object RingSignalRule {
    /**
     * One flash a second: the light is on for half a second, then off for
     * half a second.
     *
     * The rate is fixed and is not a setting. Flashes at 3 a second or more
     * can set off a seizure in a person with photosensitive epilepsy, so the
     * flash stays at 1 a second, well under that limit. Do not make it
     * faster, and do not add a second light that blinks out of step with it.
     */
    const val FLASH_ON_MS = 500L
    const val FLASH_OFF_MS = 500L

    /** Flashes a second, for the log line and the test that guards the limit. */
    val flashesPerSecond: Double get() = 1000.0 / (FLASH_ON_MS + FLASH_OFF_MS)

    /**
     * The strong vibration: 700 ms on, 300 ms off, over and over until it is
     * stopped. [VIBRATION_AMPLITUDES] is the strength of each step, 255 being
     * the most a phone can do, and is used where the phone can set a strength.
     */
    val VIBRATION_TIMINGS_MS = longArrayOf(700L, 300L)
    val VIBRATION_AMPLITUDES = intArrayOf(255, 0)

    /**
     * The same pattern for a phone that cannot set a strength. That form of
     * waveform starts with a wait, so it leads with a wait of nothing.
     */
    val VIBRATION_ON_OFF_TIMINGS_MS = longArrayOf(0L, 700L, 300L)

    /** The step the pattern starts again from when it reaches its end. */
    const val VIBRATION_REPEAT_FROM = 0

    data class Wanted(val flash: Boolean, val vibration: Boolean) {
        companion object {
            val NONE = Wanted(flash = false, vibration = false)
        }
    }

    /**
     * Whether to flash and to vibrate, given the topic of every incident the
     * service is holding. A topic is null while the phone has not learned it
     * yet: the push does not carry one (api.md §5.2).
     *
     * Each one runs while any ringing topic has it on, so a second alarm on a
     * topic with both off never takes them away from the first. An incident
     * whose topic is not known counts as off: both switches default to off,
     * and guessing would flash a light nobody asked for.
     */
    fun wanted(ringingTopics: List<String?>, saved: AlarmSignalStore.Saved): Wanted = Wanted(
        flash = ringingTopics.any { it != null && it in saved.flashTopics },
        vibration = ringingTopics.any { it != null && it in saved.vibrationTopics },
    )

    /**
     * Whether the phone should ask the server which topic an incident is on.
     * Only when some topic has a switch on: with every switch off the answer
     * could change nothing, so no request is made.
     */
    fun shouldLearnTopic(topic: String?, saved: AlarmSignalStore.Saved): Boolean =
        topic == null && saved.anyOn
}
