package app.critalarm.sound

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * The sound packs in the galaxy build (Samsung Galaxy Store). It has no Play Asset
 * Delivery, so every pack answers "unavailable", the answer a sideloaded Play
 * apk gives. Same channel name and methods as the play flavor's channel, so
 * Dart does not change. Sounds already copied into the app's sound folder are
 * still reported, because the alarm plays them from there.
 */
@Suppress("UNUSED_PARAMETER")
class SoundPackChannel(
    private val context: Context,
    /** Kept for the play flavor's signature. Nothing is pushed to Dart. */
    channel: MethodChannel,
    /** Kept for the play flavor's signature. There is no store dialog. */
    activity: () -> Activity? = { null },
) {
    companion object {
        const val NAME = "app.critalarm/sound_packs"
    }

    private val main = Handler(Looper.getMainLooper())
    private val fileWork = Executors.newSingleThreadExecutor()

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        val pack = call.argument<String>("pack")
        if (pack == null || !SoundPackRules.isSafeName(pack)) {
            result.success(null)
            return
        }
        when (call.method) {
            "packState", "download" -> result.success(mapOf("state" to "unavailable"))
            "packPath" -> result.success(null)
            "installPack" -> result.success(emptyList<Map<String, String>>())
            "installedPackSounds" -> {
                val ids = call.argument<List<String>>("ids").orEmpty()
                fileWork.execute {
                    val dir = AlarmSoundStore.soundsDir(context)
                    val found = ids.filter { SoundPackRules.isSafeName(it) && SoundPackRules.isInstalled(dir, it) }
                        .map { mapOf("id" to it, "path" to SoundPackRules.installedFile(dir, it).path) }
                    main.post { result.success(found) }
                }
            }
            else -> result.notImplemented()
        }
    }

    /** Nothing to let go of: this channel never listens to a store. */
    fun dispose() = Unit
}
