package app.critalarm.sound

import android.content.SharedPreferences
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

/**
 * What rings while own sounds are locked. The same cases as
 * test/core/sound/own_sound_rule_test.dart, run on the resolver the alarm
 * service calls.
 */
class AlarmSoundOwnLockTest {
    @get:Rule
    val temp = TemporaryFolder()

    private val siren = "classic_siren" to AlarmSoundSource.Asset("assets/sounds/classic_siren.ogg")
    private val beep = "pager_beep" to AlarmSoundSource.Asset("assets/sounds/pager_beep.ogg")
    private val pack = "pack_library_boxing_bell"

    private lateinit var sounds: File
    private lateinit var own: File
    private lateinit var otherOwn: File

    /** Both own files are on disk, so only the lock can turn them away. */
    private val paths: (String) -> String? = {
        when (it) {
            "user_1" -> own.path
            "user_2" -> otherOwn.path
            else -> null
        }
    }

    private fun rings(ids: List<String>, ownLocked: Boolean) =
        AlarmSoundStore.resolveChain(sounds, ids, ownLocked, paths)

    @Before
    fun setUp() {
        sounds = temp.newFolder("sounds")
        own = File(sounds, "user_1.wav").apply { writeBytes(byteArrayOf(1)) }
        otherOwn = File(sounds, "user_2.wav").apply { writeBytes(byteArrayOf(1)) }
    }

    @Test
    fun openAnOwnTopicSoundRings() {
        assertEquals("user_1" to AlarmSoundSource.Imported(own.path), rings(listOf("user_1", "pager_beep"), false))
    }

    @Test
    fun lockedAnOwnTopicSoundRingsTheBuiltInDefault() {
        assertEquals(beep, rings(listOf("user_1", "pager_beep"), true))
    }

    @Test
    fun openAnOwnDefaultRings() {
        assertEquals("user_1" to AlarmSoundSource.Imported(own.path), rings(listOf("user_1"), false))
    }

    @Test
    fun lockedAnOwnDefaultRingsTheClassicSiren() {
        assertEquals(siren, rings(listOf("user_1"), true))
    }

    @Test
    fun lockedOwnOnTheTopicAndAsTheDefaultRingsTheClassicSiren() {
        assertEquals(siren, rings(listOf("user_1", "user_2"), true))
        assertEquals(
            "user_1" to AlarmSoundSource.Imported(own.path),
            rings(listOf("user_1", "user_2"), false),
        )
    }

    @Test
    fun aBuiltInTopicSoundKeepsRingingOverALockedOwnDefault() {
        assertEquals(beep, rings(listOf("pager_beep", "user_1"), true))
    }

    @Test
    fun noOwnSoundAnywhereRingsTheSameLockedOrOpen() {
        for (locked in listOf(true, false)) {
            assertEquals(beep, rings(listOf("pager_beep", "classic_siren"), locked))
            assertEquals(siren, rings(listOf("classic_siren"), locked))
        }
    }

    @Test
    fun aStorePackSoundRingsWhileOwnSoundsAreLocked() {
        File(sounds, "$pack.ogg").writeBytes(byteArrayOf(1))
        assertEquals(pack, rings(listOf(pack, "pager_beep"), true).first)
        // A locked own topic sound falls to a pack default.
        assertEquals(pack, rings(listOf("user_1", pack), true).first)
    }

    @Test
    fun lockedAnOwnTopicSoundOverAMissingPackDefaultRingsTheClassicSiren() {
        assertEquals(siren, rings(listOf("user_1", pack), true))
    }

    @Test
    fun lockedNeverRingsAnOwnSoundWhateverIsSaved() {
        val ids = listOf("user_1", "user_2", "pager_beep", pack, "classic_siren")
        val ownSources = listOf(AlarmSoundSource.Imported(own.path), AlarmSoundSource.Imported(otherOwn.path))
        for (topic in ids + listOf<String?>(null)) {
            for (default in ids) {
                val picked = rings(listOfNotNull(topic, default), true)
                assertFalse("$topic $default", AlarmSoundStore.isOwnSound(picked.first))
                assertFalse("$topic $default", picked.second in ownSources)
            }
        }
    }

    @Test
    fun anEmptyChainStillRingsTheClassicSiren() {
        assertEquals(siren, rings(emptyList(), true))
        assertEquals(siren, rings(emptyList(), false))
    }

    @Test
    fun aFlagThatIsMissingOrUnreadableIsNotLocked() {
        assertTrue(AlarmSoundStore.readOwnLocked { true })
        assertFalse(AlarmSoundStore.readOwnLocked { false })
        // SharedPreferences throws this when the key holds another type.
        assertFalse(AlarmSoundStore.readOwnLocked { throw ClassCastException("not a boolean") })
    }

    @Test
    fun theOwnPrefixIsTheOneImportsUse() {
        assertEquals("user_", AlarmSoundStore.OWN_PREFIX)
        assertTrue(AlarmSoundStore.isOwnSound("user_1700000000000000"))
        assertFalse(AlarmSoundStore.isOwnSound("classic_siren"))
        assertFalse(AlarmSoundStore.isOwnSound(pack))
    }

    /** The last step of every chain is a file that ships in the apk. */
    @Test
    fun theClassicSirenIsBundled() {
        val assetPath = AlarmSoundStore.assetPathFor(AlarmSoundStore.FALLBACK_ID)
        var dir: File? = File("").absoluteFile
        var found = false
        while (dir != null && !found) {
            found = File(dir, "pubspec.yaml").exists() && File(dir, assetPath).exists()
            dir = dir.parentFile
        }
        assertTrue("$assetPath is not in the Flutter project", found)
    }

    // The same, read from preferences under the names Dart writes. A key
    // spelled differently on this side would read as "never locked".

    /** `FlutterSharedPreferences` as the alarm service finds it. */
    private fun prefs(
        topicSound: String? = "user_1",
        default: String? = "pager_beep",
        ownLocked: Any? = null,
    ): SharedPreferences {
        val values = mutableMapOf<String, Any?>(
            "flutter.alarm_sound_user_list" to
                """[{"id":"user_1","path":"${own.path}"},{"id":"user_2","path":"${otherOwn.path}"}]""",
        )
        if (default != null) values["flutter.alarm_sound_default"] = default
        if (topicSound != null) values["flutter.alarm_sound_per_topic"] = """{"prod":"$topicSound"}"""
        if (ownLocked != null) values["flutter.alarm_sound_own_locked"] = ownLocked
        return FakePrefs(values)
    }

    private fun ringsFor(prefs: SharedPreferences, topic: String?) =
        AlarmSoundStore.resolveFromPrefs(prefs, sounds, topic)

    @Test
    fun theFlagUnderTheKeyDartWritesLocksATopicOnAnOwnSound() {
        val choice = ringsFor(prefs(ownLocked = true), "prod")
        assertEquals(beep, choice.picked)
        assertEquals("user_1", choice.wanted)
        assertTrue(choice.ownLocked)
    }

    @Test
    fun theSamePrefsWithTheFlagFalseRingTheOwnSound() {
        val choice = ringsFor(prefs(ownLocked = false), "prod")
        assertEquals("user_1" to AlarmSoundSource.Imported(own.path), choice.picked)
        assertFalse(choice.ownLocked)
    }

    @Test
    fun theSamePrefsWithNoFlagRingTheOwnSound() {
        val choice = ringsFor(prefs(), "prod")
        assertEquals("user_1" to AlarmSoundSource.Imported(own.path), choice.picked)
        assertFalse(choice.ownLocked)
    }

    @Test
    fun theFlagLocksAnOwnDefaultForAPushWithNoTopic() {
        val locked = prefs(topicSound = null, default = "user_2", ownLocked = true)
        assertEquals(siren, ringsFor(locked, null).picked)
        assertEquals(siren, ringsFor(locked, "staging").picked)
        val open = prefs(topicSound = null, default = "user_2", ownLocked = false)
        assertEquals("user_2" to AlarmSoundSource.Imported(otherOwn.path), ringsFor(open, null).picked)
    }

    @Test
    fun aFlagStoredAsAStringIsNotLockedAndTheAlarmStillResolves() {
        val choice = ringsFor(prefs(ownLocked = "true"), "prod")
        assertFalse(choice.ownLocked)
        assertEquals("user_1" to AlarmSoundSource.Imported(own.path), choice.picked)
    }

    @Test
    fun emptyPreferencesRingTheClassicSirenLockedOrNot() {
        assertEquals(siren, ringsFor(FakePrefs(mutableMapOf()), "prod").picked)
        assertEquals(
            siren,
            ringsFor(FakePrefs(mutableMapOf("flutter.alarm_sound_own_locked" to true)), null).picked,
        )
    }

    /** Read-only preferences over a map, typed the way Android's are. */
    private class FakePrefs(private val values: Map<String, Any?>) : SharedPreferences {
        override fun getAll(): MutableMap<String, *> = values.toMutableMap()

        override fun getString(key: String?, defValue: String?): String? =
            if (values.containsKey(key)) values[key] as String? else defValue

        // Throws ClassCastException for another type, as the real one does.
        override fun getBoolean(key: String?, defValue: Boolean): Boolean =
            if (values.containsKey(key)) values[key] as Boolean else defValue

        override fun getStringSet(key: String?, defValues: MutableSet<String>?): MutableSet<String>? = defValues

        override fun getInt(key: String?, defValue: Int): Int = defValue

        override fun getLong(key: String?, defValue: Long): Long = defValue

        override fun getFloat(key: String?, defValue: Float): Float = defValue

        override fun contains(key: String?): Boolean = values.containsKey(key)

        override fun edit(): SharedPreferences.Editor = throw UnsupportedOperationException()

        override fun registerOnSharedPreferenceChangeListener(
            listener: SharedPreferences.OnSharedPreferenceChangeListener?,
        ) = Unit

        override fun unregisterOnSharedPreferenceChangeListener(
            listener: SharedPreferences.OnSharedPreferenceChangeListener?,
        ) = Unit
    }
}
