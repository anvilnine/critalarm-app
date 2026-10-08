package app.critalarm.motion

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The accelerometer through `SensorManager`.
 *
 * `TYPE_ACCELEROMETER` at `SENSOR_DELAY_GAME` (a reading about every 20 ms)
 * needs no permission. `HIGH_SAMPLING_RATE_SENSORS` is only for rates above
 * 200 a second, which this never asks for. The listener is registered on
 * the main thread, so the readings arrive there.
 */
class DeviceAccelerometer(context: Context) : AccelerometerSource, SensorEventListener {
    private val manager = context.getSystemService(SensorManager::class.java)
    private var onReading: ((List<Double>) -> Unit)? = null

    private val sensor: Sensor?
        get() = manager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)

    override val isAvailable: Boolean
        get() = sensor != null

    override fun start(onReading: (List<Double>) -> Unit): Boolean {
        val manager = manager ?: return false
        val sensor = sensor ?: return false
        this.onReading = onReading
        return manager.registerListener(this, sensor, SensorManager.SENSOR_DELAY_GAME)
    }

    override fun stop() {
        onReading = null
        manager?.unregisterListener(this)
    }

    override fun onSensorChanged(event: SensorEvent) {
        val reading = MotionUnits.reading(event.values, event.timestamp) ?: return
        onReading?.invoke(reading)
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
}

/**
 * The accelerometer for the shake challenge, on two channels of its own.
 *
 * [NAME] has `start` and `stop`. [READINGS_NAME] carries each reading as a
 * list of x, y, z in g and the time in seconds. [MotionSensorRun] decides
 * when the sensor runs. The Dart half is `lib/core/motion/motion_sensor.dart`.
 *
 * A `start` on a phone with no accelerometer answers the error
 * [NO_ACCELEROMETER], which Dart turns into the tap fallback. A `start`
 * while the activity is not resumed answers false and starts nothing.
 */
class MotionSensorChannel(context: Context) : EventChannel.StreamHandler {
    companion object {
        const val NAME = "app.critalarm/motion"
        const val READINGS_NAME = "app.critalarm/motion/readings"
        private const val NO_ACCELEROMETER = "no_accelerometer"
    }

    private val run = MotionSensorRun(DeviceAccelerometer(context))
    private var sink: EventChannel.EventSink? = null

    init {
        run.onReading = { reading -> sink?.success(reading) }
    }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> when (run.start()) {
                MotionSensorRun.StartAnswer.STARTED -> result.success(true)
                MotionSensorRun.StartAnswer.NOT_IN_FRONT -> result.success(false)
                MotionSensorRun.StartAnswer.NO_ACCELEROMETER ->
                    result.error(NO_ACCELEROMETER, "This phone has no accelerometer", null)
            }
            "stop" -> {
                run.stop()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    /**
     * Dart stopped listening. That alone turns the sensor off, whether or
     * not a `stop` follows.
     */
    override fun onCancel(arguments: Any?) {
        sink = null
        run.stop()
    }

    /** The activity resumed. */
    fun appCameToFront() = run.appCameToFront()

    /** The activity paused: the sensor goes off, whatever Dart does. */
    fun appLeftFront() = run.appLeftFront()

    /** The engine is going away. */
    fun dispose() {
        sink = null
        run.stop()
    }
}
