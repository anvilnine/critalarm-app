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
 * PCM over and over through [PcmWriter].
 *
 * Decoding happens on the same thread, before the track exists, so the caller
 * never blocks. When the track fails after a good decode, one new track is
 * built from the same PCM before giving up. Every way the sound can end while
 * it is still wanted reaches the caller on that thread: [onFailed] when
 * decoding, or both tracks, fail, so the caller can fall back to MediaPlayer,
 * and [onPassDone] when a non-looping ring has played out.
 */
class PcmLoopPlayer(
    private val loop: Boolean,
    private val onFailed: () -> Unit,
    private val onPassDone: () -> Unit = {},
) {
    private val lock = Any()

    @Volatile
    private var running = true

    @Volatile
    private var ended = false
    private var track: AudioTrack? = null

    /**
     * True from [start] until [stop] is called or the writer has ended, by
     * failing or by finishing its one pass. A player that is not alive will
     * never make a sound again.
     */
    val isAlive: Boolean get() = running && !ended

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
        }
    }

    private fun run(decode: () -> DecodedPcm?) {
        runCatching { Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO) }
        LoopRun.finish(
            body = { play(decode) },
            // The writer is the only one that releases the track, so a write
            // in flight never touches a released one.
            release = {
                releaseTrack()
                ended = true
            },
            running = { running },
            onFailed = onFailed,
            onPassDone = onPassDone,
            onError = { Log.w(TAG, "alarm_loop_failed error=$it") },
        )
    }

    private fun play(decode: () -> DecodedPcm?): LoopEnd {
        val pcm = decode()
        if (!running) return LoopEnd.STOPPED
        if (pcm == null) return LoopEnd.FAILED
        // The PCM is good, so a failure from here on is the track's. Build
        // one more from the same PCM before giving up: after an audio server
        // restart the old track is dead but a new one plays.
        return LoopRun.withRetries(
            retries = TRACK_RETRIES,
            running = { running },
            attempt = { playOnce(pcm) },
            onRetry = { number ->
                Log.w(TAG, "alarm_track_retry attempt=$number")
                releaseTrack()
                Thread.sleep(RETRY_DELAY_MS)
            },
            onError = { Log.w(TAG, "alarm_track_failed error=$it") },
        )
    }

    private fun playOnce(pcm: DecodedPcm): LoopEnd {
        val built = build(pcm)
        synchronized(lock) {
            track = built
            if (!running) return LoopEnd.STOPPED
            built.play()
        }
        Log.i(TAG, "alarm_loop_started frames=${pcm.frames} rate=${pcm.sampleRate} channels=${pcm.channels} loop=$loop")
        val end = PcmWriter.feed(
            samples = pcm.samples,
            frames = pcm.frames,
            channels = pcm.channels,
            loop = loop,
            sink = { samples, offset, size -> built.write(samples, offset, size, AudioTrack.WRITE_BLOCKING) },
            running = { running },
            onError = { Log.w(TAG, "alarm_track_write_failed $it") },
        )
        if (end == LoopEnd.PASS_DONE) drain(built, pcm)
        return if (running) end else LoopEnd.STOPPED
    }

    private fun releaseTrack() {
        synchronized(lock) {
            track?.let { runCatching { it.release() } }
            track = null
        }
    }

    /**
     * Lets the last of a single pass play out. `stop()` on a streaming track
     * plays what is buffered and then stops, so this waits for the play head
     * to reach the end, or for [stop], before the track is released.
     */
    private fun drain(track: AudioTrack, pcm: DecodedPcm) {
        synchronized(lock) { if (running) runCatching { track.stop() } }
        val limit = System.currentTimeMillis() + pcm.frames * 1000L / pcm.sampleRate + 1000L
        while (running && System.currentTimeMillis() < limit) {
            val head = runCatching { track.playbackHeadPosition }.getOrDefault(pcm.frames)
            // Some devices reset the head to 0 once the drain completes; the
            // time limit covers them.
            if (head >= pcm.frames) return
            Thread.sleep(50)
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

    private companion object {
        const val TAG = "CritAlarmAlarm"

        /** Fresh tracks built from the same PCM after the first one fails. */
        const val TRACK_RETRIES = 1

        /** Time for a restarting audio server to come back before the rebuild. */
        const val RETRY_DELAY_MS = 250L
    }
}
