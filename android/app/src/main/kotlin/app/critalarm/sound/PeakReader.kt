package app.critalarm.sound

import android.content.Context
import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.util.Log
import java.nio.ByteOrder
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/**
 * Reads how loud a sound is across a number of even slices, for the waveform
 * on its row in the picker.
 *
 * Decodes with MediaExtractor and MediaCodec one buffer at a time and keeps
 * only a running sum per slice, so a long file never sits in memory. Only
 * about 8000 frames a second are looked at, which is plenty for a picture.
 */
object PeakReader {
    private const val TAG = "CritAlarmSound"
    private const val FRAMES_PER_SECOND_READ = 8000
    private const val TIMEOUT_US = 10_000L

    /** RMS per slice, the loudest slice at 1. Empty when nothing could read it. */
    fun read(context: Context, path: String, isAsset: Boolean, count: Int): List<Double> {
        if (count <= 0) return emptyList()
        val extractor = MediaExtractor()
        var codec: MediaCodec? = null
        return try {
            if (isAsset) {
                AlarmSoundStore.openAsset(context, path).use {
                    extractor.setDataSource(it.fileDescriptor, it.startOffset, it.length)
                }
            } else {
                extractor.setDataSource(path)
            }
            val track = (0 until extractor.trackCount).firstOrNull {
                extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)
                    ?.startsWith("audio/") == true
            } ?: return emptyList()
            extractor.selectTrack(track)
            val format = extractor.getTrackFormat(track)
            val durationUs = if (format.containsKey(MediaFormat.KEY_DURATION)) {
                format.getLong(MediaFormat.KEY_DURATION)
            } else {
                0L
            }
            if (durationUs <= 0) return emptyList()

            val decoder = MediaCodec.createDecoderByType(format.getString(MediaFormat.KEY_MIME)!!)
            codec = decoder
            decoder.configure(format, null, null, 0)
            decoder.start()

            val sums = DoubleArray(count)
            val frames = IntArray(count)
            var sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            var channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            var isFloat = false
            val info = MediaCodec.BufferInfo()
            var inputDone = false
            var outputDone = false

            while (!outputDone) {
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
                            val buffer = decoder.getOutputBuffer(outIndex)!!
                            buffer.position(info.offset)
                            buffer.limit(info.offset + info.size)
                            buffer.order(ByteOrder.nativeOrder())
                            val bytesPerSample = if (isFloat) 4 else 2
                            val frameCount = info.size / (bytesPerSample * channels)
                            val step = max(1, sampleRate / FRAMES_PER_SECOND_READ)
                            var frame = 0
                            while (frame < frameCount) {
                                val base = info.offset + frame * bytesPerSample * channels
                                var mix = 0.0
                                for (c in 0 until channels) {
                                    val at = base + c * bytesPerSample
                                    mix += if (isFloat) {
                                        buffer.getFloat(at).toDouble()
                                    } else {
                                        buffer.getShort(at) / 32768.0
                                    }
                                }
                                mix /= channels
                                val timeUs = info.presentationTimeUs + frame * 1_000_000L / sampleRate
                                val slice = min(count - 1, max(0, (timeUs * count / durationUs).toInt()))
                                sums[slice] += mix * mix
                                frames[slice] += 1
                                frame += step
                            }
                        }
                        decoder.releaseOutputBuffer(outIndex, false)
                        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) outputDone = true
                    }
                }
            }

            val rms = DoubleArray(count) { if (frames[it] > 0) sqrt(sums[it] / frames[it]) else 0.0 }
            val loudest = rms.maxOrNull() ?: 0.0
            if (loudest <= 0.0) rms.map { 0.0 } else rms.map { it / loudest }
        } catch (error: Exception) {
            Log.w(TAG, "peaks_failed path=$path error=$error")
            emptyList()
        } finally {
            runCatching { codec?.stop() }
            runCatching { codec?.release() }
            extractor.release()
        }
    }
}
