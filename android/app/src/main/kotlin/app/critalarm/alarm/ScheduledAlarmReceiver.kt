package app.critalarm.alarm

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.util.Log
import app.critalarm.storage.IncidentDeliveryStore
import app.critalarm.widgets.WidgetSnapshotPatch
import app.critalarm.widgets.WidgetSnapshotStore

/**
 * Rings a local alarm after a delay, with no push involved.
 *
 * Onboarding's "ring my phone in 30 seconds" test needs this: there is no
 * server message coming, so [AlarmForegroundService] has nothing to start it.
 * The alarm is held by the system AlarmManager rather than by a timer in the
 * app, so it still fires if the user backgrounds or kills the app, which is
 * the whole point of the test.
 */
class ScheduledAlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val incidentId = intent.getStringExtra(EXTRA_INCIDENT_ID)
        if (incidentId.isNullOrEmpty()) return
        val slot = intent.getIntExtra(EXTRA_SLOT, -1)
        if (slot >= 0 && !slotRings(context, intent, incidentId, slot)) return
        Log.i(TAG, "scheduled_alarm_fired incident_id=$incidentId slot=$slot")

        val service = Intent(context, AlarmForegroundService::class.java).apply {
            putExtra("incident_id", incidentId)
            putExtra("server", intent.getStringExtra(EXTRA_SERVER).orEmpty())
            putExtra("kind", "open")
            putExtra("priority", "5")
            intent.getStringExtra(EXTRA_TITLE)?.let { putExtra("title", it) }
            intent.getStringExtra(EXTRA_BODY)?.let { putExtra("body", it) }
            // Passed on so the Stop button this alarm posts knows whether a
            // card may take the alarm card's place.
            putExtra(
                AlarmForegroundService.EXTRA_HAND_OVER,
                intent.getStringExtra(AlarmForegroundService.EXTRA_HAND_OVER) ?: "true",
            )
        }
        context.startForegroundService(service)
    }

    /**
     * A slot of a chain ([AlarmChains]) went off. True when it rings. The
     * gate runs again here because the chain was set minutes ago: an ack, a
     * close or the critical switch may have come since.
     */
    private fun slotRings(context: Context, intent: Intent, incidentId: String, slot: Int): Boolean {
        val now = System.currentTimeMillis()
        val fired = AlarmChain.of(context).onSlotFired(
            incidentId = incidentId,
            slot = slot,
            atMillis = intent.getLongExtra(EXTRA_AT, 0L),
            nowMillis = now,
            title = intent.getStringExtra(EXTRA_TITLE),
            body = intent.getStringExtra(EXTRA_BODY),
        )
        Log.i(TAG, "chain_slot_fired incident_id=$incidentId slot=$slot outcome=$fired")
        return when (fired) {
            ChainRule.Fired.RING -> true
            ChainRule.Fired.REOPEN_AND_RING -> {
                WidgetSnapshotStore(context).patch { snapshot, nowSeconds ->
                    WidgetSnapshotPatch.reopened(snapshot, incidentId, nowSeconds)
                }
                true
            }
            ChainRule.Fired.END -> {
                val ringUntil = IncidentDeliveryStore(context).ringUntilMillis(incidentId)
                if (ringUntil != null && now >= ringUntil) IncidentRearm.endRingWindow(context, incidentId)
                false
            }
            ChainRule.Fired.SKIP, ChainRule.Fired.STALE -> false
        }
    }

    companion object {
        private const val TAG = "CritAlarmAlarm"
        private const val EXTRA_INCIDENT_ID = "incident_id"
        private const val EXTRA_SERVER = "server"
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_BODY = "body"
        private const val EXTRA_SLOT = "chain_slot"
        private const val EXTRA_AT = "chain_at"
        private const val SLOT_SCHEME = "critalarm-chain"

        /**
         * Puts an alarm [delaySeconds] out for [incidentId], replacing any
         * alarm already set for it. False when the system refuses, which on
         * Android 12 and up means the user has not allowed exact alarms.
         */
        fun schedule(
            context: Context,
            incidentId: String,
            server: String,
            title: String,
            body: String?,
            delaySeconds: Int,
            handOverToStatusCard: Boolean = true,
        ): Boolean {
            return scheduleAt(
                context = context,
                incidentId = incidentId,
                server = server,
                title = title,
                body = body,
                atMillis = System.currentTimeMillis() + delaySeconds * 1000L,
                handOverToStatusCard = handOverToStatusCard,
            )
        }

        /**
         * The same alarm, at an instant rather than a delay. This is what a
         * re-arm uses.
         *
         * `setAlarmClock`, not `setExactAndAllowWhileIdle`. In Doze the latter
         * fires at most about once every nine minutes per app, which is no use
         * for a thirty-second repeat. `setAlarmClock` is exempt from Doze and
         * also lets the receiver start a foreground service from the
         * background, which is how the ring comes back with the app closed.
         * The cost is the alarm icon in the status bar, which for an alarm app
         * is honest.
         */
        fun scheduleAt(
            context: Context,
            incidentId: String,
            server: String,
            title: String,
            body: String?,
            atMillis: Long,
            handOverToStatusCard: Boolean = true,
        ): Boolean {
            val manager = context.getSystemService(AlarmManager::class.java) ?: return false
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !manager.canScheduleExactAlarms()) {
                Log.w(TAG, "scheduled_alarm_refused reason=no_exact_alarm_permission")
                return false
            }
            val fire = pendingIntent(context, incidentId, server, title, body, handOverToStatusCard) ?: return false
            return try {
                manager.setAlarmClock(AlarmManager.AlarmClockInfo(atMillis, fire), fire)
                Log.i(TAG, "scheduled_alarm_set incident_id=$incidentId at=$atMillis")
                true
            } catch (e: Exception) {
                Log.w(TAG, "scheduled_alarm_failed incident_id=$incidentId error=${e.message}")
                false
            }
        }

        /** Drops a pending alarm. Safe to call when there is none. */
        fun cancel(context: Context, incidentId: String) {
            val manager = context.getSystemService(AlarmManager::class.java) ?: return
            pendingIntent(
                context = context,
                incidentId = incidentId,
                server = "",
                title = "",
                body = null,
                flags = PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
            )?.let(manager::cancel)
        }

        /**
         * One slot of a chain, as a `setAlarmClock` alarm of its own. Its
         * request code comes from the incident id and [slot], and its intent
         * carries its own data address, so setting slot 3 again replaces slot
         * 3 and never touches slot 4 or the onboarding alarm.
         */
        fun scheduleSlot(
            context: Context,
            incidentId: String,
            slot: Int,
            atMillis: Long,
            server: String,
            title: String,
            body: String?,
        ): Boolean {
            val manager = context.getSystemService(AlarmManager::class.java) ?: return false
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !manager.canScheduleExactAlarms()) {
                Log.w(TAG, "chain_slot_refused reason=no_exact_alarm_permission")
                return false
            }
            val intent = slotIntent(context, incidentId, slot).apply {
                putExtra(EXTRA_AT, atMillis)
                putExtra(EXTRA_SERVER, server)
                putExtra(EXTRA_TITLE, title)
                body?.let { putExtra(EXTRA_BODY, it) }
            }
            val fire = PendingIntent.getBroadcast(
                context,
                ChainRule.requestCode(incidentId, slot),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            ) ?: return false
            return try {
                manager.setAlarmClock(AlarmManager.AlarmClockInfo(atMillis, fire), fire)
                true
            } catch (e: Exception) {
                Log.w(TAG, "chain_slot_failed incident_id=$incidentId slot=$slot error=${e.message}")
                false
            }
        }

        /** Drops one slot. Safe to call when it is not set. */
        fun cancelSlot(context: Context, incidentId: String, slot: Int) {
            val manager = context.getSystemService(AlarmManager::class.java) ?: return
            existingSlot(context, incidentId, slot)?.let {
                manager.cancel(it)
                it.cancel()
            }
        }

        fun slotIsSet(context: Context, incidentId: String, slot: Int): Boolean =
            existingSlot(context, incidentId, slot) != null

        private fun existingSlot(context: Context, incidentId: String, slot: Int): PendingIntent? =
            PendingIntent.getBroadcast(
                context,
                ChainRule.requestCode(incidentId, slot),
                slotIntent(context, incidentId, slot),
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
            )

        private fun slotIntent(context: Context, incidentId: String, slot: Int): Intent =
            Intent(context, ScheduledAlarmReceiver::class.java).apply {
                data = Uri.fromParts(SLOT_SCHEME, "$incidentId/$slot", null)
                putExtra(EXTRA_INCIDENT_ID, incidentId)
                putExtra(EXTRA_SLOT, slot)
            }

        private fun pendingIntent(
            context: Context,
            incidentId: String,
            server: String,
            title: String,
            body: String?,
            handOverToStatusCard: Boolean = true,
            flags: Int = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        ): PendingIntent? {
            val intent = Intent(context, ScheduledAlarmReceiver::class.java).apply {
                putExtra(EXTRA_INCIDENT_ID, incidentId)
                putExtra(EXTRA_SERVER, server)
                putExtra(EXTRA_TITLE, title)
                body?.let { putExtra(EXTRA_BODY, it) }
                putExtra(
                    AlarmForegroundService.EXTRA_HAND_OVER,
                    handOverToStatusCard.toString(),
                )
            }
            return PendingIntent.getBroadcast(
                context,
                incidentId.hashCode(),
                intent,
                flags,
            )
        }
    }
}
