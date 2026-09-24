package app.critalarm.widgets

import android.content.Context
import android.os.SystemClock
import android.util.Log
import app.critalarm.storage.NativeConnectionStore
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Asks the server for the whole picture when the snapshot is stale.
 *
 * Covers what no push reaches: a topic added or deleted from the web
 * dashboard, or a patch that could not place an incident. Three GETs with the
 * credentials the app already stored (api.md §3.1, §3.2), all inside one
 * [BUDGET_MS] so a widget update running under `goAsync()` always finishes.
 * Any failure keeps the old snapshot. A 401 means the token is gone, so the
 * widgets say "not connected". A patch that lands during the GETs wins over
 * the fetch, which then leaves the snapshot stale.
 */
object WidgetRefresher {
    const val BUDGET_MS = 8_000L
    private const val MAX_TIMEOUT_MS = 4_000L
    private const val TAG = "CritAlarmWidgets"

    private val running = AtomicBoolean(false)

    /** Fetches when stale, then calls [done]. [done] always runs, once. */
    fun refreshIfStale(context: Context, done: () -> Unit) {
        val app = context.applicationContext
        val store = WidgetSnapshotStore(app)
        if (!WidgetFreshness.isStale(store.read(), WidgetSnapshotStore.nowSeconds())) {
            done()
            return
        }
        val connections = NativeConnectionStore(app)
        val credentials = connections.canonicalServer()?.let(connections::credentialsFor)
        if (credentials == null || !running.compareAndSet(false, true)) {
            done()
            return
        }
        val base = credentials.first.toString().trimEnd('/')
        Thread {
            try {
                fetch(store, base, credentials.second)
            } finally {
                running.set(false)
                done()
            }
        }.start()
    }

    private fun fetch(store: WidgetSnapshotStore, base: String, token: String) {
        val deadline = SystemClock.elapsedRealtime() + BUDGET_MS
        val changesBefore = store.changes()
        val answers = mutableListOf<String>()
        for (path in PATHS) {
            val remaining = deadline - SystemClock.elapsedRealtime()
            if (remaining <= 0) {
                Log.w(TAG, "widget_fetch_skipped reason=budget")
                return
            }
            when (val answer = get(base + path, token, remaining)) {
                is Answer.Body -> answers += answer.text
                Answer.Unauthorized -> {
                    Log.w(TAG, "widget_fetch_unauthorized")
                    store.clear()
                    return
                }
                Answer.Failed -> return
            }
        }
        val snapshot = WidgetSnapshotBuilder.fromServer(
            answers[0], answers[1], answers[2], WidgetSnapshotStore.nowSeconds(),
        ) ?: run {
            Log.w(TAG, "widget_fetch_unreadable")
            return
        }
        Log.i(TAG, "widget_fetch_ok topics=${snapshot.topics.size} open=${snapshot.openCount}")
        store.writeFetched(snapshot, changesBefore)
    }

    private sealed class Answer {
        data class Body(val text: String) : Answer()
        object Unauthorized : Answer()
        object Failed : Answer()
    }

    /**
     * One GET. Connect and read each get half of what is left, capped at four
     * seconds, so the pair cannot run past the budget.
     */
    private fun get(url: String, token: String, remainingMs: Long): Answer = try {
        val timeout = minOf(MAX_TIMEOUT_MS, remainingMs / 2).coerceAtLeast(1L).toInt()
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.requestMethod = "GET"
        connection.setRequestProperty("Authorization", "Bearer $token")
        connection.setRequestProperty("Accept", "application/json")
        connection.connectTimeout = timeout
        connection.readTimeout = timeout
        val status = connection.responseCode
        val answer = when {
            status == 401 -> Answer.Unauthorized
            status !in 200..299 -> {
                Log.w(TAG, "widget_fetch_failed_$status")
                Answer.Failed
            }
            else -> Answer.Body(connection.inputStream.bufferedReader().use { it.readText() })
        }
        connection.disconnect()
        answer
    } catch (error: Exception) {
        Log.w(TAG, "widget_fetch_failed reason=${error.javaClass.simpleName}")
        Answer.Failed
    }

    /** `limit` is always sent: leaving it off means 20 (api.md §3.2). */
    private val PATHS = listOf(
        "/v1/topics",
        "/v1/incidents?limit=200&state=open",
        "/v1/incidents?limit=200&state=acked",
    )
}
