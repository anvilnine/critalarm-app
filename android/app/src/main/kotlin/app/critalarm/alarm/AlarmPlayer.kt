package app.critalarm.alarm

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Handler
import android.os.Looper
import android.util.Log
import app.critalarm.sound.AlarmSoundSource
import app.critalarm.sound.AlarmSoundStore
import app.critalarm.sound.PcmDecoder

class AlarmPlayer(private val context: Context) {
    private val audioManager = context.getSystemService(AudioManager::class.java)
    private val main = Handler(Looper.getMainLooper())
    private var previousVolume: Int? = null
    private var loopPlayer: PcmLoopPlayer? = null
    private var player: MediaPlayer? = null
    private var stopTimer: Handler? = null

    /**
     * Bumped on every start and stop. A delayed retry carries the value it
     * was posted under and does nothing once the ring it belonged to is over.
     */
    private var ringNumber = 0

    /** Whether this ring has already used its one MediaPlayer retry. */
    private var mediaRetried = false

    private fun isMainThread() = Looper.getMainLooper().isCurrentThread

    /**
     * Rings the sound picked for [topic], or the default when the push
     * carried no topic. Loops on the alarm stream, which is what gets through
     * silent mode and Do Not Disturb.
     *
     * The sound is decoded to PCM once and looped by [PcmLoopPlayer], so the
     * wrap from the last sample to the first has no gap. MediaPlayer's own
     * loop seeks back to 0 after the end and leaves a gap every time. If the
     * decode or the track fails, MediaPlayer plays it the old way.
     *
     * Safe to call from any thread: everything runs on the main thread, see
     * [AlarmPlayerRules.onMain].
     */
    fun start(topic: String? = null) {
        AlarmPlayerRules.onMain(isMainThread(), { main.post(it) }) { startOnMain(topic) }
    }

    private fun startOnMain(topic: String?) {
        val playing = runCatching { player?.isPlaying == true }.getOrDefault(false)
        if (!AlarmPlayerRules.shouldRing(loopPlayer?.isAlive == true, playing)) return
        // Whatever is left is dead: a writer that failed, a single pass that
        // played out, or a MediaPlayer that stopped. Clear it and ring again.
        releasePlayers()
        ringNumber += 1
        mediaRetried = false
        val (soundId, source) = AlarmSoundStore.resolveForTopic(context, topic)
        Log.i(
            TAG,
            "alarm_sound sound_id=$soundId source=$source topic=${topic ?: "-"}",
        )
        // A critical page overrides whatever the volume was set to. That is
        // the product. A quiet build leaves it alone so a desk test at 2pm
        // does not hurt.
        val quiet = QuietAlarm.isOn(context)
        if (quiet) {
            Log.i(TAG, "alarm_quiet_build ring_seconds=${QuietAlarm.RING_SECONDS}")
        } else {
            // A re-ring keeps the volume saved by the first ring, not the
            // maximum this player set.
            if (previousVolume == null) {
                previousVolume = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
            }
            audioManager.setStreamVolume(
                AudioManager.STREAM_ALARM,
                audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM),
                0,
            )
        }
        // A quiet ring plays the sound once, as before, and the timer below
        // stops it.
        val loop = !quiet
        lateinit var started: PcmLoopPlayer
        started = PcmLoopPlayer(
            loop = loop,
            onFailed = {
                main.post {
                    // Dropped when stop or a newer ring came first.
                    if (AlarmPlayerRules.isCurrent(started, loopPlayer)) {
                        loopPlayer = null
                        Log.w(TAG, "alarm_loop_fallback player=media_player sound_id=$soundId")
                        startMediaPlayer(source, loop)
                    }
                }
            },
            onPassDone = {
                // A quiet ring played its one pass. Clear it so the next
                // ring, such as a handover to the incident below, plays.
                main.post { if (AlarmPlayerRules.isCurrent(started, loopPlayer)) loopPlayer = null }
            },
        )
        loopPlayer = started
        started.start { PcmDecoder.decode(context, source) }
        if (quiet) {
            stopTimer = Handler(Looper.getMainLooper()).also { handler ->
                handler.postDelayed({ stop() }, QuietAlarm.RING_SECONDS * 1000L)
            }
        }
    }

    /**
     * The old path: MediaPlayer, whose loop has a gap at every wrap. If the
     * sound will not open, the bundled default is tried before giving up.
     */
    private fun startMediaPlayer(source: AlarmSoundSource, loop: Boolean) {
        var next: AlarmSoundSource? = source
        while (next != null) {
            if (tryMediaPlayer(next, source, loop)) return
            val failed = next
            next = AlarmFallback.next(failed, AlarmSoundStore.assetPathFor(AlarmSoundStore.FALLBACK_ID))
            Log.w(TAG, "alarm_media_player_failed source=$failed next=${next ?: "-"}")
        }
        Log.e(TAG, "alarm_silent reason=no_player_could_open_a_sound")
    }

    /** Opens and starts [source]. [chainStart] is where a retry begins the chain again. */
    private fun tryMediaPlayer(source: AlarmSoundSource, chainStart: AlarmSoundSource, loop: Boolean): Boolean {
        var candidate: MediaPlayer? = null
        return try {
            val opened = MediaPlayer()
            candidate = opened
            opened.setAudioAttributes(
                AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build(),
            )
            when (source) {
                is AlarmSoundSource.Imported -> opened.setDataSource(source.path)
                is AlarmSoundSource.Asset ->
                    AlarmSoundStore.openAsset(context, source.assetPath).use {
                        opened.setDataSource(it.fileDescriptor, it.startOffset, it.length)
                    }
            }
            opened.isLooping = loop
            // Errors after start (the audio server restarting, say) arrive
            // here, on main, where the player was made.
            opened.setOnErrorListener { failed, what, extra ->
                onMediaPlayerError(failed, what, extra, chainStart, loop)
                true
            }
            opened.prepare()
            opened.start()
            player = opened
            true
        } catch (error: Exception) {
            Log.w(TAG, "alarm_media_player_error source=$source error=$error")
            candidate?.let { runCatching { it.release() } }
            false
        }
    }

    /**
     * A MediaPlayer failed after it started. Release it and run the fallback
     * chain once more after [MEDIA_RETRY_MS]; a second failure is logged as
     * silence.
     */
    private fun onMediaPlayerError(failed: MediaPlayer, what: Int, extra: Int, source: AlarmSoundSource, loop: Boolean) {
        Log.w(TAG, "alarm_media_player_error_async what=$what extra=$extra")
        if (!AlarmPlayerRules.isCurrent(failed, player)) return
        runCatching { failed.release() }
        player = null
        if (mediaRetried) {
            Log.e(TAG, "alarm_silent reason=media_player_failed_after_retry")
            return
        }
        mediaRetried = true
        val ring = ringNumber
        main.postDelayed({
            if (ring == ringNumber && player == null && loopPlayer == null) {
                Log.w(TAG, "alarm_media_player_retry source=$source")
                startMediaPlayer(source, loop)
            }
        }, MEDIA_RETRY_MS)
    }

    /** Safe to call from any thread, and more than once. */
    fun stop() {
        AlarmPlayerRules.onMain(isMainThread(), { main.post(it) }) { stopOnMain() }
    }

    private fun stopOnMain() {
        ringNumber += 1
        try {
            releasePlayers()
        } finally {
            // Whatever failed above, the alarm stream gets its volume back.
            previousVolume?.let { volume ->
                runCatching { audioManager.setStreamVolume(AudioManager.STREAM_ALARM, volume, 0) }
                    .onFailure { Log.w(TAG, "alarm_volume_restore_failed error=$it") }
            }
            previousVolume = null
        }
    }

    /** Stops and drops both players and the quiet timer. Never throws. */
    private fun releasePlayers() {
        stopTimer?.removeCallbacksAndMessages(null)
        stopTimer = null
        loopPlayer?.let { runCatching { it.stop() } }
        loopPlayer = null
        player?.let { stale ->
            // A MediaPlayer in its Error state throws from stop().
            runCatching { stale.stop() }
            runCatching { stale.release() }
        }
        player = null
    }

    private companion object {
        const val TAG = "CritAlarmAlarm"

        /** How long a failed MediaPlayer waits before the chain runs again. */
        const val MEDIA_RETRY_MS = 500L
    }
}
