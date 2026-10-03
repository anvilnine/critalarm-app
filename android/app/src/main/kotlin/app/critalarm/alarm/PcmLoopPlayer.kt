package app.critalarm.alarm

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.Process
import android.util.Log
import app.critalarm.sound.DecodedPcm

/**
 * Plays one decoded sound on the alarm stream through a streaming AudioTrack,
 * looping it with no gap.
 *
 * Why streaming and not a static track with loop points: a static track puts
 * the whole sound in shared memory, and how much a device allows there varies.
 * A 60 s imported clip at 48 kHz stereo is 11 MB. The streaming track keeps a
 * buffer of a fraction of a second, and the writer thread feeds it the same
 * PCM over and over, chunk by chunk, through [PcmLoop].
 *
 * Decoding happens on the same thread, before the track exists, so the caller
 * never blocks. [onFailed] runs on that thread when decoding or the track
 * fails; the caller falls back to MediaPlayer.
 */
class PcmLoopPlayer(
    private val loop: Boolean,
    private val onFailed: () -> Unit,
) {
    private val lock = Any()

    @Volatile
    private var running = true
    private var track: AudioTrack? = null
    private var writerDone = false

    fun start(decode: () -> DecodedPcm?) {
        Thread({ run(decode) }, "CritAlarmLoop").start()
    }

    /** Silences the sound at once. Safe to call from any thread, and more than once. */
    fun stop() {
        synchronized(lock) {
            running = false
            track?.let {
                runCatching { it.pause() }
                runCatching { it.flush() }
            }
            if (writerDone) releaseTrack()
        }
    }

    private fun run(decode: () -> DecodedPcm?) {
        Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO)
        try {
            val pcm = runCatching(decode).getOrNull()
            if (!running) return
            if (pcm == null) {
                onFailed()
                return
            }
            val built = runCatching { build(pcm) }.getOrElse {
                Log.w(TAG, "alarm_track_failed error=$it")
                null
            }
            if (built == null) {
                onFailed()
                return
            }
            synchronized(lock) {
                if (!running) {
                    built.release()
                    return
                }
                track = built
                built.play()
            }
            Log.i(TAG, "alarm_loop_started frames=${pcm.frames} rate=${pcm.sampleRate} channels=${pcm.channels} loop=$loop")
            write(built, pcm)
        } catch (error: Exception) {
            Log.w(TAG, "alarm_loop_failed error=$error")
        } finally {
            synchronized(lock) {
                writerDone = true
                if (!running) releaseTrack()
            }
        }
    }

    /** Feeds the track until [stop], or until one pass is written when not looping. */
    private fun write(track: AudioTrack, pcm: DecodedPcm) {
        val cursor = PcmLoop(pcm.frames, loop)
        val channels = pcm.channels
        while (running) {
            val chunk = cursor.next(CHUNK_FRAMES) ?: break
            val end = (chunk.start + chunk.count) * channels
            var at = chunk.start * channels
            while (at < end && running) {
                val written = track.write(pcm.samples, at, end - at, AudioTrack.WRITE_BLOCKING)
                if (written < 0) {
                    Log.w(TAG, "alarm_track_write_failed code=$written")
                    return
                }
                // Zero only comes back from a paused or stopped track.
                if (written == 0) return
                at += written
            }
        }
    }

    private fun build(pcm: DecodedPcm): AudioTrack {
        val mask = if (pcm.channels == 2) AudioFormat.CHANNEL_OUT_STEREO else AudioFormat.CHANNEL_OUT_MONO
        val minBytes = AudioTrack.getMinBufferSize(pcm.sampleRate, mask, AudioFormat.ENCODING_PCM_16BIT)
        // A quarter second of headroom, so a busy CPU does not starve the track.
        val quarterSecond = pcm.sampleRate * pcm.channels * 2 / 4
        return AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build(),
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(pcm.sampleRate)
                    .setChannelMask(mask)
                    .build(),
            )
            .setTransferMode(AudioTrack.MODE_STREAM)
            .setBufferSizeInBytes(maxOf(minBytes * 2, quarterSecond))
            .build()
            .also {
                if (it.state != AudioTrack.STATE_INITIALIZED) {
                    it.release()
                    error("track not initialized")
                }
            }
    }

    /** Call with [lock] held. */
    private fun releaseTrack() {
        track?.let { runCatching { it.release() } }
        track = null
    }

    private companion object {
        const val TAG = "CritAlarmAlarm"
        const val CHUNK_FRAMES = 4096
    }
}
