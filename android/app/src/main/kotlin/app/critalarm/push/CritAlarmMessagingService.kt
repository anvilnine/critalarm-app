package app.critalarm.push

import android.util.Log
import app.critalarm.MainActivity
import app.critalarm.storage.BootMirror
import app.critalarm.storage.BootStorage
import app.critalarm.storage.PushEventLog
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

/** Every push lands here and is handed straight to [PushRouter]. */
class CritAlarmMessagingService : FirebaseMessagingService() {
    override fun onNewToken(token: String) {
        super.onNewToken(token)
        // The registry in Dart (api.md §4.2) owns the relay call. Leave the
        // token where it will find it: on the next launch if the app is not
        // running, or right away through the token-refresh stream if it is.
        if (PushEventLog(this).recordPendingToken(token)) {
            Log.i(TAG, "fcm_token_rotated")
        } else {
            // Before the first unlock. Dart reads the current token on its
            // next launch anyway.
            Log.i(TAG, "fcm_token_rotated_locked")
        }
    }

    override fun onMessageReceived(message: RemoteMessage) {
        Log.i(TAG, "fcm_received unlocked=${BootStorage.isUnlocked(this)}")
        // Keeps the copy the ring reads before an unlock in step with Dart.
        BootMirror.sync(this)
        val alarmIncidentId = PushRouter(this).route(message.data)
        // The notification goes up first; this is only so an app that is
        // already open catches up. With no engine attached it does nothing,
        // which is the usual case here. A push that rang names its incident.
        MainActivity.notifyPushReceived(alarmIncidentId)
    }

    companion object {
        private const val TAG = "CritAlarmFcm"
    }
}
