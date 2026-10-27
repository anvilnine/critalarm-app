package app.critalarm.taps

import android.content.Context
import android.content.Intent
import app.critalarm.localreminders.LocalReminderAlarms
import java.io.File

/**
 * Puts the [TapSignature] mark on the intents the app builds for MainActivity,
 * and checks it as MainActivity starts or gets a new intent.
 *
 * The key is read from its file once per process and held after that. The
 * alarm card is signed in the same process that later receives its full
 * screen start, so on the ring path the check never waits on the disk.
 */
object TapGate {
    @Volatile
    private var key: ByteArray? = null

    /**
     * Marks [intent] with the mark of the routing extras it carries now.
     * Call it last, after every routing extra is on. Never throws: if
     * signing fails, the intent goes out without a mark and opens as a plain
     * launch.
     */
    fun sign(context: Context, intent: Intent): Intent {
        intent.removeExtra(TapSignature.EXTRA)
        runCatching {
            intent.putExtra(TapSignature.EXTRA, TapSignature.sign(keyFor(context), valuesOf(intent)))
        }
        return intent
    }

    /**
     * Checks [intent] before anything reads it. True only for an intent the
     * app built itself. When it is not, every routing extra comes off, so
     * the launch goes on as a plain one. The mark comes off either way, and
     * Flutter's own start route always does. Nothing is logged.
     */
    fun admit(context: Context, intent: Intent?): Boolean {
        if (intent == null) return false
        val verdict = runCatching {
            TapSignature.verdict(valuesOf(intent), intent.getStringExtra(TapSignature.EXTRA)) {
                keyFor(context)
            }
        }.getOrDefault(TapVerdict.REFUSED)
        intent.removeExtra(TapSignature.EXTRA)
        intent.removeExtra(TapSignature.FLUTTER_ROUTE)
        if (verdict == TapVerdict.REFUSED) {
            TapSignature.FIELDS.forEach(intent::removeExtra)
        }
        return verdict == TapVerdict.SIGNED
    }

    /**
     * The routing extras as the readers see them. The reminder id is an int
     * extra, read the way LocalReminderTapIntent reads it.
     */
    private fun valuesOf(intent: Intent): Map<String, String?> =
        TapSignature.FIELDS.associateWith { name ->
            if (name == LocalReminderAlarms.EXTRA_ID) {
                if (intent.hasExtra(name)) intent.getIntExtra(name, -1).toString() else null
            } else {
                intent.getStringExtra(name)
            }
        }

    private fun keyFor(context: Context): ByteArray {
        key?.let { return it }
        synchronized(this) {
            key?.let { return it }
            val file = File(context.applicationContext.noBackupFilesDir, TapKeyFile.NAME)
            return TapKeyFile(file).load().also { key = it }
        }
    }
}
