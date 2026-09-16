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
        // Whoever asks to stop an alarm has to know which one this is. The
        // service is started again, on the same instance, when a second
        // incident rings, so the last start is what is coming out of the
        // speaker.
        ringingIncidentId = incidentId
        val handOver = intent?.getStringExtra(EXTRA_HAND_OVER) != "false"
        startForeground(
            AlarmNotificationFactory.notificationId(incidentId),
            AlarmNotificationFactory.create(
                context = this,
                payload = payload,
                handOverToStatusCard = handOver,
            ),
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
        ringingIncidentId = null
        player.stop()
        wakeLock?.takeIf { it.isHeld }?.release()
        wakeLock = null
        Log.i("CritAlarmAlarm", "alarm_service_stopped")
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        private const val WAKE_LOCK_TIMEOUT_MS = 10 * 60 * 1000L

        /**
         * Says the alarm leaves no card behind when it stops. Carried as a
         * string because the service reads its extras as strings.
         */
        const val EXTRA_HAND_OVER = "hand_over_to_status_card"

        /**
         * The incident ringing right now, or null when the service is not
         * running.
         *
         * There is one service for the whole app, so stopping it stops
         * whatever is ringing. Dart can ask to cancel an incident that is not
         * that one: launch-time reconcile walks every acked card, and an
         * incident the server expired overnight gets cancelled while a
         * different incident rings on the lock screen. [AlarmStopRule] reads
         * this so that stop leaves the live alarm alone.
         */
        @Volatile
        var ringingIncidentId: String? = null

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
