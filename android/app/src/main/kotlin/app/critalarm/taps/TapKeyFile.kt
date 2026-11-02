package app.critalarm.taps

import java.io.File
import java.security.SecureRandom

/**
 * The key [TapSignature] signs with, kept in one file in the app's private
 * storage. A notification, a widget and a full-screen intent outlive the
 * process that built them, so the key has to outlive it as well.
 *
 * Only a missing file gets a new key ([SIZE] random bytes), written once.
 * Every later read, in this process or the next, gets the same bytes. The
 * file is never replaced while it might still hold the key in use:
 *
 * - A read that fails leaves the file alone and returns a key for this
 *   process only. Marks made before stay good for the next process.
 * - A file that reads whole but is not [SIZE] bytes cannot hold a key
 *   anything was signed with, so it is replaced.
 * - A key that cannot be written is still returned, for this process only.
 *
 * Never throws and never logs. Pure (java.io only), so a JVM test can reach it.
 */
class TapKeyFile(
    private val file: File,
    private val random: SecureRandom = SecureRandom(),
) {
    fun load(): ByteArray {
        when (val found = read()) {
            is Found.Key -> return found.bytes
            Found.Unreadable -> return fresh()
            Found.Missing, Found.WrongSize -> {
                val key = fresh()
                write(key)
                return key
            }
        }
    }

    private sealed interface Found {
        class Key(val bytes: ByteArray) : Found
        object Missing : Found
        object WrongSize : Found
        object Unreadable : Found
    }

    private fun read(): Found {
        val exists = runCatching { file.exists() }.getOrElse { return Found.Unreadable }
        if (!exists) return Found.Missing
        val bytes = runCatching { file.readBytes() }.getOrElse { return Found.Unreadable }
        return if (bytes.size == SIZE) Found.Key(bytes) else Found.WrongSize
    }

    private fun fresh(): ByteArray = ByteArray(SIZE).also(random::nextBytes)

    private fun write(key: ByteArray) {
        runCatching {
            file.parentFile?.mkdirs()
            // Written beside the real name and moved over it, so a reader
            // never sees half a key.
            val partial = File(file.parentFile, file.name + ".new")
            partial.writeBytes(key)
            if (!partial.renameTo(file)) {
                partial.delete()
            }
        }
    }

    companion object {
        const val SIZE = 32
        const val NAME = "tap_mark_key"
    }
}
