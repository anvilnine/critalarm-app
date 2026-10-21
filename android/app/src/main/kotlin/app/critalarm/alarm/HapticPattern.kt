package app.critalarm.alarm

import kotlin.math.ceil
import kotlin.math.roundToInt
import kotlin.math.roundToLong
import kotlin.math.sqrt

/**
 * A vibration in the shape `VibrationEffect.createWaveform` takes: [timings]
 * in milliseconds, each with an [amplitudes] value from 0 (still) to 255.
 */
class Waveform(val timings: LongArray, val amplitudes: IntArray) {
    val durationMs: Long get() = timings.sum()

    /** True when nothing in it moves the motor. */
    val isStill: Boolean get() = amplitudes.all { it == 0 }

    /** The amplitude playing [ms] after the start of one pass. */
    fun amplitudeAt(ms: Long): Int {
        var end = 0L
        for (i in timings.indices) {
            end += timings[i]
            if (ms < end) return amplitudes[i]
        }
        return 0
    }
}

/** How a ring vibrates. */
enum class HapticMode {
    /** The switch is off: only the alarm channel's own single vibration. */
    OFF,

    /** The phone turns the playing sound into vibration itself. */
    GENERATOR,

    /** A waveform made from the sound's loudness, looped with the sound. */
    PATTERN,
}

/**
 * Turns an alarm sound into a vibration on its beat, apart from Android so
 * it is tested on the JVM.
 */
object HapticPattern {
    /** One step of the waveform. A phone's motor follows nothing shorter. */
    const val WINDOW_MS = 20

    /** Loudness, against the loudest step, below which the motor is still. */
    const val GATE = 0.3

    /** The weakest vibration the pattern plays, so a soft beat is still felt. */
    const val MIN_AMPLITUDE = 96

    /** Strength steps, so a steady tone is one long segment and not many. */
    private const val LEVELS = 5

    /** For a ring with no decoded sound to read, such as the MediaPlayer path. */
    val PULSE = Waveform(longArrayOf(600, 400), intArrayOf(255, 0))

    fun mode(switchOn: Boolean, sdk: Int, generatorAvailable: () -> Boolean): HapticMode = when {
        !switchOn -> HapticMode.OFF
        sdk >= GENERATOR_SDK && generatorAvailable() -> HapticMode.GENERATOR
        else -> HapticMode.PATTERN
    }

    /** `HapticGenerator` arrived in Android 12. */
    const val GENERATOR_SDK = 31

    /**
     * RMS loudness per [windowMs] of interleaved 16-bit PCM, channels mixed,
     * the loudest window at 1. All zeros for a silent sound.
     */
    fun loudness(
        samples: ShortArray,
        frames: Int,
        channels: Int,
        sampleRate: Int,
        windowMs: Int = WINDOW_MS,
    ): DoubleArray {
        if (frames <= 0 || channels <= 0 || sampleRate <= 0) return DoubleArray(0)
        val perWindow = maxOf(1, sampleRate * windowMs / 1000)
        val count = (frames + perWindow - 1) / perWindow
        val out = DoubleArray(count)
        for (w in 0 until count) {
            val start = w * perWindow
            val end = minOf(frames, start + perWindow)
            var sum = 0.0
            for (frame in start until end) {
                var mix = 0.0
                for (c in 0 until channels) mix += samples[frame * channels + c] / 32768.0
                mix /= channels
                sum += mix * mix
            }
            out[w] = sqrt(sum / (end - start))
        }
        val loudest = out.maxOrNull() ?: 0.0
        if (loudest <= 0.0) return DoubleArray(count)
        for (i in out.indices) out[i] /= loudest
        return out
    }

    /** Motor strength for one step's [level], 0 to 1 against the loudest step. */
    fun amplitude(level: Double): Int {
        if (level < GATE) return 0
        val above = ((level - GATE) / (1 - GATE)).coerceIn(0.0, 1.0)
        val step = ceil(above * LEVELS).coerceAtLeast(1.0) / LEVELS
        return (MIN_AMPLITUDE + (255 - MIN_AMPLITUDE) * step).roundToInt().coerceAtMost(255)
    }

    /**
     * One pass of vibration for a sound [durationMs] long, from its
     * [loudness] per [windowMs]. The pass is exactly as long as the sound,
     * so looping both keeps them in step. Neighbouring steps of the same
     * strength are joined.
     */
    fun fromLoudness(loudness: DoubleArray, durationMs: Long, windowMs: Int = WINDOW_MS): Waveform {
        val timings = ArrayList<Long>()
        val amplitudes = ArrayList<Int>()
        var at = 0L
        for (i in loudness.indices) {
            if (at >= durationMs) break
            val length = if (i == loudness.lastIndex) durationMs - at else minOf(windowMs.toLong(), durationMs - at)
            val amp = amplitude(loudness[i])
            if (amplitudes.isNotEmpty() && amplitudes.last() == amp) {
                timings[timings.lastIndex] = timings.last() + length
            } else {
                timings.add(length)
                amplitudes.add(amp)
            }
            at += length
        }
        return Waveform(timings.toLongArray(), amplitudes.toIntArray())
    }

    /** The waveform for one decoded sound. */
    fun forPcm(samples: ShortArray, frames: Int, channels: Int, sampleRate: Int): Waveform {
        val durationMs = (frames * 1000.0 / sampleRate).roundToLong()
        return fromLoudness(loudness(samples, frames, channels, sampleRate), durationMs)
    }
}
