package app.critalarm.sound

import java.io.File
import java.io.IOException

/**
 * Which `pending_audio_path` MainActivity may hand to Dart.
 *
 * MainActivity is exported, so any app can start it with that extra. Dart
 * deletes the path it gets once the cropper closes or the file is turned
 * away, so a path from anywhere else would let another app delete files in
 * this app's own storage. Two things have to hold:
 *
 * - ShareReceiverActivity issued the path in this process ([issued]). It is
 *   the only writer of the extra, and the path carries a random UUID.
 * - The path names a file directly inside [folder] once both are resolved:
 *   no `.` or `..` part, and no link that leads somewhere else.
 */
internal object ShareCopyRule {
    fun accepts(path: String, folder: File, issued: Boolean): Boolean =
        issued && isInside(path, folder)

    fun isInside(path: String, folder: File): Boolean {
        val file = File(path)
        if (!file.isAbsolute) return false
        if (path.split('/').any { it == "." || it == ".." }) return false
        return try {
            val canonical = file.canonicalFile
            // A link inside the folder that points at another file inside it
            // resolves to a different name. Nothing makes links there, so
            // that is turned away too.
            canonical.parentFile == folder.canonicalFile && canonical.name == file.name
        } catch (e: IOException) {
            false
        } catch (e: SecurityException) {
            false
        }
    }
}
