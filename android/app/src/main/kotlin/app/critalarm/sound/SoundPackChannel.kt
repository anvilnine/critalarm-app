package app.critalarm.sound

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import com.google.android.play.core.assetpacks.AssetPackException
import com.google.android.play.core.assetpacks.AssetPackManager
import com.google.android.play.core.assetpacks.AssetPackManagerFactory
import com.google.android.play.core.assetpacks.AssetPackState
import com.google.android.play.core.assetpacks.AssetPackStateUpdateListener
import com.google.android.play.core.assetpacks.model.AssetPackErrorCode
import com.google.android.play.core.assetpacks.model.AssetPackStatus
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * The native half of the sound packs on Android: Play Asset Delivery,
 * on-demand packs.
 *
 * The calls match iOS, so Dart has one bridge:
 * - `packState`: where the pack is, as a word, plus progress;
 * - `download`: asks Play for the pack. Progress arrives as `packStateChanged`;
 * - `packPath`: the folder Play put the pack in, or null;
 * - `installPack`: copies the pack's sounds into the app's sound folder;
 * - `installedPackSounds`: which pack sounds have a copy there now.
 *
 * Only a build installed from Play (the internal test track, or bundletool
 * `--local-testing`) can fetch a pack. Anywhere else Play answers with an
 * error that maps to `unavailable`.
 */
class SoundPackChannel(
    private val context: Context,
    private val channel: MethodChannel,
    /** The activity on screen, for Play's own confirmation dialogs. */
    private val activity: () -> Activity? = { null },
) {
    companion object {
        const val NAME = "app.critalarm/sound_packs"
        private const val TAG = "CritAlarmSound"
    }

    private val main = Handler(Looper.getMainLooper())
    private val fileWork = Executors.newSingleThreadExecutor()
    private val manager: AssetPackManager by lazy { AssetPackManagerFactory.getInstance(context) }
    private var listening = false

    /** The status the last dialog was shown for, so an update repeats none. */
    private var askedFor: Int? = null

    private val listener = AssetPackStateUpdateListener { state ->
        main.post {
            // Play can start waiting after the download call answered. Ask
            // once per wait, and only while the app is on screen.
            if (state.status() != askedFor) askIfPlayWaits(state.status(), onlyIfResumed = true)
            Log.i(TAG, "pack_state pack=${state.name()} status=${state.status()} error=${state.errorCode()}")
            channel.invokeMethod("packStateChanged", stateMap(state.name(), state) + ("pack" to state.name()))
        }
    }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        val pack = call.argument<String>("pack")
        if (pack == null || !SoundPackRules.isSafeName(pack)) {
            result.success(null)
            return
        }
        when (call.method) {
            "packState" -> packState(pack, result)
            "download" -> download(pack, result)
            "packPath" -> result.success(packAssetsDir(pack)?.path)
            "installPack" -> {
                val ids = call.argument<List<String>>("ids").orEmpty()
                val dir = packAssetsDir(pack)
                fileWork.execute {
                    val installed = if (dir == null) {
                        emptyMap()
                    } else {
                        SoundPackRules.install(dir, AlarmSoundStore.soundsDir(context), ids)
                    }
                    Log.i(TAG, "pack_installed pack=$pack sounds=${installed.size} of=${ids.size}")
                    main.post { result.success(installed.map { (id, path) -> mapOf("id" to id, "path" to path) }) }
                }
            }
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

    /** Stops listening for Play's updates. Called when the engine goes. */
    fun dispose() {
        if (listening) runCatching { manager.unregisterListener(listener) }
        listening = false
    }

    private fun listen() {
        if (listening) return
        runCatching { manager.registerListener(listener) }.onSuccess { listening = true }
    }

    private fun packAssetsDir(pack: String): File? =
        runCatching { manager.getPackLocation(pack)?.assetsPath() }.getOrNull()?.let(::File)

    private fun packState(pack: String, result: MethodChannel.Result) {
        if (packAssetsDir(pack) != null) {
            result.success(mapOf("state" to "downloaded", "progress" to 1.0))
            return
        }
        runCatching { manager.getPackStates(listOf(pack)) }
            .onFailure { result.success(errorMap(it)) }
            .onSuccess { task ->
                task.addOnSuccessListener { states ->
                    val state = states.packStates()[pack]
                    result.success(if (state == null) unavailableMap() else stateMap(pack, state))
                }.addOnFailureListener { result.success(errorMap(it)) }
            }
    }

    private fun download(pack: String, result: MethodChannel.Result) {
        listen()
        runCatching { manager.fetch(listOf(pack)) }
            .onFailure { result.success(errorMap(it)) }
            .onSuccess { task ->
                task.addOnSuccessListener { states ->
                    val state = states.packStates()[pack]
                    state?.let { askIfPlayWaits(it.status(), onlyIfResumed = false) }
                    result.success(if (state == null) unavailableMap() else stateMap(pack, state))
                }.addOnFailureListener {
                    Log.w(TAG, "pack_fetch_failed pack=$pack error=$it")
                    result.success(errorMap(it))
                }
            }
    }

    /**
     * Play holds a download for the user's say-so (a large pack on mobile
     * data, or a confirmation it wants). Its own dialog asks; the answer
     * arrives as a state update. Tapping Download again asks again.
     */
    @Suppress("DEPRECATION")
    private fun askIfPlayWaits(status: Int, onlyIfResumed: Boolean) {
        val waits = status == AssetPackStatus.REQUIRES_USER_CONFIRMATION ||
            status == AssetPackStatus.WAITING_FOR_WIFI
        if (!waits) {
            askedFor = null
            return
        }
        val shown = activity() ?: return
        if (shown.isFinishing || shown.isDestroyed) return
        val resumed = (shown as? LifecycleOwner)?.lifecycle?.currentState
            ?.isAtLeast(Lifecycle.State.RESUMED) ?: false
        if (onlyIfResumed && !resumed) return
        askedFor = status
        runCatching {
            when (status) {
                AssetPackStatus.REQUIRES_USER_CONFIRMATION -> manager.showConfirmationDialog(shown)
                AssetPackStatus.WAITING_FOR_WIFI -> manager.showCellularDataConfirmation(shown)
                else -> null
            }
        }.onFailure { Log.w(TAG, "pack_confirmation_failed status=$status error=$it") }
    }

    private fun stateMap(pack: String, state: AssetPackState): Map<String, Any?> {
        val hasLocation = state.status() == AssetPackStatus.COMPLETED && packAssetsDir(pack) != null
        return mapOf(
            "state" to SoundPackRules.stateName(state.status(), state.errorCode(), hasLocation),
            "progress" to SoundPackRules.progress(state.bytesDownloaded(), state.totalBytesToDownload()),
            "error_code" to state.errorCode(),
        )
    }

    private fun errorMap(error: Throwable): Map<String, Any?> {
        val code = (error as? AssetPackException)?.errorCode ?: AssetPackErrorCode.INTERNAL_ERROR
        return mapOf(
            "state" to SoundPackRules.stateName(AssetPackStatus.FAILED, code, hasLocation = false),
            "error_code" to code,
        )
    }

    private fun unavailableMap() = mapOf("state" to "unavailable")
}
