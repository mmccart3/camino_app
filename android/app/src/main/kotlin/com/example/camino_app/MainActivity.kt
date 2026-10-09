package com.example.camino_app

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.view.Surface
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity(), SensorEventListener, EventChannel.StreamHandler {
    private lateinit var sensors: SensorManager
    private var sink: EventChannel.EventSink? = null
    private var lastUpdate = 0L
    private var accuracy = SensorManager.SENSOR_STATUS_UNRELIABLE

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        sensors = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "camino/compass")
            .setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sensors.unregisterListener(this)
        sink = events
        lastUpdate = 0L
        accuracy = SensorManager.SENSOR_STATUS_UNRELIABLE
        val sensor = sensors.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
            ?: sensors.getDefaultSensor(Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR)
        if (sensor == null || !sensors.registerListener(this, sensor, SensorManager.SENSOR_DELAY_UI)) {
            events.success(null)
        }
    }

    override fun onCancel(arguments: Any?) {
        sensors.unregisterListener(this)
        sink = null
    }

    override fun onPause() {
        if (::sensors.isInitialized) sensors.unregisterListener(this)
        super.onPause()
    }

    override fun onDestroy() {
        if (::sensors.isInitialized) sensors.unregisterListener(this)
        sink = null
        super.onDestroy()
    }

    override fun onAccuracyChanged(sensor: Sensor?, value: Int) { accuracy = value }

    @Suppress("DEPRECATION")
    override fun onSensorChanged(event: SensorEvent) {
        if (sink == null || event.timestamp - lastUpdate < 100_000_000L) return
        lastUpdate = event.timestamp
        accuracy = event.accuracy
        val matrix = FloatArray(9)
        val adjusted = FloatArray(9)
        SensorManager.getRotationMatrixFromVector(matrix, event.values)
        val axes = when (windowManager.defaultDisplay.rotation) {
            Surface.ROTATION_90 -> Pair(SensorManager.AXIS_Y, SensorManager.AXIS_MINUS_X)
            Surface.ROTATION_180 -> Pair(SensorManager.AXIS_MINUS_X, SensorManager.AXIS_MINUS_Y)
            Surface.ROTATION_270 -> Pair(SensorManager.AXIS_MINUS_Y, SensorManager.AXIS_X)
            else -> Pair(SensorManager.AXIS_X, SensorManager.AXIS_Y)
        }
        SensorManager.remapCoordinateSystem(matrix, axes.first, axes.second, adjusted)
        val angles = FloatArray(3)
        SensorManager.getOrientation(adjusted, angles)
        val heading = (Math.toDegrees(angles[0].toDouble()) + 360.0) % 360.0
        sink?.success(mapOf("heading" to heading,
            "reliable" to (accuracy >= SensorManager.SENSOR_STATUS_ACCURACY_MEDIUM)))
    }
}
