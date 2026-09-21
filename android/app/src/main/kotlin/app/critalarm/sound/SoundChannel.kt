package app.critalarm.sound

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaMetadataRetriever
import android.media.MediaPlayer
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors

/**
 * The native half of the sound picker.
 *
 * Preview goes out on `USAGE_ALARM` like the real alarm does, and unlike the
 * alarm it leaves the volume alone, so what the user hears in the picker is
 * the alarm at whatever their alarm volume is set to right now.
 *
 * Anything that reads or writes a sound file runs on one background thread,
 * in the order it was asked for, and answers back on the main thread.
 */
class SoundChannel(private val context: Context, private val channel: MethodChannel) {
    companion object {
        const val NAME = "app.critalarm/sound"
        private const val TAG = "CritAlarmSound"
    }

    private var preview: MediaPlayer? = null

    /** The path Dart asked to play, sent back with previewEnded. */
    private var previewPath: String? = null
    private val fileWork = Executors.newSingleThreadExecutor()

    /** Tokens of peak reads Dart has asked to stop. Read from [fileWork]. */
    private val cancelledPeaks = ConcurrentHashMap.newKeySet<String>()

    /** Ends a clip preview at the end of its range. Removed in [stopPreview]. */
    private val stopAtEnd = Runnable { endPreview() }
    private val main = Handler(Looper.getMainLooper())

    /** Runs [work] off the main thread and hands its answer to [result] on it. */
    private fun inBackground(result: MethodChannel.Result, work: () -> Any?) {
        fileWork.execute {
            val answer = runCatching(work).getOrNull()
            main.post { result.success(answer) }
        }
    }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "capabilities" -> result.success(
                // Android plays any file the user brings in, straight off disk.
                mapOf(
                    "user_sounds_ring_alarm" to true,
                    "bundled_sounds_ring_alarm" to true,
                    "can_import_sounds" to true,
                ),
            )
            // Bundled sounds are read out of the apk. Nothing to copy.
            "prepareBundledSounds" -> result.success(true)
            "startPreview" -> result.success(startPreview(call))
            "stopPreview" -> {
                stopPreview()
                result.success(true)
            }
            "probeDuration" -> {
                val path = call.argument<String>("path")
                inBackground(result) { probeDuration(path) }
            }
            "importSound" -> {
                val sourcePath = call.argument<String>("source_path")
                val id = call.argument<String>("id")
                val startMs = call.argument<Number>("start_ms")?.toLong()
                val endMs = call.argument<Number>("end_ms")?.toLong()
                inBackground(result) {
                    if (startMs != null && endMs != null) {
                        clipSound(sourcePath, id, startMs, endMs)
                    } else {
                        importSound(sourcePath, id)
                    }
                }
            }
            "readPeaks" -> {
                val path = call.argument<String>("path")
                val isAsset = call.argument<Boolean>("is_asset") ?: false
                val count = call.argument<Int>("count") ?: 0
                val token = call.argument<String>("token")
                inBackground(result) {
                    when {
                        path.isNullOrEmpty() -> emptyList()
                        token == null -> PeakReader.read(context, path, isAsset, count)
                        else -> try {
                            PeakReader.read(
                                context,
                                path,
                                isAsset,
                                count,
                                maxReadMs = PeakReader.MAX_CROPPER_READ_MS,
                                isCancelled = { token in cancelledPeaks },
                            )
                        } finally {
                            cancelledPeaks.remove(token)
                        }
                    }
                }
            }
            // Answered at once, not queued: the read it stops is what holds
            // the queue.
            "cancelPeaks" -> {
                call.argument<String>("token")?.let { cancelledPeaks.add(it) }
                result.success(null)
            }
            "deleteSound" -> {
                val path = call.argument<String>("path")
                inBackground(result) { path != null && File(path).delete() }
            }
            else -> result.notImplemented()
        }
    }

    private fun startPreview(call: MethodCall): Boolean {
        val path = call.argument<String>("path") ?: return false
        val isAsset = call.argument<Boolean>("is_asset") ?: false
        val startMs = call.argument<Number>("start_ms")?.toInt()
        val endMs = call.argument<Number>("end_ms")?.toInt()
        stopPreview()
        previewPath = path
        return runCatching {
            preview = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build(),
                )
                if (isAsset) {
                    AlarmSoundStore.openAsset(context, path).use {
                        setDataSource(it.fileDescriptor, it.startOffset, it.length)
                    }
                } else {
                    setDataSource(path)
                }
                // One pass only. The picker is not the alarm.
                isLooping = false
                setOnCompletionListener { endPreview() }
                setOnErrorListener { _, _, _ ->
                    endPreview()
                    true
                }
                prepare()
                if (startMs != null && endMs != null && endMs > startMs) {
                    // A range of a file open in the cropper. Start once the
                    // seek lands, stop when the range runs out.
                    setOnSeekCompleteListener { player ->
                        if (preview !== player) return@setOnSeekCompleteListener
                        player.start()
                        main.postDelayed(stopAtEnd, (endMs - startMs).toLong())
                    }
                    seekTo(startMs.toLong(), MediaPlayer.SEEK_CLOSEST)
                } else {
                    start()
                }
            }
            true
        }.getOrElse {
            Log.w(TAG, "preview_failed path=$path error=$it")
            false
        }
    }

    fun stopPreview() {
        main.removeCallbacks(stopAtEnd)
        preview?.runCatching { stop() }
        preview?.release()
        preview = null
        previewPath = null
    }

    /**
     * The preview stopped without Dart asking: it reached the end, failed, or
     * the app went to the background. Dart stops the progress ring on this.
     */
    fun endPreview() {
        if (preview == null) return
        val path = previewPath ?: ""
        stopPreview()
        channel.invokeMethod("previewEnded", mapOf("path" to path))
    }

    /**
     * Cuts [startMs] to [endMs] out of the picked file and saves it in the
     * app's own folder as a mono wav, with a short fade at each end.
     */
    private fun clipSound(sourcePath: String?, id: String?, startMs: Long, endMs: Long): Map<String, Any>? {
        if (sourcePath == null || id == null) return null
        val destination = File(AlarmSoundStore.soundsDir(context), "$id.wav")
        if (!AudioClipper.clip(sourcePath, destination, startMs, endMs)) {
            Log.w(TAG, "clip_failed id=$id")
            return null
        }
        val duration = probeDuration(destination.path)
        if (duration <= 0) {
            destination.delete()
            return null
        }
        val size = destination.length()
        Log.i(TAG, "sound_clipped id=$id path=${destination.path} duration_ms=$duration size_bytes=$size")
        return mapOf("path" to destination.path, "duration_ms" to duration, "size_bytes" to size)
    }

    private fun probeDuration(path: String?): Int {
        if (path.isNullOrEmpty()) return 0
        val retriever = MediaMetadataRetriever()
        return runCatching {
            retriever.setDataSource(context, Uri.fromFile(File(path)))
            retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                ?.toIntOrNull() ?: 0
        }.getOrElse { 0 }.also { runCatching { retriever.release() } }
    }

    /**
     * Copies the picked file into the app's own folder.
     *
     * No conversion: MediaPlayer reads mp3, ogg, m4a, wav and flac as they
     * come, so the file that was picked is the file that rings.
     */
    private fun importSound(sourcePath: String?, id: String?): Map<String, Any>? {
        if (sourcePath == null || id == null) return null
        val source = File(sourcePath)
        if (!source.exists()) return null
        val extension = source.extension.ifEmpty { "mp3" }.lowercase()
        val destination = File(AlarmSoundStore.soundsDir(context), "$id.$extension")
        return runCatching {
            source.inputStream().use { input ->
                destination.outputStream().use(input::copyTo)
            }
            val duration = probeDuration(destination.path)
            if (duration <= 0) {
                destination.delete()
                return null
            }
            Log.i(TAG, "sound_imported id=$id path=${destination.path} duration_ms=$duration")
            mapOf("path" to destination.path, "duration_ms" to duration)
        }.getOrElse {
            Log.w(TAG, "import_failed id=$id error=$it")
            destination.delete()
            null
        }
    }
}
