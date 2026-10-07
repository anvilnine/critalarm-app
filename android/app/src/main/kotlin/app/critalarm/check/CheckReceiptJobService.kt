package app.critalarm.check

import android.app.job.JobParameters
import android.app.job.JobService
import android.util.Log
import java.net.HttpURLConnection
import java.net.URL

/**
 * Sends the receipt for one weekly check (api.md §4.5), on its own thread.
 *
 * A job, so the system keeps the phone awake and the process alive for the
 * call, which a thread started from the push handler is not promised. It
 * tries a small number of times and then drops the receipt. Nothing is kept
 * for later and nothing here is shared with incident pushes.
 *
 * The system reuses one service object for many jobs, so nothing about one
 * job is kept on the service: each run has its own entry in [jobs].
 */
class CheckReceiptJobService : JobService() {
    private val jobs = CheckReceiptJobs()

    override fun onStartJob(params: JobParameters): Boolean {
        val checkId = params.extras.getString(EXTRA_CHECK_ID)
        if (checkId.isNullOrEmpty()) return false
        val push = CheckPush(
            checkId = checkId,
            attempt = params.extras.getInt(EXTRA_ATTEMPT, 0).takeIf { it > 0 },
        )
        val receivedAt = params.extras.getLong(EXTRA_RECEIVED_AT, System.currentTimeMillis() / 1000L)
        val run = jobs.started(params.jobId)
        Thread {
            try {
                send(push, receivedAt, run)
            } finally {
                jobs.finished(params.jobId, run)
                // Never rescheduled: a receipt that did not get out is dropped.
                jobFinished(params, false)
            }
        }.start()
        return true
    }

    /** The system took this job back, for instance because the network went. Dropped. */
    override fun onStopJob(params: JobParameters): Boolean {
        jobs.stop(params.jobId)
        return false
    }

    private fun send(push: CheckPush, receivedAtSeconds: Long, run: CheckReceiptJobs.Run) {
        val device = WeeklyCheckResponder.relayDevice(applicationContext) ?: run {
            Log.i(TAG, "check_receipt_skipped reason=no_credentials")
            return
        }
        if (!CheckReceipt.maySend(device.relay, PlainHttpRelays.hosts)) {
            // The token never goes out over plain http. No host is named here.
            Log.i(TAG, "check_receipt_skipped reason=relay_not_https")
            return
        }
        val outcome = CheckReceipt.send(
            request = CheckReceipt.request(device, push, receivedAtSeconds),
            post = ::post,
            isCancelled = { run.isStopped },
            onTry = { index, status ->
                if (status != 200) Log.i(TAG, "check_receipt_failed status=${status ?: "-"} try=${index + 1}")
            },
            onAnswer = { answer ->
                if (answer != null) WeeklyCheckResponder.recordAnswer(applicationContext, answer)
                Log.i(TAG, "check_receipt_sent counted=${answer?.counted ?: "-"}")
            },
        )
        when (outcome) {
            CheckReceipt.Outcome.SENT -> Unit
            CheckReceipt.Outcome.REFUSED -> Log.i(TAG, "check_receipt_refused")
            CheckReceipt.Outcome.DROPPED -> Log.i(TAG, "check_receipt_dropped")
            CheckReceipt.Outcome.CANCELLED -> Log.i(TAG, "check_receipt_cancelled")
        }
    }

    /** The status and the body, or a null status when nothing came back. */
    private fun post(request: CheckReceiptRequest): Pair<Int?, String?> {
        var connection: HttpURLConnection? = null
        return try {
            connection = (URL(request.url).openConnection() as HttpURLConnection).apply {
                requestMethod = request.method
                connectTimeout = CheckReceipt.CONNECT_TIMEOUT_MS
                readTimeout = CheckReceipt.READ_TIMEOUT_MS
                doOutput = true
                request.headers.forEach { (name, value) -> setRequestProperty(name, value) }
            }
            connection.outputStream.use { it.write(request.body.toByteArray(Charsets.UTF_8)) }
            val status = connection.responseCode
            val body = if (status in 200..299) {
                connection.inputStream.bufferedReader().use { it.readText() }
            } else {
                null
            }
            status to body
        } catch (error: Exception) {
            // The class alone: a message can hold the url, and the url holds
            // the id of the check.
            Log.i(TAG, "check_receipt_error error=${error.javaClass.simpleName}")
            null to null
        } finally {
            connection?.disconnect()
        }
    }

    companion object {
        const val EXTRA_CHECK_ID = "check_id"
        const val EXTRA_ATTEMPT = "attempt"
        const val EXTRA_RECEIVED_AT = "received_at"
        private const val TAG = "CritAlarmCheck"
    }
}
