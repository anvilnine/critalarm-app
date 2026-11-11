package app.critalarm.sound

import app.critalarm.storage.BootMigration
import app.critalarm.storage.InMemoryPreferences
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

/**
 * Before the first unlock after a reboot only the apk can be read, so only a
 * bundled sound rings. A pack sound or an own sound falls back, even with its
 * file on disk, and the chain still ends at Endless climb.
 */
class AlarmSoundBeforeUnlockTest {
    @get:Rule
    val temp = TemporaryFolder()

    // What every chain ends at: Endless climb.
    private val fallback = "loop_ascend" to AlarmSoundSource.Asset("assets/sounds/loop_ascend.ogg")
    private val beep = "submarine_dive_horn" to AlarmSoundSource.Asset("assets/sounds/submarine_dive_horn.ogg")
    private val pack = "pack_library_boxing_bell"

    private lateinit var sounds: File
    private lateinit var own: File

    @Before
    fun setUp() {
        sounds = temp.newFolder("sounds")
        own = File(sounds, "user_1.wav").apply { writeBytes(byteArrayOf(1)) }
        SoundPackRules.installedFile(sounds, pack).writeBytes(byteArrayOf(1))
    }

    private fun prefs(default: String, topicSound: String? = null) = InMemoryPreferences().apply {
        val edit = edit()
        BootMigration.putValue(edit, "flutter.alarm_sound_default", default)
        topicSound?.let { BootMigration.putValue(edit, "flutter.alarm_sound_per_topic", """{"prod":"$it"}""") }
        BootMigration.putValue(
            edit,
            "flutter.alarm_sound_user_list",
            """[{"id":"user_1","path":"${own.path}"}]""",
        )
        edit.commit()
    }

    private fun ringsFor(default: String, topicSound: String? = null, bundledOnly: Boolean) =
        AlarmSoundStore.resolveFromPrefs(prefs(default, topicSound), sounds, "prod", bundledOnly = bundledOnly).picked

    @Test
    fun `a pack sound rings once the phone is unlocked`() {
        val (id, source) = ringsFor(default = pack, bundledOnly = false)
        assertEquals(pack, id)
        assertTrue(source is AlarmSoundSource.Imported)
    }

    @Test
    fun `a pack sound falls back to Endless climb before the unlock`() {
        assertEquals(fallback, ringsFor(default = pack, bundledOnly = true))
    }

    @Test
    fun `an own sound falls back to Endless climb before the unlock`() {
        assertEquals(fallback, ringsFor(default = "user_1", bundledOnly = true))
    }

    @Test
    fun `a topic on a pack sound rings the bundled default before the unlock`() {
        assertEquals(beep, ringsFor(default = "submarine_dive_horn", topicSound = pack, bundledOnly = true))
    }

    @Test
    fun `a bundled choice rings as picked before the unlock`() {
        assertEquals(beep, ringsFor(default = "classic_siren", topicSound = "submarine_dive_horn", bundledOnly = true))
    }

    @Test
    fun `only sounds in the apk count as bundled`() {
        assertTrue(AlarmSoundStore.isBundled("classic_siren"))
        assertFalse(AlarmSoundStore.isBundled(pack))
        assertFalse(AlarmSoundStore.isBundled("user_1"))
    }
}
