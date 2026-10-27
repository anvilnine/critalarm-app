package app.critalarm.storage

import android.content.SharedPreferences
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * A ring generation never comes back. An answer asked under an old value
 * must not find that value again after retention dropped the incident's keys
 * and a reopen armed it once more.
 */
class RingGenerationStoreTest {
    private val now = 100L * DeliveryRetention.WINDOW_MS

    private fun finishedLongAgo(store: IncidentDeliveryStore, incidentId: String) {
        store.markClosed(incidentId, atMillis = now - 2 * DeliveryRetention.WINDOW_MS)
    }

    @Test
    fun `a push moves the generation on`() {
        val store = IncidentDeliveryStore(InMemoryPreferences())
        val before = store.ringGeneration("inc_a")
        store.bumpRingGeneration("inc_a")
        assertTrue(store.ringGeneration("inc_a") > before)
    }

    @Test
    fun `a generation dropped by retention is never handed out again`() {
        val store = IncidentDeliveryStore(InMemoryPreferences())
        store.bumpRingGeneration("inc_a")
        val captured = store.ringGeneration("inc_a")
        finishedLongAgo(store, "inc_a")

        store.prune(now)
        store.bumpRingGeneration("inc_a")

        assertNotEquals(captured, store.ringGeneration("inc_a"))
    }

    @Test
    fun `retention never moves a generation back`() {
        val store = IncidentDeliveryStore(InMemoryPreferences())
        repeat(3) { store.bumpRingGeneration("inc_a") }
        val before = store.ringGeneration("inc_a")
        finishedLongAgo(store, "inc_a")

        store.prune(now)

        assertTrue(store.ringGeneration("inc_a") >= before)
    }

    @Test
    fun `a value read with no keys is not found again after a push and a second prune`() {
        val store = IncidentDeliveryStore(InMemoryPreferences())
        val captured = store.ringGeneration("inc_a")
        store.bumpRingGeneration("inc_a")
        finishedLongAgo(store, "inc_a")

        store.prune(now)

        assertNotEquals(captured, store.ringGeneration("inc_a"))
    }

    @Test
    fun `an incident nobody pruned keeps its value while others are pruned`() {
        val store = IncidentDeliveryStore(InMemoryPreferences())
        store.bumpRingGeneration("inc_live")
        val captured = store.ringGeneration("inc_live")
        repeat(5) { store.bumpRingGeneration("inc_old") }
        finishedLongAgo(store, "inc_old")

        store.prune(now)

        assertEquals(captured, store.ringGeneration("inc_live"))
    }
}

/** Enough of [SharedPreferences] for the store, held in a map. */
class InMemoryPreferences : SharedPreferences {
    private val values = mutableMapOf<String, Any?>()

    override fun getAll(): Map<String, *> = values.toMap()
    override fun getString(key: String, defValue: String?) = values[key] as? String ?: defValue

    @Suppress("UNCHECKED_CAST")
    override fun getStringSet(key: String, defValues: Set<String>?) =
        values[key] as? Set<String> ?: defValues

    override fun getInt(key: String, defValue: Int) = values[key] as? Int ?: defValue
    override fun getLong(key: String, defValue: Long) = values[key] as? Long ?: defValue
    override fun getFloat(key: String, defValue: Float) = values[key] as? Float ?: defValue
    override fun getBoolean(key: String, defValue: Boolean) = values[key] as? Boolean ?: defValue
    override fun contains(key: String) = values.containsKey(key)
    override fun edit(): SharedPreferences.Editor = Editor()
    override fun registerOnSharedPreferenceChangeListener(
        listener: SharedPreferences.OnSharedPreferenceChangeListener?,
    ) = Unit

    override fun unregisterOnSharedPreferenceChangeListener(
        listener: SharedPreferences.OnSharedPreferenceChangeListener?,
    ) = Unit

    private inner class Editor : SharedPreferences.Editor {
        private val puts = mutableMapOf<String, Any?>()
        private val removes = mutableSetOf<String>()
        private var clear = false

        override fun putString(key: String, value: String?) = apply { puts[key] = value }
        override fun putStringSet(key: String, values: Set<String>?) = apply { puts[key] = values }
        override fun putInt(key: String, value: Int) = apply { puts[key] = value }
        override fun putLong(key: String, value: Long) = apply { puts[key] = value }
        override fun putFloat(key: String, value: Float) = apply { puts[key] = value }
        override fun putBoolean(key: String, value: Boolean) = apply { puts[key] = value }
        override fun remove(key: String) = apply { removes += key }
        override fun clear() = apply { clear = true }
        override fun commit(): Boolean {
            if (clear) values.clear()
            removes.forEach(values::remove)
            values.putAll(puts)
            return true
        }

        override fun apply() {
            commit()
        }
    }
}
