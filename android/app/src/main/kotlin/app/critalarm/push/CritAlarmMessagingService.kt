package app.critalarm.push

import android.util.Log
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
        PushEventLog(this).recordPendingToken(token)
        Log.i(TAG, "fcm_token_rotated")
    }

    override fun onMessageReceived(message: RemoteMessage) {
        Log.i(TAG, "fcm_received")
        PushRouter(this).route(message.data)
    }

    companion object {
        private const val TAG = "CritAlarmFcm"
    }
}
