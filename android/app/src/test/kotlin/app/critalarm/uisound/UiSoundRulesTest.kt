package app.critalarm.uisound

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class UiSoundRulesTest {
    @Test
    fun `an interface sound is a plain m4a in its own folder`() {
        assertTrue(UiSoundRules.isInterfaceSound("assets/ui_sounds/ui_open.m4a"))
        assertTrue(UiSoundRules.isInterfaceSound("assets/ui_sounds/ui_pick_yearly.m4a"))
    }

    @Test
    fun `an alarm sound is refused`() {
        assertFalse(UiSoundRules.isInterfaceSound("assets/sounds/classic_siren.ogg"))
        assertFalse(UiSoundRules.isInterfaceSound("assets/sounds/emergency_klaxon.m4a"))
        assertFalse(UiSoundRules.isInterfaceSound("assets/ui_sounds/../sounds/classic_siren.m4a"))
        assertFalse(UiSoundRules.isInterfaceSound("/data/user/0/app.critalarm/files/sounds/user_1.wav"))
    }

    @Test
    fun `nothing and nonsense are refused`() {
        assertFalse(UiSoundRules.isInterfaceSound(null))
        assertFalse(UiSoundRules.isInterfaceSound(""))
        assertFalse(UiSoundRules.isInterfaceSound("assets/ui_sounds/"))
        assertFalse(UiSoundRules.isInterfaceSound("assets/ui_sounds/ui_open.ogg"))
        assertFalse(UiSoundRules.isInterfaceSound("assets/ui_sounds/sub/ui_open.m4a"))
    }

    @Test
    fun `only a ringer set to normal lets a sound play`() {
        // AudioManager: silent 0, vibrate 1, normal 2.
        assertTrue(UiSoundRules.ringerAllows(ringerMode = 2, normalMode = 2))
        assertFalse(UiSoundRules.ringerAllows(ringerMode = 1, normalMode = 2))
        assertFalse(UiSoundRules.ringerAllows(ringerMode = 0, normalMode = 2))
    }
}
