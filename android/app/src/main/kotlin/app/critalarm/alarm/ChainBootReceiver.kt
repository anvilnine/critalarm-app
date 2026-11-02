package app.critalarm.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.util.Log
import app.critalarm.storage.BootMirror
import app.critalarm.storage.BootStorage
import app.critalarm.storage.IncidentDeliveryStore

/**
 * Sets every open incident's ring chain again after a reboot, which drops
 * every alarm the phone held.
 *
 * `LOCKED_BOOT_COMPLETED` comes before anyone unlocks the phone, so a phone
 * that restarts overnight still rings. `BOOT_COMPLETED` comes after the
 * unlock and does the same only when the locked one did not run for this
 * boot ([BootRearmRule]). Runs before the unlock, so everything it reads is in
 * device-protected storage ([BootStorage]).
 */
class ChainBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val boot = BootRearmRule.Boot.fromAction(intent.action) ?: return
        // The copy of Dart's preferences, fresh before anything reads it.
        if (boot == BootRearmRule.Boot.UNLOCKED) BootMirror.sync(context)
        val store = IncidentDeliveryStore(context)
        val bootCount = bootCount(context)
        if (!BootRearmRule.runs(boot, bootCount, store.rearmedBootCount())) {
            Log.i(TAG, "boot_rearm_skipped boot=${boot.name.lowercase()} reason=already_done")
            return
        }
        val now = System.currentTimeMillis()
        val result = AlarmChain.of(context).rearmAfterBoot(now)
        result.windowOver.forEach { IncidentRearm.endRingWindow(context, it) }
        bootCount?.let(store::rememberRearmedBoot)
        Log.i(
            TAG,
            "boot_rearm_done boot=${boot.name.lowercase()} chains=${result.firstSlotByIncident.size} " +
                "window_over=${result.windowOver.size} unlocked=${BootStorage.isUnlocked(context)}",
        )
    }

    private fun bootCount(context: Context): Int? = runCatching {
        Settings.Global.getInt(context.contentResolver, Settings.Global.BOOT_COUNT, -1)
    }.getOrNull()?.takeIf { it >= 0 }

    private companion object {
        const val TAG = "CritAlarmAlarm"
    }
}

/** Whether a boot broadcast sets the chains again. Pure. */
object BootRearmRule {
    enum class Boot {
        /** `LOCKED_BOOT_COMPLETED`: before the first unlock. */
        LOCKED,

        /** `BOOT_COMPLETED`: after it. */
        UNLOCKED,
        ;

        companion object {
            fun fromAction(action: String?): Boot? = when (action) {
                Intent.ACTION_LOCKED_BOOT_COMPLETED -> LOCKED
                Intent.ACTION_BOOT_COMPLETED -> UNLOCKED
                else -> null
            }
        }
    }

    /**
     * The locked boot always runs: it is the first word of a new boot. The
     * unlocked one runs unless the locked one already ran for the same boot
     * count. With no boot count to compare, it runs: setting a chain replaces
     * the old one, so a second run costs nothing but the work.
     */
    fun runs(boot: Boot, bootCount: Int?, rearmedBootCount: Int?): Boolean = when (boot) {
        Boot.LOCKED -> true
        Boot.UNLOCKED -> bootCount == null || bootCount != rearmedBootCount
    }
}
