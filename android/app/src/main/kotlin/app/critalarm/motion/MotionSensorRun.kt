package app.critalarm.motion

/**
 * What the shake challenge needs from the phone: the accelerometer, and
 * nothing else of its motion hardware.
 *
 * An interface so the rules in [MotionSensorRun] are tested on the JVM with
 * a made-up source, with no phone.
 */
interface AccelerometerSource {
    /** Whether this phone has an accelerometer. */
    val isAvailable: Boolean

    /**
     * Starts readings. Each is x, y, z in g and the sensor's own time in
     * seconds. False when the system would not start them.
     */
    fun start(onReading: (List<Double>) -> Unit): Boolean

    /** Stops readings. Safe to call when none are running. */
    fun stop()
}

/** How an Android reading becomes the one Dart is sent. */
object MotionUnits {
    /** `SensorManager.GRAVITY_EARTH`, written out so this runs on the JVM. */
    const val GRAVITY = 9.80665

    /**
     * x, y, z in g and the time in seconds.
     *
     * Android reports metres per second squared and reads +9.81 on z for a
     * phone flat on a desk with the screen up. An iPhone reports g and reads
     * -1 there. Dart gets the iPhone's units and signs from both, so one rule
     * counts shakes on both.
     */
    fun reading(values: FloatArray, timestampNanos: Long): List<Double>? {
        if (values.size < 3) return null
        return listOf(
            -values[0] / GRAVITY,
            -values[1] / GRAVITY,
            -values[2] / GRAVITY,
            timestampNanos / 1_000_000_000.0,
        )
    }
}

/**
 * When the accelerometer runs, and when it does not.
 *
 * It runs between a [start] and the first of: a [stop], or the activity
 * pausing ([appLeftFront]). It never starts while the activity is not
 * resumed, and it never starts again by itself: Dart asks when it wants it
 * back. So a mistake on the Dart side cannot leave the sensor on behind a
 * locked screen.
 *
 * Every call arrives on the main thread, and so do the readings.
 */
class MotionSensorRun(private val source: AccelerometerSource) {
    enum class StartAnswer { STARTED, NO_ACCELEROMETER, NOT_IN_FRONT }

    /** Where a reading goes. */
    var onReading: ((List<Double>) -> Unit)? = null

    var isRunning = false
        private set

    private var isInFront = false

    fun start(): StartAnswer {
        if (!source.isAvailable) return StartAnswer.NO_ACCELEROMETER
        if (!isInFront) return StartAnswer.NOT_IN_FRONT
        if (isRunning) return StartAnswer.STARTED
        isRunning = true
        val started = source.start { reading ->
            // A reading that was on its way when the sensor stopped is dropped.
            if (isRunning) onReading?.invoke(reading)
        }
        if (!started) {
            stop()
            return StartAnswer.NO_ACCELEROMETER
        }
        return StartAnswer.STARTED
    }

    /**
     * Stops the sensor. The source is told every time, running or not, so
     * nothing depends on this class having kept count.
     */
    fun stop() {
        isRunning = false
        source.stop()
    }

    /** The activity resumed. The sensor stays off until it is asked for. */
    fun appCameToFront() {
        isInFront = true
    }

    /** The activity paused. The sensor goes off by itself. */
    fun appLeftFront() {
        isInFront = false
        stop()
    }
}
