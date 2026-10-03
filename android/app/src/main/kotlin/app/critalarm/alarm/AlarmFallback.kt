package app.critalarm.alarm

import app.critalarm.sound.AlarmSoundSource

/**
 * What MediaPlayer tries next when it cannot open [failed]: the bundled
 * default at [defaultAssetPath], or null once the default itself has failed
 * and there is nothing left to try. Pure, so the order is tested on the JVM.
 */
object AlarmFallback {
    fun next(failed: AlarmSoundSource, defaultAssetPath: String): AlarmSoundSource? {
        val default = AlarmSoundSource.Asset(defaultAssetPath)
        return if (failed == default) null else default
    }
}
