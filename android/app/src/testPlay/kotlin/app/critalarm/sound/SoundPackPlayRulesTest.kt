package app.critalarm.sound

import com.google.android.play.core.assetpacks.model.AssetPackErrorCode
import com.google.android.play.core.assetpacks.model.AssetPackStatus
import org.junit.Assert.assertEquals
import org.junit.Test

/** Play flavor only: the words Play's pack statuses map to. */
class SoundPackPlayRulesTest {
    @Test
    fun playStatusesMapToTheWordsDartReads() {
        val ok = AssetPackErrorCode.NO_ERROR
        assertEquals("downloaded", SoundPackPlayRules.stateName(AssetPackStatus.COMPLETED, ok, false))
        assertEquals("downloaded", SoundPackPlayRules.stateName(AssetPackStatus.UNKNOWN, ok, true))
        assertEquals("downloading", SoundPackPlayRules.stateName(AssetPackStatus.PENDING, ok, false))
        assertEquals("downloading", SoundPackPlayRules.stateName(AssetPackStatus.DOWNLOADING, ok, false))
        assertEquals("downloading", SoundPackPlayRules.stateName(AssetPackStatus.TRANSFERRING, ok, false))
        assertEquals("waiting_for_wifi", SoundPackPlayRules.stateName(AssetPackStatus.WAITING_FOR_WIFI, ok, false))
        assertEquals("needs_confirmation", SoundPackPlayRules.stateName(AssetPackStatus.REQUIRES_USER_CONFIRMATION, ok, false))
        assertEquals("not_downloaded", SoundPackPlayRules.stateName(AssetPackStatus.NOT_INSTALLED, ok, false))
        assertEquals("not_downloaded", SoundPackPlayRules.stateName(AssetPackStatus.CANCELED, ok, false))
        assertEquals("failed", SoundPackPlayRules.stateName(AssetPackStatus.FAILED, AssetPackErrorCode.NETWORK_ERROR, false))
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
            assertEquals("unavailable", SoundPackPlayRules.stateName(AssetPackStatus.FAILED, code, false))
        }
    }
}
