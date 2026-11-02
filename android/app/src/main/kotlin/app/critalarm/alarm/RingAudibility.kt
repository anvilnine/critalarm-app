package app.critalarm.alarm

import android.app.NotificationManager
import android.content.Context
import android.content.SharedPreferences
import android.media.AudioManager

/**
 * Whether a ring could be heard, as the phone reports it a moment after the
 * sound started.
 *
 * A setup test used to say "It works" while the alarm played at volume 0
 * under total-silence Do Not Disturb (W4). The test result reads this
 * record, so a muted ring never ticks "This phone rang".
 *
 * Only reads the phone's settings. Nothing here changes the volume or Do Not
 * Disturb.
 */
object RingAudibility {
    const val PREFS = "critalarm_ring_audibility"
    private const val MUTED_KEY = "muted_incident_ids"

    /** How many muted ids are kept. A test reads the last one or two. */
    const val MAX_MUTED = 20

    /**
     * True when the alarm stream can be heard: it is not at 0, not muted,
     * and Do Not Disturb is not on total silence, which silences alarms too.
     */
    fun audible(alarmVolume: Int, streamMuted: Boolean, interruptionFilter: Int): Boolean =
        alarmVolume > 0 && !streamMuted && interruptionFilter != NotificationManager.INTERRUPTION_FILTER_NONE

    fun readNow(context: Context): Boolean {
        val audio = context.getSystemService(AudioManager::class.java) ?: return true
        val notifications = context.getSystemService(NotificationManager::class.java) ?: return true
        return audible(
            alarmVolume = audio.getStreamVolume(AudioManager.STREAM_ALARM),
            streamMuted = audio.isStreamMute(AudioManager.STREAM_ALARM),
            interruptionFilter = notifications.currentInterruptionFilter,
        )
    }

    /** Writes [audible] for every id in [incidentIds]. */
    fun record(prefs: SharedPreferences, incidentIds: Collection<String>, audible: Boolean) {
        val muted = mutedAfter(prefs.getStringSet(MUTED_KEY, emptySet()).orEmpty(), incidentIds, audible)
        prefs.edit().putStringSet(MUTED_KEY, muted).apply()
    }

    fun wasMuted(prefs: SharedPreferences, incidentId: String): Boolean =
        prefs.getStringSet(MUTED_KEY, emptySet()).orEmpty().contains(incidentId)

    /** The muted set after a check: added when muted, dropped when heard, capped. */
    internal fun mutedAfter(before: Set<String>, incidentIds: Collection<String>, audible: Boolean): Set<String> {
        val next = if (audible) before - incidentIds.toSet() else before + incidentIds
        return if (next.size <= MAX_MUTED) next else next.toList().takeLast(MAX_MUTED).toSet()
    }
}
