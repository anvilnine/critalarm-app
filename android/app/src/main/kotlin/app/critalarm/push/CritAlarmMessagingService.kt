package app.critalarm.push

import android.app.NotificationManager
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat
import app.critalarm.alarm.AlarmForegroundService
import app.critalarm.notifications.AlarmNotificationFactory
import app.critalarm.notifications.StatusNotificationFactory
import app.critalarm.storage.IncidentDeliveryStore
import app.critalarm.storage.NativeConnectionStore
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class CritAlarmMessagingService : FirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) {
        Log.i(TAG, "fcm_received")
        val payload = FcmIncidentPayload.fromData(message.data) ?: return
        if (!NativeConnectionStore(this).matchesCanonicalServer(payload.server)) return
        if (payload.kind == IncidentPushKind.P4) return

        val store = IncidentDeliveryStore(this)
        if (payload.kind == IncidentPushKind.REPEAT && store.isAcknowledged(payload.incidentId)) return
        val alreadyActive = store.isActive(payload.incidentId)
        val reopen = payload.kind == IncidentPushKind.REOPEN
        store.activate(payload.incidentId, reopen = reopen)

        if (!alreadyActive || reopen) {
            val notification = AlarmNotificationFactory.create(this, payload)
            getSystemService(NotificationManager::class.java).notify(
                payload.incidentId,
                AlarmNotificationFactory.notificationId(payload.incidentId),
                notification,
            )
            getSystemService(NotificationManager::class.java).notify(
                payload.incidentId,
                StatusNotificationFactory.notificationId(payload.incidentId),
                StatusNotificationFactory.create(this, payload),
            )
            Log.i(TAG, "alarm_notification_posted incident_id=${payload.incidentId} kind=${payload.kind.wireValue}")
        }
        try {
            ContextCompat.startForegroundService(this, AlarmForegroundService.startIntent(this, payload))
            Log.i(TAG, "alarm_service_start_requested incident_id=${payload.incidentId} kind=${payload.kind.wireValue}")
        } catch (error: RuntimeException) {
            if (Build.VERSION.SDK_INT < 31 || error.javaClass.simpleName != "ForegroundServiceStartNotAllowedException") throw error
            Log.w(TAG, "alarm_service_start_rejected incident_id=${payload.incidentId}")
        }
    }

    companion object {
        private const val TAG = "CritAlarmFcm"
    }
}
