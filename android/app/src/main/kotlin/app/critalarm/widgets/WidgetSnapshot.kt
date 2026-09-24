package app.critalarm.widgets

import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant

/**
 * The one document the home screen widgets read.
 *
 * Dart writes it through [WidgetChannel] and the push and action paths patch it
 * here. The format is `backlog/home-widgets-plan.md` section 1, the same bytes
 * iOS keeps in its app group. `test/fixtures/widget_snapshot_v1.json` is the
 * sample every platform's tests read.
 */
data class WidgetSnapshot(
    val updatedAt: Long,
    val connected: Boolean,
    val openCount: Int,
    val topics: List<WidgetTopic>,
) {
    /** Topics with an open incident first, then acked, then quiet, each by name. */
    fun sorted(): WidgetSnapshot = copy(topics = topics.sortedWith(DISPLAY_ORDER))

    /** [openCount] as the sum of the topic counts. */
    fun recounted(): WidgetSnapshot = copy(openCount = topics.sumOf { it.count })

    companion object {
        const val VERSION = 1
        const val MAX_TOPICS = 50
        const val TITLE_MAX_LENGTH = 120
        const val STALE_AFTER_SECONDS = 900L

        const val OPEN = "open"
        const val ACKED = "acked"

        /** What sign out writes: nothing to show and nothing to fetch. */
        fun disconnected(nowSeconds: Long) = WidgetSnapshot(
            updatedAt = nowSeconds,
            connected = false,
            openCount = 0,
            topics = emptyList(),
        )

        private fun group(topic: WidgetTopic) = when (topic.incident?.state) {
            OPEN -> 0
            ACKED -> 1
            else -> 2
        }

        private val DISPLAY_ORDER = compareBy<WidgetTopic>({ group(it) }, { it.name })

        /** True when [a] is shown over [b]: open beats acked, then newer, then the smaller id. */
        internal fun wins(a: WidgetIncident, b: WidgetIncident): Boolean {
            if ((a.state == OPEN) != (b.state == OPEN)) return a.state == OPEN
            if (a.openedAt != b.openedAt) return a.openedAt > b.openedAt
            return a.id < b.id
        }

        /**
         * Trimmed, cut to [TITLE_MAX_LENGTH] code points (the same cut Dart
         * and Swift make), and the topic name when empty.
         */
        internal fun title(raw: String?, topic: String): String {
            val picked = raw?.trim()?.takeIf { it.isNotEmpty() } ?: topic
            if (picked.codePointCount(0, picked.length) <= TITLE_MAX_LENGTH) return picked
            return picked.substring(0, picked.offsetByCodePoints(0, TITLE_MAX_LENGTH))
        }
    }
}

data class WidgetTopic(
    val name: String,
    val critical: Boolean,
    /** Open plus acked incidents on this topic. */
    val count: Int,
    val incident: WidgetIncident?,
)

data class WidgetIncident(
    val id: String,
    /** `open` or `acked`. */
    val state: String,
    val title: String,
    /** Epoch seconds, 0 when unknown. */
    val openedAt: Long,
    /** Epoch seconds, null while open. */
    val ackedAt: Long?,
)

object WidgetSnapshotJson {
    /** The snapshot in [json], or null for anything that is not version 1. */
    fun parse(json: String?): WidgetSnapshot? {
        if (json == null) return null
        return runCatching {
            val root = JSONObject(json)
            if (root.optInt("v", -1) != WidgetSnapshot.VERSION) return null
            val topics = root.getJSONArray("topics")
            WidgetSnapshot(
                updatedAt = root.getLong("updated_at"),
                connected = root.getBoolean("connected"),
                openCount = root.getInt("open_count"),
                topics = (0 until topics.length()).map { parseTopic(topics.getJSONObject(it)) },
            )
        }.getOrNull()
    }

    private fun parseTopic(json: JSONObject): WidgetTopic {
        val incident = json.optJSONObject("incident")
        return WidgetTopic(
            name = json.getString("name"),
            critical = json.getBoolean("critical"),
            count = json.getInt("count"),
            incident = incident?.let {
                WidgetIncident(
                    id = it.getString("id"),
                    state = it.getString("state"),
                    title = it.getString("title"),
                    openedAt = it.getLong("opened_at"),
                    ackedAt = if (it.isNull("acked_at")) null else it.getLong("acked_at"),
                )
            },
        )
    }

    fun write(snapshot: WidgetSnapshot): String = JSONObject().apply {
        put("v", WidgetSnapshot.VERSION)
        put("updated_at", snapshot.updatedAt)
        put("connected", snapshot.connected)
        put("open_count", snapshot.openCount)
        put("topics", JSONArray().apply { snapshot.topics.forEach { put(writeTopic(it)) } })
    }.toString()

    private fun writeTopic(topic: WidgetTopic) = JSONObject().apply {
        put("name", topic.name)
        put("critical", topic.critical)
        put("count", topic.count)
        put(
            "incident",
            topic.incident?.let {
                JSONObject().apply {
                    put("id", it.id)
                    put("state", it.state)
                    put("title", it.title)
                    put("opened_at", it.openedAt)
                    put("acked_at", it.ackedAt ?: JSONObject.NULL)
                }
            } ?: JSONObject.NULL,
        )
    }
}

/** What a patch did. A snapshot that is missing or signed out is never patched. */
sealed class WidgetPatchResult {
    data class Changed(val snapshot: WidgetSnapshot) : WidgetPatchResult()

    object Unchanged : WidgetPatchResult()

    /**
     * The patch could not place everything, so the widget has to ask the
     * server. [partial] is what the patch could do, written stale so the next
     * redraw fetches; null keeps the old snapshot and marks it stale.
     */
    data class NeedsFetch(val partial: WidgetSnapshot? = null) : WidgetPatchResult()
}

/**
 * The four changes a push or a button makes, without a network call.
 *
 * Every one leaves a missing or signed-out snapshot alone: only the app writes
 * the first one, so a widget placed before the app was opened never fetches.
 * `ios/Shared/Widgets/WidgetSnapshot.swift` has the same four with the same
 * tests.
 */
object WidgetSnapshotPatch {
    /**
     * An `open` or `repeat` push. A new id goes on its topic, and shows if it
     * wins over the incident already there.
     */
    fun opened(
        snapshot: WidgetSnapshot?,
        incidentId: String,
        topic: String?,
        title: String?,
        openedAt: Long,
        nowSeconds: Long,
    ): WidgetPatchResult {
        if (snapshot == null || !snapshot.connected) return WidgetPatchResult.Unchanged
        if (find(snapshot, incidentId) != null) return WidgetPatchResult.Unchanged
        if (topic == null) return WidgetPatchResult.NeedsFetch()
        val at = snapshot.topics.indexOfFirst { it.name == topic }
        if (at < 0) return WidgetPatchResult.NeedsFetch()
        val current = snapshot.topics[at]
        // The topic holds incidents the snapshot does not name, and this id
        // could be one of them. Counting it again would be wrong.
        if (current.count > (if (current.incident == null) 0 else 1)) {
            return WidgetPatchResult.NeedsFetch()
        }
        val added = WidgetIncident(
            id = incidentId,
            state = WidgetSnapshot.OPEN,
            title = WidgetSnapshot.title(title, topic),
            openedAt = openedAt,
            ackedAt = null,
        )
        val shown = current.incident
        val next = current.copy(
            count = current.count + 1,
            incident = if (shown == null || WidgetSnapshot.wins(added, shown)) added else shown,
        )
        return changed(snapshot, at, next, nowSeconds)
    }

    /** A `reopen` push: the desk timer ran out on an acked incident. */
    fun reopened(snapshot: WidgetSnapshot?, incidentId: String, nowSeconds: Long): WidgetPatchResult {
        if (snapshot == null || !snapshot.connected) return WidgetPatchResult.Unchanged
        val at = find(snapshot, incidentId) ?: return WidgetPatchResult.NeedsFetch()
        val topic = snapshot.topics[at]
        val incident = topic.incident!!
        if (incident.state == WidgetSnapshot.OPEN) return WidgetPatchResult.Unchanged
        val next = topic.copy(incident = incident.copy(state = WidgetSnapshot.OPEN, ackedAt = null))
        return changed(snapshot, at, next, nowSeconds)
    }

    /**
     * An acknowledge, here or anywhere. An `acked_at` already known is kept.
     * When the topic has other incidents, one of them may now be the one to
     * show, so the change is written and a fetch asked for.
     */
    fun acked(snapshot: WidgetSnapshot?, incidentId: String, at: Long, nowSeconds: Long): WidgetPatchResult {
        if (snapshot == null || !snapshot.connected) return WidgetPatchResult.Unchanged
        val index = find(snapshot, incidentId) ?: return WidgetPatchResult.NeedsFetch()
        val topic = snapshot.topics[index]
        val incident = topic.incident!!
        if (incident.state == WidgetSnapshot.ACKED && incident.ackedAt != null) {
            return WidgetPatchResult.Unchanged
        }
        val next = topic.copy(
            incident = incident.copy(state = WidgetSnapshot.ACKED, ackedAt = incident.ackedAt ?: at),
        )
        val result = changed(snapshot, index, next, nowSeconds)
        return if (topic.count > 1) WidgetPatchResult.NeedsFetch(result.snapshot) else result
    }

    /** A close or an expiry. The topic goes quiet unless it has other incidents. */
    fun ended(snapshot: WidgetSnapshot?, incidentId: String, nowSeconds: Long): WidgetPatchResult {
        if (snapshot == null || !snapshot.connected) return WidgetPatchResult.Unchanged
        val index = find(snapshot, incidentId) ?: return WidgetPatchResult.NeedsFetch()
        val topic = snapshot.topics[index]
        val next = topic.copy(count = (topic.count - 1).coerceAtLeast(0), incident = null)
        val result = changed(snapshot, index, next, nowSeconds)
        // Another incident on this topic is still going, and the snapshot
        // does not know which.
        return if (next.count > 0) WidgetPatchResult.NeedsFetch(result.snapshot) else result
    }

    /** Index of the topic whose shown incident is [incidentId]. */
    private fun find(snapshot: WidgetSnapshot, incidentId: String): Int? =
        snapshot.topics.indexOfFirst { it.incident?.id == incidentId }.takeIf { it >= 0 }

    private fun changed(
        snapshot: WidgetSnapshot,
        index: Int,
        topic: WidgetTopic,
        nowSeconds: Long,
    ): WidgetPatchResult.Changed {
        val topics = snapshot.topics.toMutableList().also { it[index] = topic }
        return WidgetPatchResult.Changed(
            snapshot.copy(topics = topics, updatedAt = nowSeconds).sorted().recounted(),
        )
    }
}

/**
 * Builds a snapshot from the three answers the widget fetch gets
 * (api.md §3.1 and §3.2), with the same rules as Dart's `buildWidgetSnapshot`.
 */
object WidgetSnapshotBuilder {
    fun fromServer(topicsJson: String, openJson: String, ackedJson: String, nowSeconds: Long): WidgetSnapshot? {
        val topics = runCatching { JSONArray(topicsJson) }.getOrNull() ?: return null
        val open = runCatching { JSONArray(openJson) }.getOrNull() ?: return null
        val acked = runCatching { JSONArray(ackedJson) }.getOrNull() ?: return null

        val live = mutableMapOf<String, MutableList<WidgetIncident>>()
        for (list in listOf(open, acked)) {
            for (i in 0 until list.length()) {
                val json = list.optJSONObject(i) ?: continue
                val (topic, incident) = incident(json) ?: continue
                live.getOrPut(topic) { mutableListOf() }.add(incident)
            }
        }

        val built = (0 until topics.length()).mapNotNull { i ->
            val json = topics.optJSONObject(i) ?: return@mapNotNull null
            val name = string(json, "name") ?: return@mapNotNull null
            val incidents = live[name].orEmpty()
            WidgetTopic(
                name = name,
                critical = json.optBoolean("critical", false),
                count = incidents.size,
                incident = incidents.reduceOrNull { shown, next ->
                    if (WidgetSnapshot.wins(next, shown)) next else shown
                },
            )
        }
        return WidgetSnapshot(nowSeconds, connected = true, openCount = 0, topics = built)
            .sorted()
            .let { it.copy(topics = it.topics.take(WidgetSnapshot.MAX_TOPICS)) }
            .recounted()
    }

    private fun incident(json: JSONObject): Pair<String, WidgetIncident>? {
        val id = string(json, "id") ?: return null
        val topic = string(json, "topic") ?: return null
        val state = string(json, "state")
        if (state != WidgetSnapshot.OPEN && state != WidgetSnapshot.ACKED) return null
        return topic to WidgetIncident(
            id = id,
            state = state,
            title = WidgetSnapshot.title(newestText(json), topic),
            openedAt = seconds(json.opt("opened_at")) ?: 0L,
            ackedAt = if (state == WidgetSnapshot.ACKED) seconds(json.opt("acked_at")) else null,
        )
    }

    /** The newest message's title, else its text. Newest is the largest `time`. */
    private fun newestText(incident: JSONObject): String? {
        val messages = incident.optJSONArray("messages") ?: return null
        var newest: JSONObject? = null
        var newestTime = Long.MIN_VALUE
        for (i in 0 until messages.length()) {
            val message = messages.optJSONObject(i) ?: continue
            val time = message.optLong("time", 0L)
            if (time >= newestTime) {
                newest = message
                newestTime = time
            }
        }
        newest ?: return null
        return string(newest, "title")?.trim()?.takeIf { it.isNotEmpty() }
            ?: string(newest, "message")?.trim()?.takeIf { it.isNotEmpty() }
    }

    /** `optString` answers "null" for a JSON null. This answers null. */
    private fun string(json: JSONObject, key: String): String? =
        if (json.isNull(key)) null else json.optString(key).takeIf { it.isNotEmpty() }

    /**
     * Unix seconds, unix milliseconds or ISO-8601, the three shapes Dart's
     * NullableDateTimeConverter reads. Rounded down to whole seconds.
     */
    internal fun seconds(raw: Any?): Long? = when (raw) {
        is Number -> fromNumber(raw.toLong())
        is String -> raw.toLongOrNull()?.let(::fromNumber)
            ?: runCatching { Instant.parse(raw).epochSecond }.getOrNull()
        else -> null
    }

    private fun fromNumber(value: Long) = if (value < 10_000_000_000L) value else Math.floorDiv(value, 1000L)
}

object WidgetFreshness {
    /**
     * True when the widget should ask the server: a patch could not place
     * something, or nothing has been written for 15 minutes. A missing or
     * signed-out snapshot is never stale.
     */
    fun isStale(snapshot: WidgetSnapshot?, nowSeconds: Long): Boolean {
        if (snapshot == null || !snapshot.connected) return false
        return snapshot.updatedAt == 0L ||
            nowSeconds - snapshot.updatedAt >= WidgetSnapshot.STALE_AFTER_SECONDS
    }

    /**
     * What a finished fetch stores. When a patch or an app write landed while
     * the GETs ran, [fetched] may be older than what is stored, so the stored
     * snapshot stays and is marked stale for the next redraw to fetch again.
     */
    fun afterFetch(
        fetched: WidgetSnapshot,
        current: WidgetSnapshot?,
        changedMeanwhile: Boolean,
    ): WidgetSnapshot? = if (!changedMeanwhile) fetched else current?.copy(updatedAt = 0L)
}
