package app.critalarm.sound

import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.util.Log
import java.io.BufferedOutputStream
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.floor
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Cuts one range out of an audio file and writes it as a WAV: mono, 16-bit,
 * 22.05 kHz. A minute of that is about 2.6 MB, needs no encoder or muxer, and
 * MediaPlayer plays it as the alarm.
 *
 * Decodes with MediaExtractor and MediaCodec. Seeks to the sync point before
 * the start, drops what comes before the start, then counts samples until it
 * has the length it wants. Runs on the sound channel's background thread, so
 * a decoder that stops making progress is given up on rather than left to
 * hold that thread.
 */
object AudioClipper {
    private const val TAG = "CritAlarmSound"
    private const val TIMEOUT_US = 10_000L
    private const val MAX_CUT_MS = 60_000L
    private const val MAX_EMPTY_DEQUEUES = 500

    /** The longest clip Android keeps, the same cap as the Dart side. */
    private const val MAX_CLIP_MS = 60_000L

    /**
     * Writes [startMs] to [endMs] of [sourcePath] into [destination]. False
     * when anything fails, and then nothing is left at [destination].
     */
    fun clip(sourcePath: String, destination: File, startMs: Long, endMs: Long): Boolean {
        if (startMs < 0 || endMs <= startMs || endMs - startMs > MAX_CLIP_MS) return false
        val extractor = MediaExtractor()
        var codec: MediaCodec? = null
        // An early return below happens before anything is written.
        val ok = try {
            extractor.setDataSource(sourcePath)
            val track = (0 until extractor.trackCount).firstOrNull {
                extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)
                    ?.startsWith("audio/") == true
            } ?: return false
            extractor.selectTrack(track)
            val format = extractor.getTrackFormat(track)
            val decoder = MediaCodec.createDecoderByType(format.getString(MediaFormat.KEY_MIME)!!)
            codec = decoder
            decoder.configure(format, null, null, 0)
            decoder.start()

            val startUs = startMs * 1000
            extractor.seekTo(startUs, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)

            var sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            var channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            var isFloat = false
            var mono: FloatArray? = null
            var wanted = 0
            var have = 0
            val info = MediaCodec.BufferInfo()
            var inputDone = false
            var outputDone = false
            val startedAt = System.currentTimeMillis()
            var emptyDequeues = 0

            while (!outputDone) {
                if (System.currentTimeMillis() - startedAt > MAX_CUT_MS ||
                    emptyDequeues > MAX_EMPTY_DEQUEUES
                ) {
                    Log.w(TAG, "clip_gave_up path=$sourcePath empty_dequeues=$emptyDequeues")
                    return false
                }
                if (!inputDone) {
                    val inIndex = decoder.dequeueInputBuffer(TIMEOUT_US)
                    if (inIndex >= 0) {
                        val buffer = decoder.getInputBuffer(inIndex)!!
                        val size = extractor.readSampleData(buffer, 0)
                        if (size < 0) {
                            decoder.queueInputBuffer(inIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputDone = true
                        } else {
                            decoder.queueInputBuffer(inIndex, 0, size, extractor.sampleTime, 0)
                            extractor.advance()
                        }
                    }
                }
                val outIndex = decoder.dequeueOutputBuffer(info, TIMEOUT_US)
                if (outIndex == MediaCodec.INFO_TRY_AGAIN_LATER) emptyDequeues += 1 else emptyDequeues = 0
                when {
                    outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        // The real rate and layout come from here, not the extractor.
                        val out = decoder.outputFormat
                        sampleRate = out.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                        channels = out.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                        isFloat = out.containsKey(MediaFormat.KEY_PCM_ENCODING) &&
                            out.getInteger(MediaFormat.KEY_PCM_ENCODING) == AudioFormat.ENCODING_PCM_FLOAT
                    }
                    outIndex >= 0 -> {
                        if (info.size > 0 && channels > 0 && sampleRate > 0) {
                            val samples = mono ?: FloatArray(
                                ((endMs - startMs) * sampleRate / 1000).toInt(),
                            ).also {
                                mono = it
                                wanted = it.size
                            }
                            val buffer = decoder.getOutputBuffer(outIndex)!!
                            buffer.order(ByteOrder.nativeOrder())
                            val bytesPerSample = if (isFloat) 4 else 2
                            val frameCount = info.size / (bytesPerSample * channels)
                            for (frame in 0 until frameCount) {
                                if (have >= wanted) break
                                val timeUs = info.presentationTimeUs + frame * 1_000_000L / sampleRate
                                if (timeUs < startUs) continue
                                val base = info.offset + frame * bytesPerSample * channels
                                var mix = 0f
                                for (c in 0 until channels) {
                                    val at = base + c * bytesPerSample
                                    mix += if (isFloat) buffer.getFloat(at) else buffer.getShort(at) / 32768f
                                }
                                samples[have++] = mix / channels
                            }
                        }
                        decoder.releaseOutputBuffer(outIndex, false)
                        if (have >= wanted && wanted > 0) outputDone = true
                        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) outputDone = true
                    }
                }
            }

            val decoded = mono ?: return false
            if (have == 0) return false
            val clip = ClipMath.resample(decoded, have, sampleRate, ClipMath.OUTPUT_RATE)
            ClipMath.fade(clip, ClipMath.OUTPUT_RATE, ClipMath.FADE_MS)
            BufferedOutputStream(destination.outputStream()).use {
                it.write(ClipMath.wavBytes(clip, ClipMath.OUTPUT_RATE))
            }
            Log.i(TAG, "clip_written frames=${clip.size} path=${destination.path}")
            true
        } catch (error: Exception) {
            Log.w(TAG, "clip_failed path=$sourcePath error=$error")
            false
        } finally {
            runCatching { codec?.stop() }
            runCatching { codec?.release() }
            extractor.release()
        }
        if (!ok) destination.delete()
        return ok
    }
}

/** The sums behind [AudioClipper], kept apart so they run in plain JVM tests. */
object ClipMath {
    const val OUTPUT_RATE = 22_050
    const val FADE_MS = 50

    /** The first [count] of [input] at [fromRate], turned into [toRate] by straight-line steps. */
    fun resample(input: FloatArray, count: Int, fromRate: Int, toRate: Int): FloatArray {
        if (count <= 0) return FloatArray(0)
        if (fromRate == toRate) return input.copyOf(count)
        val outCount = (count.toLong() * toRate / fromRate).toInt().coerceAtLeast(1)
        val step = fromRate.toDouble() / toRate
        return FloatArray(outCount) { i ->
            val at = i * step
            val low = floor(at).toInt().coerceAtMost(count - 1)
            val high = min(low + 1, count - 1)
            val t = (at - low).toFloat()
            input[low] * (1 - t) + input[high] * t
        }
    }

    /** Ramps the first and last [ms] of [samples] up from and down to silence. */
    fun fade(samples: FloatArray, rate: Int, ms: Int) {
        val length = min(rate * ms / 1000, samples.size / 2)
        if (length <= 0) return
        for (i in 0 until length) {
            val gain = i.toFloat() / length
            samples[i] *= gain
            samples[samples.size - 1 - i] *= gain
        }
    }

    /** A complete mono 16-bit PCM WAV file. */
    fun wavBytes(samples: FloatArray, rate: Int): ByteArray {
        val dataLength = samples.size * 2
        val out = ByteBuffer.allocate(44 + dataLength).order(ByteOrder.LITTLE_ENDIAN)
        out.put("RIFF".toByteArray(Charsets.US_ASCII))
        out.putInt(36 + dataLength)
        out.put("WAVE".toByteArray(Charsets.US_ASCII))
        out.put("fmt ".toByteArray(Charsets.US_ASCII))
        out.putInt(16)
        out.putShort(1) // PCM
        out.putShort(1) // mono
        out.putInt(rate)
        out.putInt(rate * 2)
        out.putShort(2)
        out.putShort(16)
        out.put("data".toByteArray(Charsets.US_ASCII))
        out.putInt(dataLength)
        for (sample in samples) {
            out.putShort((sample.coerceIn(-1f, 1f) * 32767f).roundToInt().toShort())
        }
        return out.array()
    }
}
