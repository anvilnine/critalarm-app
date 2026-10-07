package app.critalarm.check

import android.app.job.JobInfo
import android.app.job.JobScheduler
import android.content.ComponentName
import android.content.Context
import android.os.PersistableBundle
import android.util.Log
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Answers a weekly check push (api.md §5.4) with no Dart running.
 *
 * It records when the push arrived and hands the receipt to
 * [CheckReceiptJobService]. That is all. It shows nothing and rings nothing,
 * and it shares no state with incident pushes: its one preference key is read
 * by the weekly check in Dart and by nothing else.
 *
 * [answer] does no work on the caller's thread. The caller is the thread
 * every push arrives on, and an alarm push behind this one must not wait for
 * a disk write, a system call or the network. Everything goes to [worker],
 * one thread of this object's own that nothing on the incident path uses.
 * Every change to the record goes through it too, so two of them never
 * overwrite each other's fields.
 */
object WeeklyCheckResponder {
    private const val TAG = "CritAlarmCheck"
    private const val PREFERENCES = "FlutterSharedPreferences"

    /**
     * Read by `SharedPrefsWeeklyCheckStore` in Dart. The `flutter.` prefix is
     * what the shared_preferences plugin puts on every key it owns.
     */
    const val ARRIVAL_KEY = "flutter.weekly_check.native"

    private const val API_SESSION_KEY = "flutter.api_session"
    private const val DEVICE_ID_KEY = "flutter.device_id"
    private const val DEVICE_TOKEN_KEY = "flutter.device_token"

    /** Job ids from here up, one per check and attempt. No other job in the app uses them. */
    private const val JOB_ID_BASE = 0x43480000

    private val worker: ExecutorService = Executors.newSingleThreadExecutor { task ->
        Thread(task, "weekly-check").apply { isDaemon = true }
    }

    fun answer(context: Context, push: CheckPush) {
        val appContext = context.applicationContext
        val receivedAt = System.currentTimeMillis() / 1000L
        worker.execute { arrived(appContext, push, receivedAt) }
    }

    /** On [worker]: the record, then the job. */
    private fun arrived(context: Context, push: CheckPush, receivedAt: Long) {
        // The id of the check is never logged.
        Log.i(TAG, "check_received attempt=${push.attempt ?: "-"}")
        update(context) { CheckReceipt.withArrival(it, receivedAt) }

        val extras = PersistableBundle().apply {
            putString(CheckReceiptJobService.EXTRA_CHECK_ID, push.checkId)
            putInt(CheckReceiptJobService.EXTRA_ATTEMPT, push.attempt ?: 0)
            putLong(CheckReceiptJobService.EXTRA_RECEIVED_AT, receivedAt)
        }
        // Not persisted, so the id never reaches the disk. A job needs the
        // network, so one that cannot send now waits for it.
        val job = JobInfo.Builder(jobId(push), ComponentName(context, CheckReceiptJobService::class.java))
            .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
            .setExtras(extras)
            .build()
        val scheduled = runCatching {
            context.getSystemService(JobScheduler::class.java)?.schedule(job) == JobScheduler.RESULT_SUCCESS
        }.getOrDefault(false)
        if (!scheduled) Log.w(TAG, "check_receipt_not_scheduled")
    }

    /**
     * The same push arriving twice gets the same job id. A copy that lands
     * while the first is still waiting replaces it, and one that lands after
     * is answered again. Both are harmless (api.md §4.5).
     */
    internal fun jobId(push: CheckPush): Int =
        JOB_ID_BASE or ("${push.checkId}/${push.attempt}".hashCode() and 0xFFFF)

    fun relayDevice(context: Context): RelayDevice? {
        val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        return RelayDevice.parse(
            apiSession = preferences.getString(API_SESSION_KEY, null),
            deviceId = preferences.getString(DEVICE_ID_KEY, null),
            deviceToken = preferences.getString(DEVICE_TOKEN_KEY, null),
        )
    }

    /** A receipt was answered. Written on [worker], like every change to the record. */
    fun recordAnswer(context: Context, answer: CheckReceiptAnswer) {
        val appContext = context.applicationContext
        val now = System.currentTimeMillis() / 1000L
        worker.execute { update(appContext) { CheckReceipt.withAnswer(it, answer, now) } }
    }

    /** Only ever called on [worker], so a read and its write are never split by another. */
    private fun update(context: Context, change: (String?) -> String) {
        val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        preferences.edit().putString(ARRIVAL_KEY, change(preferences.getString(ARRIVAL_KEY, null))).apply()
    }
}
