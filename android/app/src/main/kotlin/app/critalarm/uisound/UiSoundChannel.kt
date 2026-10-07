package app.critalarm.uisound

import android.content.Context
import android.content.res.AssetFileDescriptor
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Plays one short interface sound at a time, such as the cues of the plans
 * screen.
 *
 * This is not the alarm and not the sound picker's preview, and it shares
 * nothing with either. A sound goes out as media (`USAGE_MEDIA`), so it
 * plays at the media volume and is silent when that is at zero. The volume
 * of no stream is read or set here, and audio focus is never asked for, so
 * music keeps playing and nothing an alarm needs is held.
 *
 * Every call arrives on the main thread, and so do the player's callbacks.
 */
class UiSoundChannel(private val context: Context) {
    companion object {
        const val NAME = "app.critalarm/ui_sound"
        private const val TAG = "CritAlarmUiSound"
    }

    private val audioManager = context.getSystemService(AudioManager::class.java)
    private var player: MediaPlayer? = null

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "play" -> result.success(play(call.argument<String>("asset")))
            "stop" -> {
                stop()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    /** Plays [asset] once, in place of whatever was playing. Never queues. */
    private fun play(asset: String?): Boolean {
        stop()
        if (asset == null || !UiSoundRules.isInterfaceSound(asset)) return false
        val ringerMode = audioManager?.ringerMode ?: AudioManager.RINGER_MODE_NORMAL
        if (!UiSoundRules.ringerAllows(ringerMode, AudioManager.RINGER_MODE_NORMAL)) return false
        val next = MediaPlayer()
        player = next
        return runCatching {
            next.setAudioAttributes(
                AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build(),
            )
            openAsset(asset).use {
                next.setDataSource(it.fileDescriptor, it.startOffset, it.length)
            }
            next.isLooping = false
            next.setOnPreparedListener { ready ->
                // Dropped when a newer sound or a stop came first.
                if (player === ready) ready.start()
            }
            next.setOnCompletionListener { release(it) }
            next.setOnErrorListener { failed, _, _ ->
                release(failed)
                true
            }
            // Off the main thread, so a sound never holds a frame back.
            next.prepareAsync()
            true
        }.getOrElse {
            Log.w(TAG, "ui_sound_failed asset=$asset error=$it")
            release(next)
            false
        }
    }

    /** Stops whatever is playing. Safe to call when nothing is. */
    fun stop() {
        player?.let { release(it) }
    }

    private fun release(target: MediaPlayer) {
        if (player === target) player = null
        // A player still preparing, or in its error state, throws from stop().
        runCatching { target.stop() }
        runCatching { target.release() }
    }

    /** Opens a bundled Flutter asset straight out of the apk. */
    private fun openAsset(asset: String): AssetFileDescriptor {
        val key = runCatching {
            FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(asset)
        }.getOrNull() ?: "flutter_assets/$asset"
        return context.assets.openFd(key)
    }
}
