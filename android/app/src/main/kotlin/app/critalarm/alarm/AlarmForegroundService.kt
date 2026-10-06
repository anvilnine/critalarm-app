package app.critalarm.alarm

import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import app.critalarm.notifications.AlarmNotificationFactory
import app.critalarm.notifications.IncidentCards
import app.critalarm.notifications.IncidentPhoneState
import app.critalarm.push.FcmIncidentPayload
import app.critalarm.push.IncidentContentFetcher
import app.critalarm.storage.IncidentDeliveryStore
import android.util.Log

class AlarmForegroundService : Service() {
    private lateinit var player: AlarmPlayer
    private lateinit var signals: RingSignals
    private val main = Handler(Looper.getMainLooper())
    private var wakeLock: PowerManager.WakeLock? = null

    /**
     * True once the ring stopped by itself, which only the quiet build's ring
     * does. The flash and the vibration stay off from then until the next
     * ring starts, even if a topic is learned in between.
     */
    private var ringTimedOut = false

    /** Incidents whose topic is being asked for, so each is asked for once. */
    private val learningTopicOf = mutableSetOf<String>()

    @Volatile
    private var destroyed = false

    override fun onCreate() {
        super.onCreate()
        signals = RingSignals(this)
        player = AlarmPlayer(this) {
            ringTimedOut = true
            signals.stop("ring_timed_out")
        }
        instance = this
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val payload = FcmIncidentPayload.fromData(intent?.extras?.keySet()?.associateWith { intent.getStringExtra(it).orEmpty() }.orEmpty())
            ?: return ignoreBadStart(startId, "unparseable")
        // Only an incident rings, and an incident always has an id.
        val incidentId = payload.incidentId ?: return ignoreBadStart(startId, "no_incident_id")
        val handOver = intent?.getStringExtra(EXTRA_HAND_OVER) != "false"
        // Whoever asks to stop an alarm has to know which one this is. The
        // service is started again, on the same instance, when a second
        // incident rings, so the last start is what is coming out of the
        // speaker and the ones before it are still waiting for an ack.
        val ringing = Ringing(incidentId, payload, handOver)
        push(ringing)
        ring(ringing)
        Log.i(TAG, "alarm_service_started incident_id=$incidentId")
        if (wakeLock?.isHeld != true) {
            wakeLock = getSystemService(PowerManager::class.java)
                .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "critalarm:alarm")
                .apply { acquire(WAKE_LOCK_TIMEOUT_MS) }
        }
        return START_NOT_STICKY
    }

    /** Puts [next] on the speaker and its card in the status bar. */
    private fun ring(next: Ringing) {
        startForeground(
            AlarmNotificationFactory.notificationId(next.incidentId),
            AlarmNotificationFactory.create(
                context = this,
                payload = next.payload,
                handOverToStatusCard = next.handOver,
            ),
        )
        // The ringing card replaces whatever status card was up, whether it was
        // the silenced one a re-arm fire is ringing over, or a handover.
        IncidentCards.show(this, next.incidentId, IncidentPhoneState.Ringing)
        player.start()
        main.post {
            ringTimedOut = false
            refreshSignals()
        }
    }

    /**
     * Starts or stops the flash and the strong vibration to match what is
     * ringing now. Runs on the main thread, after every start and every
     * handover, and again when an incident's topic is learned.
     *
     * Both follow the topics of every incident the service holds, not only
     * the one on the speaker: see [RingSignalRule.wanted].
     */
    private fun refreshSignals() {
        if (destroyed || ringTimedOut) return
        val ringing = synchronized(held) { held.toList() }
        if (ringing.isEmpty()) {
            signals.stop("nothing_ringing")
            return
        }
        val saved = AlarmSignalStore.read(this)
        val deliveries = IncidentDeliveryStore(this)
        val topics = ringing.map { deliveries.topicOf(it.incidentId) }
        val wanted = RingSignalRule.wanted(topics, saved)
        Log.i(
            TAG,
            "alarm_signals flash=${wanted.flash} vibration=${wanted.vibration} " +
                "ringing=${ringing.size} topics_known=${topics.count { it != null }}",
        )
        signals.update(flash = wanted.flash, vibration = wanted.vibration)
        ringing.forEachIndexed { index, incident ->
            if (RingSignalRule.shouldLearnTopic(topics[index], saved)) learnTopic(incident)
        }
    }

    /**
     * Asks the server which topic [incident] is on, then looks at the
     * switches again. The push does not carry a topic (api.md §5.2), and the
     * push path only fetches one when the relay stripped the text. The sound
     * never waits on this: it is already playing.
     */
    private fun learnTopic(incident: Ringing) {
        if (!learningTopicOf.add(incident.incidentId)) return
        Thread {
            val topic = runCatching {
                IncidentContentFetcher.fetch(this, incident.payload.server, incident.incidentId)?.topic
            }.getOrNull()
            if (topic.isNullOrEmpty()) {
                Log.i(TAG, "alarm_signals_topic_unknown incident_id=${incident.incidentId}")
                return@Thread
            }
            IncidentDeliveryStore(this).rememberTopic(incident.incidentId, topic)
            main.post { refreshSignals() }
        }.start()
    }

    /**
     * A start this service could not read. It stops the service only when
     * nothing is ringing: see [AlarmStopRule.stopsOnBadStart].
     */
    private fun ignoreBadStart(startId: Int, reason: String): Int {
        if (AlarmStopRule.stopsOnBadStart(ringingIncidentId)) {
            stopSelf(startId)
            return START_NOT_STICKY
        }
        // Every startForegroundService owes the system a startForeground within
        // a few seconds or it kills the app, and this start is one of them even
        // though its payload was junk. Re-asserting the card that is already up
        // pays that debt. player.start() is a no-op while the sound is playing.
        synchronized(held) { held.lastOrNull() }?.let { ring(it) }
        Log.w(TAG, "alarm_start_ignored reason=$reason ringing_incident_id=$ringingIncidentId")
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        synchronized(held) { held.clear() }
        instance = null
        destroyed = true
        main.removeCallbacksAndMessages(null)
        player.stop()
        // The one stop every way out of a ring passes through. See RingSignals.
        signals.stop("service_destroyed")
        wakeLock?.takeIf { it.isHeld }?.release()
        wakeLock = null
        Log.i(TAG, "alarm_service_stopped")
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    /** One un-acked incident the service is holding. */
    private data class Ringing(
        val incidentId: String,
        val payload: FcmIncidentPayload,
        val handOver: Boolean,
    )

    companion object {
        private const val TAG = "CritAlarmAlarm"
        private const val WAKE_LOCK_TIMEOUT_MS = 10 * 60 * 1000L

        /**
         * Says the alarm leaves no card behind when it stops. Carried as a
         * string because the service reads its extras as strings.
         */
        const val EXTRA_HAND_OVER = "hand_over_to_status_card"

        /**
         * Every un-acked incident the service is holding, oldest first. The
         * last one is what the speaker is playing.
         *
         * There is one service and one player for the whole app, so two
         * incidents cannot ring at once. They queue instead: stopping the top
         * one hands the service to the one under it rather than going quiet.
         */
        private val held = mutableListOf<Ringing>()

        /**
         * The running service, or null when it is not up. Set in onCreate and
         * cleared in onDestroy, so a handover can reach it without a bind and
         * without a background service start.
         */
        @Volatile
        private var instance: AlarmForegroundService? = null

        /**
         * The incident ringing right now, or null when the service is not
         * running.
         *
         * Dart can ask to cancel an incident that is not that one: launch-time
         * reconcile walks every acked card, and an incident the server expired
         * overnight gets cancelled while a different incident rings on the lock
         * screen. [stopIncident] works off [held] so that stop leaves the live
         * alarm alone.
         */
        private val ringingIncidentId: String?
            get() = synchronized(held) { held.lastOrNull()?.incidentId }

        /**
         * True while any un-acked incident is holding the alarm. Dart asks
         * before it opens a shared sound in the cropper, so the cropper never
         * covers an alarm that still needs acknowledging.
         */
        val isRinging: Boolean
            get() = ringingIncidentId != null

        internal fun isRinging(incidentId: String): Boolean = ringingIncidentId == incidentId

        /** The incident on the speaker now, for [AlarmLockRule]. */
        internal val ringingNow: String?
            get() = ringingIncidentId

        /**
         * True while [incidentId] holds the alarm, ringing now or waiting its
         * turn behind another incident. A state learned from the server has
         * to reach both.
         */
        internal fun isHolding(incidentId: String): Boolean =
            synchronized(held) { held.any { it.incidentId == incidentId } }

        private fun push(next: Ringing) = synchronized(held) {
            held.removeAll { it.incidentId == next.incidentId }
            held.add(next)
        }

        /**
         * Stops the ring for one incident.
         *
         * The service goes quiet only when nothing un-acked is left. With
         * another incident still waiting, the service hands over to it: see
         * [AlarmStopRule.nextRinging]. Stopping an incident the service is not
         * holding does nothing at all, which is the reconcile case.
         */
        fun stopIncident(context: Context, incidentId: String): Boolean {
            val service = instance
            val next = synchronized(held) {
                val ids = held.map { it.incidentId }
                if (service != null && incidentId !in ids) {
                    Log.i(TAG, "alarm_service_kept incident_id=$incidentId held=$ids")
                    return true
                }
                val nextId = AlarmStopRule.nextRinging(incidentId, ids)
                held.removeAll { it.incidentId == incidentId }
                if (nextId == null) null else held.lastOrNull()
            }
            if (next == null || service == null) {
                synchronized(held) { held.clear() }
                context.stopService(Intent(context, AlarmForegroundService::class.java))
                Log.i(TAG, "alarm_service_stopped incident_id=$incidentId")
                return true
            }
            service.ring(next)
            Log.i(TAG, "alarm_service_handover from=$incidentId to=${next.incidentId}")
            return true
        }

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
