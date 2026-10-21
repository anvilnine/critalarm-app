package app.critalarm.alarm

/**
 * Dart's `releaseLockScreen` calls that wait for the window to leave the
 * lock screen.
 *
 * The alarm screen keeps its ringing layout until its release is answered,
 * so the acknowledged and failure layouts never draw over the lock screen.
 * On a locked phone the window leaves only once the unlock prompt answers,
 * and every release that came in meanwhile is answered then, once each.
 */
class LockReleaseAnswers {
    private val waiting = mutableListOf<() -> Unit>()

    val isEmpty: Boolean get() = waiting.isEmpty()

    fun add(answer: () -> Unit) {
        waiting += answer
    }

    /** Answers everything waiting. An answer added while this runs waits for the next call. */
    fun answerAll() {
        val now = waiting.toList()
        waiting.clear()
        now.forEach { it() }
    }
}
