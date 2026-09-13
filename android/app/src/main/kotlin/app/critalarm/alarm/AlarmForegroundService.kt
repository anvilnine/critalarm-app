package app.critalarm.alarm

import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder
import android.os.PowerManager
import app.critalarm.notifications.AlarmNotificationFactory
import app.critalarm.push.FcmIncidentPayload
import android.util.Log

class AlarmForegroundService : Service() {
    private lateinit var player: AlarmPlayer
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onCreate() {
        super.onCreate()
        player = AlarmPlayer(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val payload = FcmIncidentPayload.fromData(intent?.extras?.keySet()?.associateWith { intent.getStringExtra(it).orEmpty() }.orEmpty())
            ?: run {
                stopSelf(startId)
                return START_NOT_STICKY
            }
        // Only an incident rings, and an incident always has an id.
        val incidentId = payload.incidentId ?: run {
            stopSelf(startId)
            return START_NOT_STICKY
        }
        startForeground(
            AlarmNotificationFactory.notificationId(incidentId),
            AlarmNotificationFactory.create(this, payload),
        )
        Log.i("CritAlarmAlarm", "alarm_service_started incident_id=$incidentId")
        if (wakeLock?.isHeld != true) {
            wakeLock = getSystemService(PowerManager::class.java)
                .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "critalarm:alarm")
                .apply { acquire(WAKE_LOCK_TIMEOUT_MS) }
        }
        player.start()
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        player.stop()
        wakeLock?.takeIf { it.isHeld }?.release()
        wakeLock = null
        Log.i("CritAlarmAlarm", "alarm_service_stopped")
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        private const val WAKE_LOCK_TIMEOUT_MS = 10 * 60 * 1000L

        fun startIntent(context: Context, payload: FcmIncidentPayload) =
            Intent(context, AlarmForegroundService::class.java).apply {
                payload.incidentId?.let { putExtra("incident_id", it) }
                putExtra("server", payload.server.toString())
                putExtra("kind", payload.kind.wireValue)
                putExtra("priority", payload.priority.toString())
                payload.title?.let { putExtra("title", it) }
                payload.body?.let { putExtra("body", it) }
            }
    }
}
