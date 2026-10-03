package app.critalarm.sound

import app.critalarm.alarm.AlarmFallback
import com.google.android.play.core.assetpacks.model.AssetPackErrorCode
import com.google.android.play.core.assetpacks.model.AssetPackStatus
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

class SoundPackRulesTest {
    @get:Rule
    val temp = TemporaryFolder()

    private val siren = AlarmSoundSource.Asset("assets/sounds/classic_siren.ogg")
    private val id = "pack_library_boxing_bell"

    private fun packWith(vararg ids: String): File {
        val pack = temp.newFolder("pack")
        val sounds = File(pack, "sounds").apply { mkdirs() }
        for (soundId in ids) File(sounds, "$soundId.ogg").writeBytes(byteArrayOf(1, 2, 3, 4))
        return pack
    }

    @Test
    fun installCopiesEachSoundIntoTheSoundsFolder() {
        val pack = packWith(id, "pack_library_buzzer_1")
        val sounds = temp.newFolder("sounds")
        val installed = SoundPackRules.install(pack, sounds, listOf(id, "pack_library_buzzer_1"))
        assertEquals(setOf(id, "pack_library_buzzer_1"), installed.keys)
        assertEquals(File(sounds, "$id.ogg").path, installed[id])
        assertTrue(SoundPackRules.isInstalled(sounds, id))
        assertFalse(File(sounds, "$id.ogg.part").exists())
    }

    @Test
    fun installSkipsWhatThePackDoesNotHold() {
        val pack = packWith(id)
        val sounds = temp.newFolder("sounds")
        val installed = SoundPackRules.install(pack, sounds, listOf(id, "pack_library_missing"))
        assertEquals(setOf(id), installed.keys)
    }

    @Test
    fun installRefusesIdsThatCouldLeaveTheFolder() {
        val pack = packWith(id)
        val sounds = temp.newFolder("sounds")
        val installed = SoundPackRules.install(pack, sounds, listOf("../pack_x", "pack_A", "user_1"))
        assertTrue(installed.isEmpty())
    }

    @Test
    fun installIsSafeToRepeat() {
        val pack = packWith(id)
        val sounds = temp.newFolder("sounds")
        SoundPackRules.install(pack, sounds, listOf(id))
        val again = SoundPackRules.install(pack, sounds, listOf(id))
        assertEquals(setOf(id), again.keys)
    }

    @Test
    fun anEmptyCopyDoesNotCountAsInstalled() {
        val sounds = temp.newFolder("sounds")
        File(sounds, "$id.ogg").writeBytes(byteArrayOf())
        assertFalse(SoundPackRules.isInstalled(sounds, id))
    }

    @Test
    fun anInstalledPackSoundRingsFromItsCopy() {
        val sounds = temp.newFolder("sounds")
        File(sounds, "$id.ogg").writeBytes(byteArrayOf(1))
        val resolved = AlarmSoundStore.resolveIn(sounds, id) { null }
        assertEquals(AlarmSoundSource.Imported(File(sounds, "$id.ogg").path), resolved.source)
        assertFalse(resolved.fellBack)
    }

    @Test
    fun aMissingPackSoundRingsTheClassicSiren() {
        val sounds = temp.newFolder("sounds")
        val resolved = AlarmSoundStore.resolveIn(sounds, id) { null }
        assertEquals(siren, resolved.source)
        assertTrue(resolved.fellBack)
    }

    @Test
    fun anEmptyPackSoundRingsTheClassicSiren() {
        val sounds = temp.newFolder("sounds")
        File(sounds, "$id.ogg").writeBytes(byteArrayOf())
        assertEquals(siren, AlarmSoundStore.resolveIn(sounds, id) { null }.source)
    }

    @Test
    fun aPackSoundThatWillNotPlayFallsBackToTheClassicSiren() {
        // The file is there but MediaPlayer cannot open it: AlarmPlayer asks
        // AlarmFallback what to try next.
        val path = File(temp.newFolder("sounds"), "$id.ogg").path
        assertEquals(siren, AlarmFallback.next(AlarmSoundSource.Imported(path), siren.assetPath))
        assertNull(AlarmFallback.next(siren, siren.assetPath))
    }

    @Test
    fun bundledAndUserSoundsResolveAsBefore() {
        val sounds = temp.newFolder("sounds")
        assertEquals(
            AlarmSoundSource.Asset("assets/sounds/pager_beep.ogg"),
            AlarmSoundStore.resolveIn(sounds, "pager_beep") { null }.source,
        )
        val user = File(sounds, "user_1.wav").apply { writeBytes(byteArrayOf(1)) }
        assertEquals(
            AlarmSoundSource.Imported(user.path),
            AlarmSoundStore.resolveIn(sounds, "user_1") { user.path }.source,
        )
        assertEquals(siren, AlarmSoundStore.resolveIn(sounds, "user_2") { null }.source)
    }

    @Test
    fun playStatusesMapToTheWordsDartReads() {
        val ok = AssetPackErrorCode.NO_ERROR
        assertEquals("downloaded", SoundPackRules.stateName(AssetPackStatus.COMPLETED, ok, false))
        assertEquals("downloaded", SoundPackRules.stateName(AssetPackStatus.UNKNOWN, ok, true))
        assertEquals("downloading", SoundPackRules.stateName(AssetPackStatus.PENDING, ok, false))
        assertEquals("downloading", SoundPackRules.stateName(AssetPackStatus.DOWNLOADING, ok, false))
        assertEquals("downloading", SoundPackRules.stateName(AssetPackStatus.TRANSFERRING, ok, false))
        assertEquals("waiting_for_wifi", SoundPackRules.stateName(AssetPackStatus.WAITING_FOR_WIFI, ok, false))
        assertEquals("needs_confirmation", SoundPackRules.stateName(AssetPackStatus.REQUIRES_USER_CONFIRMATION, ok, false))
        assertEquals("not_downloaded", SoundPackRules.stateName(AssetPackStatus.NOT_INSTALLED, ok, false))
        assertEquals("not_downloaded", SoundPackRules.stateName(AssetPackStatus.CANCELED, ok, false))
        assertEquals("failed", SoundPackRules.stateName(AssetPackStatus.FAILED, AssetPackErrorCode.NETWORK_ERROR, false))
    }

    @Test
    fun aSideloadedBuildReportsThePackUnavailable() {
        for (code in listOf(
            AssetPackErrorCode.APP_UNAVAILABLE,
            AssetPackErrorCode.PACK_UNAVAILABLE,
            AssetPackErrorCode.API_NOT_AVAILABLE,
            AssetPackErrorCode.UNRECOGNIZED_INSTALLATION,
            AssetPackErrorCode.APP_NOT_OWNED,
        )) {
            assertEquals("unavailable", SoundPackRules.stateName(AssetPackStatus.FAILED, code, false))
        }
    }

    @Test
    fun progressIsAShareOfTheTotal() {
        assertNull(SoundPackRules.progress(0, 0))
        assertEquals(0.5, SoundPackRules.progress(50, 100)!!, 1e-9)
        assertEquals(1.0, SoundPackRules.progress(150, 100)!!, 1e-9)
    }

    @Test
    fun aTopicWhosePackSoundIsGoneRingsTheDefault() {
        val sounds = temp.newFolder("sounds")
        val picked = AlarmSoundStore.resolveChain(sounds, listOf(id, "pager_beep")) { null }
        assertEquals("pager_beep" to AlarmSoundSource.Asset("assets/sounds/pager_beep.ogg"), picked)
    }

    @Test
    fun aDefaultThatIsAlsoGoneRingsTheClassicSiren() {
        val sounds = temp.newFolder("sounds")
        val picked = AlarmSoundStore.resolveChain(sounds, listOf(id, "pack_library_buzzer_1")) { null }
        assertEquals("classic_siren" to siren, picked)
    }

    @Test
    fun aTopicWhosePackSoundIsThereRingsIt() {
        val sounds = temp.newFolder("sounds")
        File(sounds, "$id.ogg").writeBytes(byteArrayOf(1))
        val picked = AlarmSoundStore.resolveChain(sounds, listOf(id, "pager_beep")) { null }
        assertEquals(id, picked.first)
    }
}
