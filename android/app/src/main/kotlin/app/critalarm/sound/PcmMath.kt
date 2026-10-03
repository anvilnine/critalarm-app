package app.critalarm.sound

import android.media.AudioFormat
import android.media.MediaFormat
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

    /** The PCM encoding a format states, or null when it states none. */
    fun encodingOf(format: MediaFormat): Int? =
        if (format.containsKey(MediaFormat.KEY_PCM_ENCODING)) format.getInteger(MediaFormat.KEY_PCM_ENCODING) else null

    /**
     * Bytes per sample for a decoder's [encoding], or null for one the alarm
     * does not read. No stated encoding means 16-bit, the MediaCodec default.
     * 8-bit, 24-bit packed and 32-bit integer output are refused rather than
     * read as 16-bit, which would play noise at the wrong length.
     */
    fun bytesPerSample(encoding: Int?): Int? = when (encoding) {
        null, AudioFormat.ENCODING_PCM_16BIT -> 2
        AudioFormat.ENCODING_PCM_FLOAT -> 4
        else -> null
    }

    /**
     * The new size of a sample buffer of [current] shorts that must hold
     * [needed], never past [max]. Doubles to keep copies rare, starting at
     * 64 K. Null when [needed] is over [max]: the sound is too long to hold.
     */
    fun grownCapacity(current: Int, needed: Int, max: Int): Int? {
        if (needed > max) return null
        if (needed <= current) return current
        val doubled = if (current > max / 2) max else current * 2
        return minOf(max, maxOf(needed, doubled, 1 shl 16))
    }
}
