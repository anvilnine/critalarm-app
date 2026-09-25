package app.critalarm.widgets

import java.util.concurrent.atomic.AtomicLong

/**
 * The store's rules without Android: what gets saved, and a count of every
 * write and patch, so a fetch that started before one of them does not land
 * on top of it. [WidgetSnapshotStore] runs it over the preferences file; the
 * JVM test runs it over a plain string.
 *
 * Every save except the fetch's own bumps [changes]. A sign out that lands
 * while a widget fetch is out is a write too, and the fetch must not put the
 * connected snapshot back over it.
 */
class WidgetSnapshotLedger(
    private val load: () -> String?,
    private val store: (String) -> Unit,
    private val changes: AtomicLong,
    private val lock: Any,
) {
    fun read(): WidgetSnapshot? = WidgetSnapshotJson.parse(load())

    fun changes(): Long = changes.get()

    /** Stores a snapshot Dart built. Anything that does not parse is refused. */
    fun writeJson(json: String): Boolean {
        if (WidgetSnapshotJson.parse(json) == null) return false
        synchronized(lock) {
            store(json)
            changes.incrementAndGet()
        }
        return true
    }

    fun write(snapshot: WidgetSnapshot) {
        synchronized(lock) {
            save(snapshot)
            changes.incrementAndGet()
        }
    }

    /**
     * Stores [fetched] unless something was written since [changesBefore].
     * Returns true when something was, so the caller can log it.
     */
    fun writeFetched(fetched: WidgetSnapshot, changesBefore: Long): Boolean = synchronized(lock) {
        val changed = changes.get() != changesBefore
        WidgetFreshness.afterFetch(fetched, read(), changed)?.let(::save)
        changed
    }

    /**
     * Runs one of the [WidgetSnapshotPatch] operations against what is stored.
     * A fetch that is needed is left to the next redraw: the stored snapshot
     * gets `updated_at = 0`, which [WidgetFreshness] reads as stale.
     */
    fun patch(
        nowSeconds: Long,
        operation: (WidgetSnapshot?, Long) -> WidgetPatchResult,
    ): WidgetPatchResult = synchronized(lock) {
        val current = read()
        // Widgets are part of Pro. Nothing patches topic data back in.
        if (current?.locked == true) return@synchronized WidgetPatchResult.Unchanged
        val result = operation(current, nowSeconds)
        when (result) {
            is WidgetPatchResult.Changed -> save(result.snapshot)
            is WidgetPatchResult.NeedsFetch ->
                (result.partial ?: current)?.let { save(it.copy(updatedAt = 0L)) }
            WidgetPatchResult.Unchanged -> Unit
        }
        if (result != WidgetPatchResult.Unchanged) changes.incrementAndGet()
        result
    }

    private fun save(snapshot: WidgetSnapshot) = store(WidgetSnapshotJson.write(snapshot))
}
