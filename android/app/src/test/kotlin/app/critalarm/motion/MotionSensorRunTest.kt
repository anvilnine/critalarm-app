package app.critalarm.motion

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Stands in for the accelerometer and counts what it was asked. */
private class FakeAccelerometer(
    override var isAvailable: Boolean = true,
    private val startsFine: Boolean = true,
) : AccelerometerSource {
    var starts = 0
    var stops = 0
    private var handler: ((List<Double>) -> Unit)? = null

    /** Whether the hardware would be on right now. */
    val isOn: Boolean get() = handler != null

    override fun start(onReading: (List<Double>) -> Unit): Boolean {
        starts++
        if (!startsFine) return false
        handler = onReading
        return true
    }

    override fun stop() {
        stops++
        handler = null
    }

    fun read(vararg values: Double) {
        handler?.invoke(values.toList())
    }
}

class MotionSensorRunTest {
    private val source = FakeAccelerometer()
    private val readings = ArrayList<List<Double>>()

    private fun run(inFront: Boolean = true): MotionSensorRun {
        val run = MotionSensorRun(source)
        run.onReading = { readings.add(it) }
        if (inFront) run.appCameToFront()
        return run
    }

    @Test
    fun `start turns the sensor on once`() {
        val run = run()
        assertFalse(source.isOn)
        assertEquals(MotionSensorRun.StartAnswer.STARTED, run.start())
        assertEquals(MotionSensorRun.StartAnswer.STARTED, run.start())
        assertEquals(1, source.starts)
        assertTrue(run.isRunning)
        assertTrue(source.isOn)
    }

    @Test
    fun `a phone with no accelerometer says so and starts nothing`() {
        source.isAvailable = false
        val run = run()
        assertEquals(MotionSensorRun.StartAnswer.NO_ACCELEROMETER, run.start())
        assertEquals(0, source.starts)
        assertFalse(run.isRunning)
    }

    @Test
    fun `a sensor the system will not start reads as none and is let go`() {
        val refused = FakeAccelerometer(startsFine = false)
        val run = MotionSensorRun(refused)
        run.appCameToFront()
        assertEquals(MotionSensorRun.StartAnswer.NO_ACCELEROMETER, run.start())
        assertFalse(run.isRunning)
        assertEquals(1, refused.stops)
    }

    @Test
    fun `readings go out as they came`() {
        val run = run()
        run.start()
        source.read(0.1, -0.2, -1.0, 12.5)
        assertEquals(listOf(listOf(0.1, -0.2, -1.0, 12.5)), readings)
    }

    @Test
    fun `stop turns the sensor off`() {
        val run = run()
        run.start()
        run.stop()
        assertFalse(run.isRunning)
        assertFalse(source.isOn)
        assertEquals(1, source.stops)
    }

    @Test
    fun `stop tells the source even when nothing runs`() {
        val run = run()
        run.stop()
        run.stop()
        assertEquals(2, source.stops)
        assertEquals(0, source.starts)
    }

    @Test
    fun `pausing the activity turns the sensor off by itself`() {
        val run = run()
        run.start()
        run.appLeftFront()
        assertFalse(run.isRunning)
        assertFalse(source.isOn)
    }

    @Test
    fun `it does not start before the activity has resumed`() {
        val run = run(inFront = false)
        assertEquals(MotionSensorRun.StartAnswer.NOT_IN_FRONT, run.start())
        assertEquals(0, source.starts)
        assertFalse(run.isRunning)
    }

    @Test
    fun `it does not start while the activity is paused`() {
        val run = run()
        run.appLeftFront()
        assertEquals(MotionSensorRun.StartAnswer.NOT_IN_FRONT, run.start())
        assertEquals(0, source.starts)
    }

    @Test
    fun `coming back does not turn it on until asked`() {
        val run = run()
        run.start()
        run.appLeftFront()
        run.appCameToFront()
        assertFalse(run.isRunning)
        assertFalse(source.isOn)
        assertEquals(1, source.starts)
        assertEquals(MotionSensorRun.StartAnswer.STARTED, run.start())
        assertEquals(2, source.starts)
        assertTrue(source.isOn)
    }

    @Test
    fun `an old stop cannot end a newer start`() {
        // A widget that remounts in one frame: start new, then stop old.
        val run = run()
        assertEquals(MotionSensorRun.StartAnswer.STARTED, run.start(1))
        assertEquals(MotionSensorRun.StartAnswer.STARTED, run.start(2))
        assertEquals(1, source.starts)
        run.stopFrom(1)
        assertTrue(run.isRunning)
        assertTrue(source.isOn)
        assertEquals(2, run.owner)
        run.stopFrom(2)
        assertFalse(run.isRunning)
        assertFalse(source.isOn)
    }

    @Test
    fun `a start that was refused owns nothing`() {
        val run = run()
        run.start(1)
        run.appLeftFront()
        assertEquals(MotionSensorRun.StartAnswer.NOT_IN_FRONT, run.start(2))
        assertNull(run.owner)
    }

    @Test
    fun `pausing ends it whoever owns it`() {
        val run = run()
        run.start(3)
        run.appLeftFront()
        assertFalse(source.isOn)
        assertNull(run.owner)
    }

    @Test
    fun `a reading is in g with the signs an iPhone uses, and seconds`() {
        // Flat on a desk, screen up: Android says +9.81 on z.
        val flat = MotionUnits.reading(floatArrayOf(0f, 0f, 9.80665f), 2_500_000_000L)!!
        assertEquals(0.0, flat[0], 1e-6)
        assertEquals(0.0, flat[1], 1e-6)
        assertEquals(-1.0, flat[2], 1e-6)
        assertEquals(2.5, flat[3], 1e-9)
        val moving = MotionUnits.reading(floatArrayOf(19.6133f, -4.903325f, 0f), 0L)!!
        assertEquals(-2.0, moving[0], 1e-5)
        assertEquals(0.5, moving[1], 1e-5)
    }

    @Test
    fun `a reading with fewer than three values is none`() {
        assertNull(MotionUnits.reading(floatArrayOf(1f, 2f), 0L))
    }
}
