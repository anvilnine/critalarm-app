package app.critalarm.alarm

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RingWindowRuleTest {
    @Test
    fun theSwitchDecidesTheBrightness() {
        assertEquals(1f, RingWindowRule.brightness(switchOn = true))
        // Off: the window keeps the phone's own brightness.
        assertNull(RingWindowRule.brightness(switchOn = false))
    }

    @Test
    fun onlyAReleaseForTheRingingIncidentEndsIt() {
        assertTrue(RingWindowRule.ends(ringingFor = "inc_a", released = "inc_a"))
        assertTrue(RingWindowRule.ends(ringingFor = "inc_a", released = null))
        assertFalse(RingWindowRule.ends(ringingFor = "inc_a", released = "inc_b"))
        assertFalse(RingWindowRule.ends(ringingFor = null, released = "inc_a"))
    }

    @Test
    fun volumeDownIsSwallowedOnlyWhileTheAlarmScreenRings() {
        assertTrue(RingWindowRule.swallowsKey(isVolumeDown = true, screenRings = true, alarmRings = true))
        assertFalse(RingWindowRule.swallowsKey(isVolumeDown = false, screenRings = true, alarmRings = true))
        assertFalse(RingWindowRule.swallowsKey(isVolumeDown = true, screenRings = false, alarmRings = true))
        assertFalse(RingWindowRule.swallowsKey(isVolumeDown = true, screenRings = true, alarmRings = false))
    }

    @Test
    fun theSwitchKeysMatchWhatDartWrites() {
        val dart = File("../../lib/features/settings/data/repositories/shared_prefs_ring_settings_repository.dart").readText()
        for (key in listOf(RingSwitches.BRIGHT_SCREEN_KEY, RingSwitches.VIBRATE_KEY)) {
            // The shared_preferences plugin puts "flutter." in front of every key.
            val dartKey = key.removePrefix("flutter.")
            assertTrue("Dart does not write '$dartKey'", dart.contains("'$dartKey'"))
        }
    }
}
