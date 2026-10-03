package app.critalarm.sound

import kotlin.math.roundToInt

/**
 * The sums behind [PcmDecoder], kept apart so they run in plain JVM tests.
 */
object PcmMath {
    /**
     * Frames in [durationUs] at [sampleRate], rounded to the nearest frame.
     *
     * For Ogg Opus the extractor reports the duration from the last granule
     * position less the pre-skip, cut to whole microseconds. A frame at 48 kHz
     * is about 20.8 µs, so rounding gets the exact count back.
     */
    fun framesForDurationUs(durationUs: Long, sampleRate: Int): Int {
        if (durationUs <= 0 || sampleRate <= 0) return 0
        return ((durationUs * sampleRate + 500_000L) / 1_000_000L).toInt()
    }

    /**
     * How many of [decodedFrames] to keep when the container says the sound
     * is [expectedFrames] long.
     *
     * Android's Opus decoder drops the pre-skip at the start but never trims
     * the padded last packet, so a decode runs up to one Opus frame long. Only
     * a tail shorter than [maxTrimFrames] is cut, so a bad duration can never
     * eat real audio. A decode that came out short is kept as it is.
     */
    fun trimmedFrames(decodedFrames: Int, expectedFrames: Int, maxTrimFrames: Int): Int {
        if (expectedFrames <= 0 || expectedFrames >= decodedFrames) return decodedFrames
        if (decodedFrames - expectedFrames > maxTrimFrames) return decodedFrames
        return expectedFrames
    }

    /** The most of a tail [trimmedFrames] may cut: 40 ms, two Opus frames. */
    fun maxTrimFrames(sampleRate: Int): Int = sampleRate / 25

    /** Channels the alarm plays: mono and stereo stay, anything wider is folded to mono. */
    fun outputChannels(decodedChannels: Int): Int = if (decodedChannels == 2) 2 else 1

    /** One float sample, -1 to 1, as 16-bit PCM. Out-of-range input is clipped. */
    fun floatToPcm16(sample: Float): Short =
        (sample.coerceIn(-1f, 1f) * Short.MAX_VALUE).roundToInt().toShort()

    /**
     * Copies [frameCount] frames of interleaved [input] (with [inChannels]
     * channels) into [out] at [outOffset], as [outputChannels] of
     * [inChannels]. Returns the number of shorts written.
     */
    fun mixInto(
        input: ShortArray,
        frameCount: Int,
        inChannels: Int,
        out: ShortArray,
        outOffset: Int,
    ): Int {
        val outChannels = outputChannels(inChannels)
        if (outChannels == inChannels) {
            System.arraycopy(input, 0, out, outOffset, frameCount * inChannels)
            return frameCount * inChannels
        }
        for (frame in 0 until frameCount) {
            var sum = 0
            for (c in 0 until inChannels) sum += input[frame * inChannels + c]
            out[outOffset + frame] = (sum / inChannels).toShort()
        }
        return frameCount
    }
}
