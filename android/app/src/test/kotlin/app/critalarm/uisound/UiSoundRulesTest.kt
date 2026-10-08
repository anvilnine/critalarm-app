package app.critalarm.uisound

import org.junit.Assert.assertEquals
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

    @Test
    fun `one voice replaces everything that plays`() {
        val a = "assets/ui_sounds/ui_open.m4a"
        val b = "assets/ui_sounds/ui_tick.m4a"
        assertEquals(emptyList<Int>(), UiSoundRules.toStop(emptyList(), a, 1))
        assertEquals(listOf(0), UiSoundRules.toStop(listOf(a), a, 1))
        assertEquals(listOf(0, 1), UiSoundRules.toStop(listOf(a, b), b, 1))
    }

    @Test
    fun `a sound with three voices overlaps itself and drops the oldest`() {
        val line = "assets/ui_sounds/ui_line.m4a"
        assertEquals(emptyList<Int>(), UiSoundRules.toStop(listOf(line), line, 3))
        assertEquals(emptyList<Int>(), UiSoundRules.toStop(listOf(line, line), line, 3))
        // Five in a row: from the fourth on, the oldest makes room.
        assertEquals(listOf(0), UiSoundRules.toStop(listOf(line, line, line), line, 3))
    }

    @Test
    fun `a different sound is cut off even when the new one may overlap`() {
        val line = "assets/ui_sounds/ui_line.m4a"
        val print = "assets/ui_sounds/ui_print.m4a"
        assertEquals(listOf(0), UiSoundRules.toStop(listOf(print), line, 3))
        assertEquals(listOf(1), UiSoundRules.toStop(listOf(line, print, line), line, 3))
    }

    @Test
    fun `the voices asked for are kept between one and the cap`() {
        assertEquals(1, UiSoundRules.voices(null))
        assertEquals(1, UiSoundRules.voices(0))
        assertEquals(1, UiSoundRules.voices(-3))
        assertEquals(3, UiSoundRules.voices(3))
        assertEquals(UiSoundRules.MAX_VOICES, UiSoundRules.voices(99))
    }
}
