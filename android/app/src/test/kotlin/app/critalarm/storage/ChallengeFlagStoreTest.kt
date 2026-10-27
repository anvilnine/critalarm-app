package app.critalarm.storage

import android.content.SharedPreferences
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ChallengeFlagStoreTest {
    private fun store(vararg values: Pair<String, Any?>) = ChallengeFlagStore(FakePrefs(mapOf(*values)))

    // The key is spelled the way Dart writes it. A key spelled differently
    // on this side would read as "never owed", and Done would close.

    @Test
    fun `the key is the one Dart writes`() {
        assertEquals("flutter.topic_challenge_owed.prod-db", ChallengeFlagStore.keyFor("prod-db"))
    }

    @Test
    fun `a flag set for the topic means a challenge is owed`() {
        assertTrue(store("flutter.topic_challenge_owed.prod-db" to true).owesChallenge("prod-db"))
    }

    @Test
    fun `no flag means nothing is owed`() {
        assertFalse(store().owesChallenge("prod-db"))
    }

    @Test
    fun `a flag for another topic says nothing about this one`() {
        assertFalse(store("flutter.topic_challenge_owed.nas" to true).owesChallenge("prod-db"))
    }

    @Test
    fun `a false flag means nothing is owed`() {
        assertFalse(store("flutter.topic_challenge_owed.prod-db" to false).owesChallenge("prod-db"))
    }

    @Test
    fun `a flag that is not a boolean means nothing is owed, not a crash`() {
        assertFalse(store("flutter.topic_challenge_owed.prod-db" to "true").owesChallenge("prod-db"))
        assertFalse(store("flutter.topic_challenge_owed.prod-db" to 1).owesChallenge("prod-db"))
    }

    @Test
    fun `a card with no topic owes nothing`() {
        val flags = store("flutter.topic_challenge_owed." to true, "flutter.topic_challenge_owed.null" to true)
        assertFalse(flags.owesChallenge(null))
        assertFalse(flags.owesChallenge(""))
    }

    @Test
    fun `the choice itself is never read as the flag`() {
        // Without Pro Dart keeps the choice and sets no flag.
        assertFalse(store("flutter.topic_challenge.prod-db" to "type_topic_name").owesChallenge("prod-db"))
    }

    @Test
    fun `Done opens the app while the flag is set`() {
        val flags = store("flutter.topic_challenge_owed.prod-db" to true)
        assertEquals(DoneButton.OPENS_APP, DoneButtonRule.forTopic("prod-db", flags))
    }

    @Test
    fun `Done closes as it always has while the flag is not set`() {
        assertEquals(DoneButton.CLOSES, DoneButtonRule.forTopic("prod-db", store()))
        assertEquals(
            DoneButton.CLOSES,
            DoneButtonRule.forTopic("prod-db", store("flutter.topic_challenge_owed.prod-db" to false)),
        )
    }

    @Test
    fun `Done closes on a card that does not know its topic`() {
        val flags = store("flutter.topic_challenge_owed.prod-db" to true)
        assertEquals(DoneButton.CLOSES, DoneButtonRule.forTopic(null, flags))
    }

    /** Read-only preferences over a map, typed the way Android's are. */
    private class FakePrefs(private val values: Map<String, Any?>) : SharedPreferences {
        override fun getAll(): MutableMap<String, *> = values.toMutableMap()

        override fun getString(key: String?, defValue: String?): String? =
            if (values.containsKey(key)) values[key] as String? else defValue

        // Throws ClassCastException for another type, as the real one does.
        override fun getBoolean(key: String?, defValue: Boolean): Boolean =
            if (values.containsKey(key)) values[key] as Boolean else defValue

        override fun getStringSet(key: String?, defValues: MutableSet<String>?): MutableSet<String>? = defValues

        override fun getInt(key: String?, defValue: Int): Int = defValue

        override fun getLong(key: String?, defValue: Long): Long = defValue

        override fun getFloat(key: String?, defValue: Float): Float = defValue

        override fun contains(key: String?): Boolean = values.containsKey(key)

        override fun edit(): SharedPreferences.Editor = throw UnsupportedOperationException()

        override fun registerOnSharedPreferenceChangeListener(
            listener: SharedPreferences.OnSharedPreferenceChangeListener?,
        ) = Unit

        override fun unregisterOnSharedPreferenceChangeListener(
            listener: SharedPreferences.OnSharedPreferenceChangeListener?,
        ) = Unit
    }
}
