package app.critalarm.alarm

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import app.critalarm.R

class AlarmPlayer(private val context: Context) {
    private val audioManager = context.getSystemService(AudioManager::class.java)
    private var previousVolume: Int? = null
    private var player: MediaPlayer? = null

    fun start() {
        if (player?.isPlaying == true) return
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
            setDataSource(context, Uri.parse("android.resource://${context.packageName}/${R.raw.alarm}"))
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
