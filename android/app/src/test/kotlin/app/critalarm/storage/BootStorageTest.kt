package app.critalarm.storage

import android.content.SharedPreferences
import app.critalarm.alarm.PrefsSavedVolume
import app.critalarm.l10n.NativeLocale
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * What sits in device-protected storage, which anyone holding the phone can
 * reach before it is unlocked. Every key the ring path writes there is listed
 * and checked: no token, no session, no account data.
 */
class BootStorageTest {
    private val token = "tok_9f2a7c1e"
    private val deviceToken = "dvt_51bd02"
    private val server = "https://alarm.example.com"

    private fun prefs(vararg values: Pair<String, Any>): InMemoryPreferences =
        InMemoryPreferences().apply {
            val edit = edit()
            values.forEach { (key, value) -> BootMigration.putValue(edit, key, value) }
            edit.commit()
        }

    /**
     * Dart's preferences on a phone in daily use: the ring settings next to
     * everything that must never leave normal storage.
     */
    private fun dartPrefs() = prefs(
        BootMirror.SESSION_KEY to "$server|acc_77|dev_31|$token",
        "flutter.device_id" to "dev_31",
        "flutter.device_token" to deviceToken,
        "flutter.pending_push_token" to "fcm_0a1b2c",
        "flutter.account_id" to "acc_77",
        "flutter.account_email_hint" to "someone",
        "flutter.pending_acks" to """[{"incident_id":"inc_a","token":"$token"}]""",
        "flutter.pending_push_events" to "[]",
        "flutter.has_completed_showcase_tour" to true,
        "flutter.topic_critical.prod" to true,
        "flutter.topic_critical.staging" to false,
        "flutter.topic_timers.prod" to "30|1800|600",
        "flutter.topic_challenge_owed.prod" to true,
        "flutter.quiet_hours_enabled" to true,
        "flutter.quiet_hours_start_minutes" to 1320L,
        "flutter.quiet_hours_end_minutes" to 420L,
        "flutter.quiet_hours_critical_rings" to true,
        "flutter.alarm_sound_default" to "submarine_dive_horn",
        "flutter.alarm_sound_per_topic" to """{"prod":"classic_siren"}""",
        "flutter.alarm_sound_user_list" to """[{"id":"user_1","path":"/data/user/0/app/files/sounds/user_1.wav"}]""",
        "flutter.alarm_sound_own_locked" to false,
        "flutter.ring_bright_screen" to true,
        "flutter.ring_vibrate" to false,
        "flutter.quiet_alarm" to false,
    )

    /** Every device-protected file, filled the way the ring path fills it. */
    private fun deviceStorage(): Map<String, SharedPreferences> {
        val incidents = InMemoryPreferences()
        IncidentDeliveryStore(incidents).apply {
            activate("inc_a")
            bumpRingGeneration("inc_a")
            rememberRingUntil("inc_a", 1_757_464_200_000L)
            rememberTopic("inc_a", "prod")
            rememberServer("inc_a", server)
            rememberContent("inc_a", "Disk full", "db-1 at 99%")
            rememberChain("inc_a", StoredChain("ring", 1_757_464_200_000L, 30, listOf(1L, 2L)))
            rememberDeskTimerFiresAt("inc_a", 1_757_463_000_000L)
            markLocallyAcknowledged("inc_a", 1_757_462_500_000L)
            markClosed("inc_b", 1_757_462_500_000L)
            rememberRearmedBoot(4)
        }
        val volume = InMemoryPreferences()
        PrefsSavedVolume(volume).write(6)
        val locale = prefs(NativeLocale.KEY to "ja")
        val mirror = InMemoryPreferences()
        BootMirror.copy(from = dartPrefs(), to = mirror)
        return mapOf(
            BootStorage.INCIDENTS to incidents,
            BootStorage.RING_VOLUME to volume,
            BootStorage.LOCALE to locale,
            BootStorage.MIRROR to mirror,
        )
    }

    private val forbidden = Regex("token|session|account|credential|secret|password|auth|device_id|email|ack", RegexOption.IGNORE_CASE)

    @Test
    fun `this test covers every device-protected file`() {
        assertEquals(BootStorage.FILES.toSet(), deviceStorage().keys)
    }

    @Test
    fun `no key in device-protected storage is a token or account key`() {
        val keys = deviceStorage().flatMap { (file, prefs) -> prefs.all.keys.map { "$file/$it" } }
        assertTrue(keys.isNotEmpty())
        // Acks are allowed as the incident's own flags, which hold no token.
        val allowedAckKeys = Regex("/(acknowledged|acked_at|local_acked_at):")
        val bad = keys.filter { forbidden.containsMatchIn(it.substringAfter('/')) && !allowedAckKeys.containsMatchIn(it) }
        assertEquals("keys that must stay in normal storage: $bad", emptyList<String>(), bad)
    }

    @Test
    fun `no value in device-protected storage holds a token`() {
        val values = deviceStorage().values.flatMap { it.all.values }.map { it.toString() }
        for (secret in listOf(token, deviceToken, "fcm_0a1b2c", "acc_77", "dev_31")) {
            assertTrue("$secret leaked", values.none { it.contains(secret) })
        }
    }

    @Test
    fun `the copy holds exactly what the ring reads`() {
        val mirror = InMemoryPreferences()
        BootMirror.copy(from = dartPrefs(), to = mirror)

        assertEquals(
            setOf(
                BootMirror.SERVER_KEY,
                "flutter.topic_critical.prod",
                "flutter.topic_critical.staging",
                "flutter.topic_timers.prod",
                "flutter.topic_challenge_owed.prod",
                "flutter.quiet_hours_enabled",
                "flutter.quiet_hours_start_minutes",
                "flutter.quiet_hours_end_minutes",
                "flutter.quiet_hours_critical_rings",
                "flutter.alarm_sound_default",
                "flutter.alarm_sound_per_topic",
                "flutter.ring_bright_screen",
                "flutter.ring_vibrate",
                "flutter.quiet_alarm",
            ),
            mirror.all.keys,
        )
        assertEquals(server, mirror.getString(BootMirror.SERVER_KEY, null))
        assertFalse(mirror.getBoolean("flutter.topic_critical.staging", true))
        assertEquals(1320L, mirror.getLong("flutter.quiet_hours_start_minutes", 0L))
        assertEquals("submarine_dive_horn", mirror.getString("flutter.alarm_sound_default", null))
    }

    @Test
    fun `a key Dart drops goes from the copy too`() {
        val dart = dartPrefs()
        val mirror = InMemoryPreferences()
        BootMirror.copy(dart, mirror)

        dart.edit().remove("flutter.topic_critical.staging").remove(BootMirror.SESSION_KEY).commit()
        assertTrue(BootMirror.copy(dart, mirror))

        assertFalse(mirror.contains("flutter.topic_critical.staging"))
        assertFalse(mirror.contains(BootMirror.SERVER_KEY))
        assertTrue(mirror.contains("flutter.topic_critical.prod"))
    }

    @Test
    fun `a copy already in step writes nothing`() {
        val dart = dartPrefs()
        val mirror = InMemoryPreferences()
        assertTrue(BootMirror.copy(dart, mirror))
        assertFalse(BootMirror.copy(dart, mirror))
    }

    @Test
    fun `only the address is cut out of the session`() {
        assertEquals(server, BootMirror.serverAddress("$server|a|b|$token"))
        assertEquals("http://10.0.2.2:8080", BootMirror.serverAddress("http://10.0.2.2:8080|a|b|c"))
        assertNull(BootMirror.serverAddress(null))
        assertNull(BootMirror.serverAddress(""))
        assertNull(BootMirror.serverAddress("not a url|a|b|c"))
        assertNull(BootMirror.serverAddress("ftp://alarm.example.com|a|b|c"))
        assertNull(BootMirror.serverAddress("https://user:$token@alarm.example.com|a|b|c"))
    }

    @Test
    fun `the listener follows the keys the copy holds and nothing else`() {
        assertTrue(BootMirror.follows(BootMirror.SESSION_KEY))
        assertTrue(BootMirror.follows("flutter.topic_critical.prod"))
        assertTrue(BootMirror.follows("flutter.ring_vibrate"))
        assertTrue(BootMirror.follows(null))
        assertFalse(BootMirror.follows("flutter.device_token"))
        assertFalse(BootMirror.follows("flutter.pending_push_events"))
    }

    @Test
    fun `moving a file keeps what was written since the reboot and empties the old copy`() {
        val old = prefs("active:inc_a" to true, "ring_until:inc_a" to 100L, "topic:inc_a" to "prod")
        val moved = prefs("ring_until:inc_a" to 200L)

        assertEquals(2, BootMigration.merge(from = old, to = moved))

        assertEquals(200L, moved.getLong("ring_until:inc_a", 0L))
        assertTrue(moved.getBoolean("active:inc_a", false))
        assertEquals("prod", moved.getString("topic:inc_a", null))
        assertTrue(old.all.isEmpty())
    }

    @Test
    fun `moving an empty file changes nothing`() {
        val moved = prefs("active:inc_a" to true)
        assertEquals(0, BootMigration.merge(from = InMemoryPreferences(), to = moved))
        assertEquals(mapOf("active:inc_a" to true), moved.all)
    }

    @Test
    fun `the incident text and server stay with the incident and go when it is pruned`() {
        val prefs = InMemoryPreferences()
        val store = IncidentDeliveryStore(prefs)
        store.rememberContent("inc_a", "Disk full", null)
        store.rememberContent("inc_a", null, "db-1 at 99%")
        store.rememberServer("inc_a", server)
        assertEquals("Disk full", store.titleOf("inc_a"))
        assertEquals("db-1 at 99%", store.bodyOf("inc_a"))
        assertEquals(server, store.serverOf("inc_a"))

        store.markClosed("inc_a", 1L)
        store.rememberRearmedBoot(3)
        store.prune(nowMillis = 1L + 400L * 24 * 60 * 60 * 1000)

        assertNull(store.titleOf("inc_a"))
        assertNull(store.bodyOf("inc_a"))
        assertNull(store.serverOf("inc_a"))
        assertEquals(3, store.rearmedBootCount())
    }
}
