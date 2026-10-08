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
}
