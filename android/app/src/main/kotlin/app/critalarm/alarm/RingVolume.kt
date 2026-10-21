package app.critalarm.alarm

/** The alarm stream's volume: the phone's AudioManager, or a fake in tests. */
interface AlarmStream {
    val volume: Int
    val max: Int
    fun set(volume: Int)
}

/**
 * Where the volume from before a ring is kept. On disk, so a process that
 * dies mid-ring does not leave the phone at full volume for good.
 */
interface SavedVolume {
    fun read(): Int?
    fun write(volume: Int)
    fun clear()
}

/**
 * The volume rule for a ring, apart from Android so it is tested on the JVM.
 *
 * Every ring is loud, whatever the person did to the last one. A volume-down
 * press or a snooze means the next ring comes back at full volume.
 */
class RingVolume(private val stream: AlarmStream, private val saved: SavedVolume) {
    /**
     * Called on every start, also while the sound already plays. Saves the
     * volume from before the ring, once, and before it changes anything,
     * then sets the stream to its maximum.
     *
     * A saved value that is already there is kept: it is the volume from
     * before the first ring, from a ring still going, or from a process that
     * died mid-ring.
     */
    fun raise() {
        if (saved.read() == null) saved.write(stream.volume)
        val max = stream.max
        if (stream.volume < max) stream.set(max)
    }

    /**
     * While ringing: puts a lowered stream back to its maximum. Returns
     * whether it had to.
     */
    fun holdAtMax(): Boolean {
        val max = stream.max
        if (stream.volume >= max) return false
        stream.set(max)
        return true
    }

    /**
     * The ring is over: the stream goes back to the saved volume and the
     * saved value is dropped. Does nothing when nothing was saved.
     */
    fun restore() {
        val volume = saved.read() ?: return
        try {
            stream.set(volume)
        } finally {
            saved.clear()
        }
    }

    /**
     * App start. A saved volume while nothing rings means the process died
     * mid-ring, so it is put back now. Returns whether it was.
     */
    fun recover(ringing: Boolean): Boolean {
        if (ringing || saved.read() == null) return false
        restore()
        return true
    }
}
