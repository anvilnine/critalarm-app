package app.critalarm.storage

import android.content.Context
import android.content.SharedPreferences

/**
 * The one thing native code knows about wake-up challenges: whether a topic
 * owes one before its incident is closed.
 *
 * Dart writes the flag, one per topic, and only when it is sure. Nothing
 * here works a plan out. `ChallengeChoices.owedKeyPrefix` in
 * lib/features/challenges/domain/challenge_choices.dart holds the same
 * word. Keep the two in step.
 *
 * The flag is about the Done button on a card that is already acknowledged.
 * It is never read on the way to stopping a ring. A flag that is missing,
 * or that does not read as a boolean, is "nothing owed", so the card closes
 * the incident as it always has.
 */
class ChallengeFlagStore(private val preferences: SharedPreferences) {
    constructor(context: Context) : this(
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE),
    )

    /** True only while Dart's last sure answer for [topic] was "owed". */
    fun owesChallenge(topic: String?): Boolean {
        if (topic.isNullOrEmpty()) return false
        return try {
            preferences.getBoolean(keyFor(topic), false)
        } catch (e: ClassCastException) {
            false
        }
    }

    companion object {
        fun keyFor(topic: String) = "flutter.topic_challenge_owed.$topic"
    }
}

/** What Done on an acknowledged card does. */
enum class DoneButton {
    /** Closes the incident from the card, with no app. What it always did. */
    CLOSES,

    /**
     * Opens the app on the incident's acknowledged screen and closes
     * nothing. The challenge is asked there, with its way out on screen.
     */
    OPENS_APP,
}

object DoneButtonRule {
    /**
     * [topic] is the card's topic, null when the card does not know it. A
     * card with no topic closes, as it always has.
     */
    fun forTopic(topic: String?, flags: ChallengeFlagStore): DoneButton =
        if (flags.owesChallenge(topic)) DoneButton.OPENS_APP else DoneButton.CLOSES
}
