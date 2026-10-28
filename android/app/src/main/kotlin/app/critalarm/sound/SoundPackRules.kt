package app.critalarm.sound

import java.io.File

/**
 * The parts of the sound packs that need no Play Store and no Android, so the
 * JVM tests can check them. Every store flavor has them: the alarm reads an
 * installed pack sound through here. Play's status words are in
 * `SoundPackPlayRules`, in the play source set.
 *
 * A pack sound is copied out of the pack into the same folder imported sounds
 * live in, under its id. From then on it rings the way an imported sound does,
 * and the pack itself is never read at ring time.
 */
object SoundPackRules {
    /** Every pack sound id starts with this. Ids never change once shipped. */
    const val SOUND_ID_PREFIX = "pack_"

    /** Where a pack keeps its sounds, inside the pack's assets folder. */
    const val PACK_SOUNDS_DIR = "sounds"

    fun isPackSound(soundId: String) = soundId.startsWith(SOUND_ID_PREFIX)

    /** The copy the alarm plays, in the app's own sound folder. */
    fun installedFile(soundsDir: File, soundId: String) = File(soundsDir, "$soundId.ogg")

    /**
     * Ids and pack names come from Dart. Anything that could step out of a
     * folder is refused before it is used in a path.
     */
    fun isSafeName(name: String) = name.matches(Regex("[a-z0-9_]{1,64}"))

    /** A copy counts only if it holds bytes. A zero-length file never rings. */
    fun isInstalled(soundsDir: File, soundId: String): Boolean {
        val file = installedFile(soundsDir, soundId)
        return file.isFile && file.length() > 0
    }

    /**
     * Copies each of [soundIds] from `<packAssetsDir>/sounds/<id>.ogg` into
     * [soundsDir], through a temporary file so a half-written copy is never
     * taken for a sound. Returns id to the installed path, for the ids that
     * made it. Safe to run more than once.
     */
    fun install(packAssetsDir: File, soundsDir: File, soundIds: List<String>): Map<String, String> {
        soundsDir.mkdirs()
        val installed = linkedMapOf<String, String>()
        for (id in soundIds) {
            if (!isSafeName(id) || !isPackSound(id)) continue
            val source = File(File(packAssetsDir, PACK_SOUNDS_DIR), "$id.ogg")
            if (!source.isFile || source.length() == 0L) continue
            val destination = installedFile(soundsDir, id)
            if (destination.isFile && destination.length() == source.length()) {
                installed[id] = destination.path
                continue
            }
            val partial = File(soundsDir, "$id.ogg.part")
            val copied = runCatching {
                source.inputStream().use { input -> partial.outputStream().use(input::copyTo) }
                destination.delete()
                partial.renameTo(destination)
            }.getOrDefault(false)
            if (copied && isInstalled(soundsDir, id)) {
                installed[id] = destination.path
            } else {
                partial.delete()
            }
        }
        return installed
    }

    /** Share of the pack downloaded, 0 to 1, or null before Play knows the size. */
    fun progress(bytesDownloaded: Long, totalBytes: Long): Double? =
        if (totalBytes > 0) (bytesDownloaded.toDouble() / totalBytes).coerceIn(0.0, 1.0) else null
}
