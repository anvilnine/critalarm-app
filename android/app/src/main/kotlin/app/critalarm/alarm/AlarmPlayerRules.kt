package app.critalarm.alarm

/**
 * The threading and identity rules [AlarmPlayer] follows, apart from Android
 * so they are tested on the JVM.
 */
object AlarmPlayerRules {
    /**
     * Runs [action] now when called on the main thread, otherwise posts it
     * there. [AlarmPlayer] is called from the FCM worker thread as well as
     * from main, and its own callbacks run on main, so every read and write
     * of its players happens on main and none of them race.
     */
    fun onMain(isMainThread: Boolean, post: (() -> Unit) -> Unit, action: () -> Unit) {
        if (isMainThread) action() else post(action)
    }

    /**
     * A callback from [owner] still speaks for the ring only while [owner]
     * is the current one. A late callback from a player that was stopped or
     * replaced is dropped, so it can never start a second sound.
     */
    fun isCurrent(owner: Any, current: Any?): Boolean = current != null && owner === current

    /**
     * Whether a start should ring anew. A loop that is still alive or a
     * MediaPlayer that is still playing means the alarm is already sounding;
     * anything else (a failed writer, a finished single pass, a MediaPlayer
     * that errored or stopped) is dead and is replaced.
     */
    fun shouldRing(loopAlive: Boolean, mediaPlaying: Boolean): Boolean = !loopAlive && !mediaPlaying
}
