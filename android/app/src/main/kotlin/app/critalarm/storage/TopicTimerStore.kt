package app.critalarm.storage

import android.content.Context

data class TopicTimers(
    val repeatIntervalS: Int,
    val maxRingS: Int,
    val deskTimerS: Int,
)

/**
 * The per-topic timers, cached by Dart so the notification can read them with
 * no Flutter engine running.
 *
 * They are topic settings from GET /v1/topics, not push fields, so a card
 * built straight off an FCM message has no other way to learn them. Missing or
 * unreadable means no countdown bar. Never a guessed default: a bar counting
 * down the wrong number is worse than no bar.
 */
class TopicTimerStore(context: Context) {
    private val preferences =
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

    fun timersFor(topic: String): TopicTimers? =
        parse(preferences.getString(keyFor(topic), null))

    companion object {
        fun keyFor(topic: String) = "flutter.topic_timers.$topic"

        fun parse(raw: String?): TopicTimers? {
            val parts = raw?.split('|') ?: return null
            if (parts.size != 3) return null
            val numbers = parts.map { it.trim().toIntOrNull() ?: return null }
            if (numbers.any { it <= 0 }) return null
            return TopicTimers(numbers[0], numbers[1], numbers[2])
        }
    }
}
