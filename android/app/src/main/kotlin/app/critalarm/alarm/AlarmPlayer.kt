package app.critalarm.alarm

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.util.Log
import app.critalarm.sound.AlarmSoundSource
import app.critalarm.sound.AlarmSoundStore

class AlarmPlayer(private val context: Context) {
    private val audioManager = context.getSystemService(AudioManager::class.java)
    private var previousVolume: Int? = null
    private var player: MediaPlayer? = null

    /**
     * Rings the sound picked for [topic], or the default when the push
     * carried no topic. Loops on the alarm stream, which is what gets through
     * silent mode and Do Not Disturb.
     */
    fun start(topic: String? = null) {
        if (player?.isPlaying == true) return
        val soundId = AlarmSoundStore.soundIdFor(context, topic)
        val source = AlarmSoundStore.resolve(context, soundId)
        Log.i(
            "CritAlarmAlarm",
            "alarm_sound sound_id=$soundId source=$source topic=${topic ?: "-"}",
        )
        previousVolume = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
        audioManager.setStreamVolume(
            AudioManager.STREAM_ALARM,
            audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM),
            0,
        )
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
            isLooping = true
            prepare()
            start()
        }
    }

    fun stop() {
        player?.stop()
        player?.release()
        player = null
        previousVolume?.let { audioManager.setStreamVolume(AudioManager.STREAM_ALARM, it, 0) }
        previousVolume = null
    }
}
