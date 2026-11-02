package app.critalarm.sound

import com.google.android.play.core.assetpacks.model.AssetPackErrorCode
import com.google.android.play.core.assetpacks.model.AssetPackStatus

/**
 * Play's pack statuses as the words Dart reads. Play flavor only, because it
 * needs Play Core. The parts every store shares are in [SoundPackRules].
 */
object SoundPackPlayRules {
    /**
     * Play's status for a pack, as the word Dart reads. [hasLocation] wins:
     * once Play reports a folder, the files are on the device whatever the
     * status says.
     */
    fun stateName(status: Int, errorCode: Int, hasLocation: Boolean): String = when {
        hasLocation || status == AssetPackStatus.COMPLETED -> "downloaded"
        errorCode != AssetPackErrorCode.NO_ERROR && isUnavailable(errorCode) -> "unavailable"
        status == AssetPackStatus.PENDING ||
            status == AssetPackStatus.DOWNLOADING ||
            status == AssetPackStatus.TRANSFERRING -> "downloading"
        status == AssetPackStatus.WAITING_FOR_WIFI -> "waiting_for_wifi"
        status == AssetPackStatus.REQUIRES_USER_CONFIRMATION -> "needs_confirmation"
        status == AssetPackStatus.FAILED -> "failed"
        // CANCELED, NOT_INSTALLED and UNKNOWN all mean "not here, ask again".
        else -> "not_downloaded"
    }

    /**
     * Errors that mean this install can never get the pack: no Play Store API,
     * an app Play did not install (sideloaded, `UNRECOGNIZED_INSTALLATION`),
     * or a pack Play does not know.
     */
    fun isUnavailable(errorCode: Int) = errorCode in setOf(
        AssetPackErrorCode.API_NOT_AVAILABLE,
        AssetPackErrorCode.APP_UNAVAILABLE,
        AssetPackErrorCode.PACK_UNAVAILABLE,
        AssetPackErrorCode.UNRECOGNIZED_INSTALLATION,
        AssetPackErrorCode.APP_NOT_OWNED,
    )
}
