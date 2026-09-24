package app.critalarm.widgets

import android.content.Context
import android.util.Log
import java.util.concurrent.atomic.AtomicLong

/**
 * Where the widget snapshot lives: the `critalarm_widgets` preferences, key
 * `widget_snapshot_v1`. Every change asks [WidgetRedraw] to draw the widgets
 * again. The rules are in [WidgetSnapshotLedger].
 */
class WidgetSnapshotStore(context: Context) {
    private val context = context.applicationContext
    private val preferences = this.context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private val ledger = WidgetSnapshotLedger(
        load = { preferences.getString(KEY, null) },
        store = { preferences.edit().putString(KEY, it).apply() },
        changes = CHANGES,
        lock = LOCK,
    )

    fun read(): WidgetSnapshot? = ledger.read()

    /** Stores a snapshot Dart built. Anything that does not parse is refused. */
    fun writeJson(json: String): Boolean {
        if (!ledger.writeJson(json)) {
            Log.w(TAG, "widget_snapshot_refused")
            return false
        }
        WidgetRedraw.all(context)
        return true
    }

    /**
     * Counts app writes and patches in this process. [WidgetRefresher] reads
     * it before its GETs and hands it to [writeFetched] after.
     */
    fun changes(): Long = ledger.changes()

    /** Stores [fetched] unless something was written since [changesBefore]. */
    fun writeFetched(fetched: WidgetSnapshot, changesBefore: Long) {
        if (ledger.writeFetched(fetched, changesBefore)) Log.i(TAG, "widget_fetch_overtaken")
        WidgetRedraw.all(context)
    }

    fun write(snapshot: WidgetSnapshot) {
        ledger.write(snapshot)
        WidgetRedraw.all(context)
    }

    /** Signed out. Every widget says so and nothing is fetched. */
    fun clear(nowSeconds: Long = nowSeconds()) = write(WidgetSnapshot.disconnected(nowSeconds))

    /** See [WidgetSnapshotLedger.patch]. */
    fun patch(operation: (WidgetSnapshot?, Long) -> WidgetPatchResult) {
        val result = ledger.patch(nowSeconds(), operation)
        Log.i(TAG, "widget_snapshot_patch result=${result.javaClass.simpleName}")
        if (result != WidgetPatchResult.Unchanged) WidgetRedraw.all(context)
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
