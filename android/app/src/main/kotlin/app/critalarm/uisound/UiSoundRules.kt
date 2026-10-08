package app.critalarm.uisound

/** The rules of the interface sound player, with no Android in them. */
object UiSoundRules {
    /** The only folder a sound may come from. The alarm sounds live elsewhere. */
    const val FOLDER = "assets/ui_sounds/"

    private val fileName = Regex("^[a-z0-9_]+\\.m4a$")

    /**
     * Whether [asset] is one of the interface sounds. Anything else is
     * refused, so this player can never be handed an alarm sound.
     */
    fun isInterfaceSound(asset: String?): Boolean {
        if (asset == null || !asset.startsWith(FOLDER)) return false
        return fileName.matches(asset.removePrefix(FOLDER))
    }

    /**
     * Whether the phone's ringer lets an interface sound play. [ringerMode]
     * and [normalMode] are `AudioManager` ringer modes. A phone set to silent
     * or to vibrate stays quiet, the same as the silent switch on an iPhone.
     */
    fun ringerAllows(ringerMode: Int, normalMode: Int): Boolean = ringerMode == normalMode

    /** The most copies of one sound that may play at once, whatever is asked. */
    const val MAX_VOICES = 4

    /** How many copies the caller may have. Nothing asked means one. */
    fun voices(asked: Int?): Int = (asked ?: 1).coerceIn(1, MAX_VOICES)

    /**
     * Which of the sounds now [playing], oldest first, must stop before
     * [asset] starts with [voices] copies allowed.
     *
     * With one voice everything stops: a new sound replaces the old one.
     * With more, the newest copies of the same sound are left to finish, so
     * that with the new one there are never more than [voices]. A different
     * sound always stops.
     */
    fun toStop(playing: List<String>, asset: String, voices: Int): List<Int> {
        val same = playing.indices.filter { playing[it] == asset }
        val kept = same.takeLast(voices(voices) - 1).toSet()
        return playing.indices.filter { it !in kept }
    }
}
