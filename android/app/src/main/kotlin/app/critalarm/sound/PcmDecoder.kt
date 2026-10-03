package app.critalarm.sound

import android.content.Context
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.util.Log
import java.nio.ByteOrder

/** A whole sound as interleaved 16-bit PCM. */
class DecodedPcm(
    val samples: ShortArray,
    val frames: Int,
    val channels: Int,
    val sampleRate: Int,
)

/**
 * Decodes one alarm sound to 16-bit PCM in memory, once, so the alarm can
 * loop it with no gap.
 *
 * MediaExtractor and MediaCodec read every format MediaPlayer read before:
 * the bundled Ogg Opus files and imported mp3, ogg, m4a, aac, wav and flac.
 * Encoder delay and padding come off here:
 *
 * - MP3 and AAC: the platform decoder trims both from the LAME tag, the
 *   `iTunSMPB` comment or the edit list.
 * - Ogg Opus: the decoder drops the pre-skip but not the padded last packet,
 *   so the tail is cut back to the length the container reports.
 * - Ogg Vorbis, WAV and FLAC come out at their exact length already.
 *
 * Returns null on any failure. The caller then falls back to MediaPlayer.
 */
object PcmDecoder {
    private const val TAG = "CritAlarmAlarm"
    private const val TIMEOUT_US = 10_000L

    /**
     * A decode that takes longer than this is given up on, so a stalled
     * decoder costs at most this much silence before MediaPlayer takes over.
     * Software decoders run the bundled 16 s sounds many times faster than
     * real time; the log line `alarm_decoded ... decode_ms=` shows the cost.
     */
    private const val MAX_DECODE_MS = 2_500L

    /** About 1.25 s of the decoder handing back nothing at all. */
    private const val MAX_EMPTY_DEQUEUES = 125

    /**
     * The most samples ever held in memory, buffer slack included: 90 s of
     * 48 kHz stereo, about 17 MB.
     * Clips are capped at 60 s, so only an odd uncut import gets near it.
     */
    private const val MAX_SAMPLES = 48_000 * 2 * 90

    fun decode(context: Context, source: AlarmSoundSource): DecodedPcm? {
        val extractor = MediaExtractor()
        var codec: MediaCodec? = null
        return try {
            when (source) {
                is AlarmSoundSource.Imported -> extractor.setDataSource(source.path)
                is AlarmSoundSource.Asset ->
                    AlarmSoundStore.openAsset(context, source.assetPath).use {
                        extractor.setDataSource(it.fileDescriptor, it.startOffset, it.length)
                    }
            }
            val track = (0 until extractor.trackCount).firstOrNull {
                extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)
                    ?.startsWith("audio/") == true
            } ?: run {
                Log.w(TAG, "alarm_decode_failed reason=no_audio_track source=$source")
                return null
            }
            extractor.selectTrack(track)
            val format = extractor.getTrackFormat(track)
            val mime = format.getString(MediaFormat.KEY_MIME)!!
            val durationUs =
                if (format.containsKey(MediaFormat.KEY_DURATION)) format.getLong(MediaFormat.KEY_DURATION) else 0L
            val decoder = MediaCodec.createDecoderByType(mime)
            codec = decoder
            decoder.configure(format, null, null, 0)
            decoder.start()

            var sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            var channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            // A raw WAV track can carry its PCM encoding on the extractor's
            // format already; a decoder states its own on its output format.
            var encoding = PcmMath.encodingOf(format)
            var formatSeen = false
            var out = ShortArray(0)
            var outChannels = 0
            var frames = 0
            var scratch = ShortArray(0)
            val info = MediaCodec.BufferInfo()
            var inputDone = false
            var outputDone = false
            val startedAt = System.currentTimeMillis()
            var emptyDequeues = 0

            while (!outputDone) {
                if (System.currentTimeMillis() - startedAt > MAX_DECODE_MS ||
                    emptyDequeues > MAX_EMPTY_DEQUEUES
                ) {
                    Log.w(TAG, "alarm_decode_failed reason=stalled source=$source")
                    return null
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
                        val decoded = decoder.outputFormat
                        sampleRate = decoded.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                        channels = decoded.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                        encoding = PcmMath.encodingOf(decoded) ?: encoding
                        formatSeen = true
                    }
                    outIndex >= 0 -> {
                        if (!formatSeen) {
                            // Some decoders never announce a format change.
                            // Their format is final by the first buffer.
                            val decoded = decoder.getOutputFormat(outIndex)
                            sampleRate = decoded.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                            channels = decoded.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                            encoding = PcmMath.encodingOf(decoded) ?: encoding
                            formatSeen = true
                        }
                        val bytesPerSample = PcmMath.bytesPerSample(encoding) ?: run {
                            Log.w(TAG, "alarm_decode_failed reason=pcm_encoding encoding=$encoding source=$source")
                            return null
                        }
                        if (info.size > 0 && channels > 0) {
                            if (frames > 0 && outChannels != PcmMath.outputChannels(channels)) {
                                Log.w(TAG, "alarm_decode_failed reason=channels_changed source=$source")
                                return null
                            }
                            outChannels = PcmMath.outputChannels(channels)
                            val buffer = decoder.getOutputBuffer(outIndex)!!
                            buffer.order(ByteOrder.nativeOrder())
                            buffer.position(info.offset)
                            val isFloat = bytesPerSample == 4
                            val sampleCount = info.size / bytesPerSample
                            val frameCount = sampleCount / channels
                            if (scratch.size < sampleCount) scratch = ShortArray(sampleCount)
                            if (isFloat) {
                                val floats = buffer.asFloatBuffer()
                                for (i in 0 until sampleCount) scratch[i] = PcmMath.floatToPcm16(floats.get(i))
                            } else {
                                buffer.asShortBuffer().get(scratch, 0, sampleCount)
                            }
                            val needed = (frames + frameCount) * outChannels
                            if (needed > out.size) {
                                val capacity = PcmMath.grownCapacity(out.size, needed, MAX_SAMPLES) ?: run {
                                    Log.w(TAG, "alarm_decode_failed reason=too_long source=$source")
                                    return null
                                }
                                out = out.copyOf(capacity)
                            }
                            PcmMath.mixInto(scratch, frameCount, channels, out, frames * outChannels)
                            frames += frameCount
                        }
                        decoder.releaseOutputBuffer(outIndex, false)
                        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) outputDone = true
                    }
                }
            }
            if (frames == 0 || sampleRate <= 0) {
                Log.w(TAG, "alarm_decode_failed reason=empty source=$source")
                return null
            }
            val kept = if (mime == MediaFormat.MIMETYPE_AUDIO_OPUS) {
                PcmMath.trimmedFrames(
                    decodedFrames = frames,
                    expectedFrames = PcmMath.framesForDurationUs(durationUs, sampleRate),
                    maxTrimFrames = PcmMath.maxTrimFrames(sampleRate),
                )
            } else {
                frames
            }
            Log.i(
                TAG,
                "alarm_decoded mime=$mime rate=$sampleRate channels=$outChannels " +
                    "frames=$kept trimmed=${frames - kept} " +
                    "decode_ms=${System.currentTimeMillis() - startedAt} source=$source",
            )
            DecodedPcm(out, kept, outChannels, sampleRate)
        } catch (error: Exception) {
            Log.w(TAG, "alarm_decode_failed source=$source error=$error")
            null
        } catch (error: OutOfMemoryError) {
            // The buffer is dropped with this frame, so MediaPlayer has room.
            Log.w(TAG, "alarm_decode_failed reason=out_of_memory source=$source")
            null
        } finally {
            runCatching { codec?.stop() }
            runCatching { codec?.release() }
            extractor.release()
        }
    }
}
