package app.critalarm.sound

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.OpenableColumns
import android.util.Log
import android.webkit.MimeTypeMap
import app.critalarm.MainActivity
import java.io.File
import java.util.UUID

/**
 * "Share to Crit Alarm" on Android.
 *
 * Holds the ACTION_SEND filter for audio so MainActivity does not: a share
 * that landed on MainActivity would start a second Flutter engine inside the
 * sending app's task and take the push channel away from the real one.
 *
 * It has no screen. It copies the shared `content://` stream into the cache
 * on a worker thread, while the read grant from the sender is still live,
 * then hands the copy to MainActivity and finishes.
 */
class ShareReceiverActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val uri = sharedUri(intent)
        if (uri == null) {
            finish()
            return
        }
        Thread {
            val copied = copy(uri)
            runOnUiThread {
                startActivity(
                    Intent(this, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                        putExtra(EXTRA_PATH, copied.path)
                        putExtra(EXTRA_NAME, copied.name)
                        putExtra(EXTRA_SIZE, copied.sizeBytes)
                    },
                )
                finish()
            }
        }.start()
    }

    private fun sharedUri(intent: Intent?): Uri? {
        if (intent?.action != Intent.ACTION_SEND) return null
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }
    }

    private data class Copied(val path: String, val name: String, val sizeBytes: Long)

    /**
     * Copies at most one byte over the 100 MB cap, so a huge file is not read
     * to the end only to be turned away. Dart makes the call on the size. A
     * copy that fails still goes to Dart, with size 0, so the user is told.
     */
    private fun copy(uri: Uri): Copied {
        val name = fileName(uri)
        val folder = File(cacheDir, FOLDER).apply { mkdirs() }
        val target = File(folder, "${UUID.randomUUID()}_$name")
        return try {
            val input = contentResolver.openInputStream(uri)
                ?: return Copied(target.path, name, 0)
            var total = 0L
            input.use { from ->
                target.outputStream().use { to ->
                    val buffer = ByteArray(64 * 1024)
                    while (total <= MAX_SOURCE_BYTES) {
                        val read = from.read(buffer)
                        if (read < 0) break
                        to.write(buffer, 0, read)
                        total += read
                    }
                }
            }
            Copied(target.path, name, total)
        } catch (e: Exception) {
            Log.w(TAG, "incoming_audio_copy_failed ${e.javaClass.simpleName}")
            target.delete()
            Copied(target.path, name, 0)
        }
    }

    /**
     * The name the sender gave the file, with an extension Dart can check.
     * The display name's own extension wins; with none, the MIME type gives
     * one.
     */
    private fun fileName(uri: Uri): String {
        val display = runCatching {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                ?.use { if (it.moveToFirst()) it.getString(0) else null }
        }.getOrNull()
        val base = (display ?: uri.lastPathSegment ?: "audio")
            .replace('/', '_')
            .ifBlank { "audio" }
        if (base.substringAfterLast('.', "").isNotEmpty()) return base
        val extension = contentResolver.getType(uri)
            ?.let { MimeTypeMap.getSingleton().getExtensionFromMimeType(it) }
        return if (extension.isNullOrEmpty()) base else "$base.$extension"
    }

    companion object {
        private const val TAG = "CritAlarmSound"

        /** Under the app's cache, cleared by the cropper as it closes. */
        const val FOLDER = "incoming_audio"

        /** Matches SoundImportLimits.maxSourceBytes in Dart. */
        private const val MAX_SOURCE_BYTES = 100L * 1024 * 1024

        const val EXTRA_PATH = "pending_audio_path"
        const val EXTRA_NAME = "pending_audio_name"
        const val EXTRA_SIZE = "pending_audio_size"
    }
}

/**
 * The shared file MainActivity read off an intent and Dart has not taken yet.
 * Sent live as well; Dart opens each path once.
 */
object IncomingAudioHolder {
    @Volatile
    private var pending: Map<String, Any>? = null

    /** Reads the share off [intent] and removes it, so it is read once. */
    fun read(intent: Intent?): Map<String, Any>? {
        if (intent == null) return null
        if ((intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) != 0) return null
        val path = intent.getStringExtra(ShareReceiverActivity.EXTRA_PATH) ?: return null
        val file = mapOf(
            "path" to path,
            "name" to (intent.getStringExtra(ShareReceiverActivity.EXTRA_NAME) ?: File(path).name),
            "size_bytes" to intent.getLongExtra(ShareReceiverActivity.EXTRA_SIZE, 0L),
        )
        intent.removeExtra(ShareReceiverActivity.EXTRA_PATH)
        intent.removeExtra(ShareReceiverActivity.EXTRA_NAME)
        intent.removeExtra(ShareReceiverActivity.EXTRA_SIZE)
        pending = file
        return file
    }

    /**
     * A fresh launch: deletes copies nobody opened last time, such as one
     * whose cropper was open when the app was killed. [keep] is the copy this
     * launch brought in. Runs off the main thread.
     */
    fun clearLeftovers(cacheDir: File, keep: String?) {
        Thread {
            File(cacheDir, ShareReceiverActivity.FOLDER).listFiles()
                ?.filter { it.path != keep }
                ?.forEach { it.delete() }
        }.start()
    }

    fun take(): Map<String, Any>? {
        val file = pending
        pending = null
        return file
    }
}
