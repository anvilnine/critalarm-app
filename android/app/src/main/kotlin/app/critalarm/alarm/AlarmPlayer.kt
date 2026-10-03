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
     * Rings the sound picked for [topic], or the default when the push
     * carried no topic. Loops on the alarm stream, which is what gets through
     * silent mode and Do Not Disturb.
     *
     * The sound is decoded to PCM once and looped by [PcmLoopPlayer], so the
     * wrap from the last sample to the first has no gap. MediaPlayer's own
     * loop seeks back to 0 after the end and leaves a gap every time. If the
     * decode fails, MediaPlayer plays it the old way.
     */
    fun start(topic: String? = null) {
        if (loopPlayer != null || player?.isPlaying == true) return
        val soundId = AlarmSoundStore.soundIdFor(context, topic)
        val source = AlarmSoundStore.resolve(context, soundId)
        Log.i(
            "CritAlarmAlarm",
            "alarm_sound sound_id=$soundId source=$source topic=${topic ?: "-"}",
        )
        // A critical page overrides whatever the volume was set to. That is
        // the product. A quiet build leaves it alone so a desk test at 2pm
        // does not hurt.
        val quiet = QuietAlarm.isOn(context)
        if (quiet) {
            Log.i("CritAlarmAlarm", "alarm_quiet_build ring_seconds=${QuietAlarm.RING_SECONDS}")
        } else {
            previousVolume = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
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
        started = PcmLoopPlayer(loop) {
            main.post {
                // Still the current ring: nobody pressed stop while it decoded.
                if (loopPlayer === started) {
                    loopPlayer = null
                    Log.w("CritAlarmAlarm", "alarm_loop_fallback player=media_player sound_id=$soundId")
                    startMediaPlayer(source, loop)
                }
            }
        }
        loopPlayer = started
        started.start { PcmDecoder.decode(context, source) }
        if (quiet) {
            stopTimer = Handler(Looper.getMainLooper()).also { handler ->
                handler.postDelayed({ stop() }, QuietAlarm.RING_SECONDS * 1000L)
            }
        }
    }

    /** The old path: MediaPlayer, whose loop has a gap at every wrap. */
    private fun startMediaPlayer(source: AlarmSoundSource, loop: Boolean) {
        player = MediaPlayer().apply {
            setAudioAttributes(
                AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build(),
            )
            when (source) {
                is AlarmSoundSource.Imported -> setDataSource(source.path)
                is AlarmSoundSource.Asset ->
                    AlarmSoundStore.openAsset(context, source.assetPath).use {
                        setDataSource(it.fileDescriptor, it.startOffset, it.length)
                    }
            }
            isLooping = loop
            prepare()
            start()
        }
    }

    fun stop() {
        stopTimer?.removeCallbacksAndMessages(null)
        stopTimer = null
        loopPlayer?.stop()
        loopPlayer = null
        player?.stop()
        player?.release()
        player = null
        previousVolume?.let { audioManager.setStreamVolume(AudioManager.STREAM_ALARM, it, 0) }
        previousVolume = null
    }
}
