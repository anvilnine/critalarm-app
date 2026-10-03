package app.critalarm.alarm

import app.critalarm.sound.AlarmSoundSource
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AlarmFallbackTest {
    private val default = "assets/sounds/classic_siren.ogg"

    @Test
    fun aBrokenImportFallsBackToTheBundledDefault() {
        assertEquals(
            AlarmSoundSource.Asset(default),
            AlarmFallback.next(AlarmSoundSource.Imported("/data/user_1.mp3"), default),
        )
    }

    @Test
    fun aBrokenBundledSoundFallsBackToTheDefault() {
        assertEquals(
            AlarmSoundSource.Asset(default),
            AlarmFallback.next(AlarmSoundSource.Asset("assets/sounds/pager_beep.ogg"), default),
        )
    }

    @Test
    fun whenTheDefaultFailsThereIsNothingLeft() {
        assertNull(AlarmFallback.next(AlarmSoundSource.Asset(default), default))
    }
}
