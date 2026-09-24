package app.critalarm.widgets

import android.content.Context
import android.util.Log
import java.util.concurrent.atomic.AtomicLong

/**
 * Where the widget snapshot lives: the `critalarm_widgets` preferences, key
 * `widget_snapshot_v1`. Every change asks [WidgetRedraw] to draw the widgets
 * again.
 */
class WidgetSnapshotStore(context: Context) {
    private val context = context.applicationContext
    private val preferences = this.context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun read(): WidgetSnapshot? = WidgetSnapshotJson.parse(preferences.getString(KEY, null))

    /** Stores a snapshot Dart built. Anything that does not parse is refused. */
    fun writeJson(json: String): Boolean {
        if (WidgetSnapshotJson.parse(json) == null) {
            Log.w(TAG, "widget_snapshot_refused")
            return false
        }
        synchronized(LOCK) {
            preferences.edit().putString(KEY, json).apply()
            CHANGES.incrementAndGet()
        }
        WidgetRedraw.all(context)
        return true
    }

    /**
     * Counts app writes and patches in this process. [WidgetRefresher] reads
     * it before its GETs and hands it to [writeFetched] after.
     */
    fun changes(): Long = CHANGES.get()

    /** Stores [fetched] unless something was written since [changesBefore]. */
    fun writeFetched(fetched: WidgetSnapshot, changesBefore: Long) {
        synchronized(LOCK) {
            val changed = CHANGES.get() != changesBefore
            WidgetFreshness.afterFetch(fetched, read(), changed)?.let(::save)
            if (changed) Log.i(TAG, "widget_fetch_overtaken")
        }
        WidgetRedraw.all(context)
    }

    fun write(snapshot: WidgetSnapshot) {
        synchronized(LOCK) { save(snapshot) }
        WidgetRedraw.all(context)
    }

    /** Signed out. Every widget says so and nothing is fetched. */
    fun clear(nowSeconds: Long = nowSeconds()) = write(WidgetSnapshot.disconnected(nowSeconds))

    /**
     * Runs one of the [WidgetSnapshotPatch] operations against what is stored.
     * A fetch that is needed is left to the next redraw: the stored snapshot
     * gets `updated_at = 0`, which [WidgetFreshness] reads as stale.
     */
    fun patch(operation: (WidgetSnapshot?, Long) -> WidgetPatchResult) {
        val result = synchronized(LOCK) {
            val current = read()
            val result = operation(current, nowSeconds())
            when (result) {
                is WidgetPatchResult.Changed -> save(result.snapshot)
                is WidgetPatchResult.NeedsFetch ->
                    (result.partial ?: current)?.let { save(it.copy(updatedAt = 0L)) }
                WidgetPatchResult.Unchanged -> Unit
            }
            if (result != WidgetPatchResult.Unchanged) CHANGES.incrementAndGet()
            result
        }
        Log.i(TAG, "widget_snapshot_patch result=${result.javaClass.simpleName}")
        if (result != WidgetPatchResult.Unchanged) WidgetRedraw.all(context)
    }

    private fun save(snapshot: WidgetSnapshot) {
        preferences.edit().putString(KEY, WidgetSnapshotJson.write(snapshot)).apply()
    }

    companion object {
        const val PREFS = "critalarm_widgets"
        const val KEY = "widget_snapshot_v1"
        private const val TAG = "CritAlarmWidgets"
        private val LOCK = Any()
        private val CHANGES = AtomicLong()

        fun nowSeconds(): Long = System.currentTimeMillis() / 1000L
    }
}
