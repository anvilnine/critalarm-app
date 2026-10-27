package app.critalarm.taps

import java.io.File
import java.security.SecureRandom

/**
 * The key [TapSignature] signs with, kept in one file in the app's private
 * storage. A notification, a widget and a full-screen intent outlive the
 * process that built them, so the key has to outlive it as well.
 *
 * The first read makes the key ([SIZE] random bytes) and writes it. Every
 * later read, in this process or the next, gets the same bytes. A file of the
 * wrong size is replaced. If the file cannot be written, the new key is still
 * returned, so this process can sign and check its own intents; the next
 * process makes another one.
 *
 * Never throws and never logs. Pure (java.io only), so a JVM test can reach it.
 */
class TapKeyFile(
    private val file: File,
    private val random: SecureRandom = SecureRandom(),
) {
    fun load(): ByteArray {
        read()?.let { return it }
        val key = ByteArray(SIZE).also(random::nextBytes)
        write(key)
        return key
    }

    private fun read(): ByteArray? = runCatching {
        if (!file.isFile || file.length() != SIZE.toLong()) return null
        file.readBytes().takeIf { it.size == SIZE }
    }.getOrNull()

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
