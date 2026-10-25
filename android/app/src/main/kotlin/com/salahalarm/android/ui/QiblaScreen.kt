package com.salahalarm.android.ui

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.hardware.GeomagneticField
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.salahalarm.android.Graph
import com.salahalarm.android.t
import com.salahalarm.android.tf
import com.salahalarm.core.QiblaMath
import kotlin.math.abs
import kotlin.math.roundToInt

/** Compass pointing at the Kaaba, from the rotation-vector sensor. Port of iOS QiblaCompassView. */
@Composable
fun QiblaScreen(onBack: () -> Unit) {
    val context = LocalContext.current
    val location by Graph.repo.location.collectAsState()
    var heading by remember { mutableFloatStateOf(0f) }
    var hasSensor by remember { mutableStateOf(true) }
    var accuracyLow by remember { mutableStateOf(false) }

    DisposableEffect(Unit) {
        val sm = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        val sensor = sm.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR) ?: sm.getDefaultSensor(Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR)
        if (sensor == null) hasSensor = false
        val matrix = FloatArray(9)
        val orientation = FloatArray(3)
        val listener = object : SensorEventListener {
            override fun onSensorChanged(e: SensorEvent) {
                SensorManager.getRotationMatrixFromVector(matrix, e.values)
                SensorManager.getOrientation(matrix, orientation)
                var deg = Math.toDegrees(orientation[0].toDouble()).toFloat()
                val loc = Graph.repo.location.value
                if (loc != null) {
                    // Magnetic north to true north.
                    deg += GeomagneticField(loc.point.latitude.toFloat(), loc.point.longitude.toFloat(), 0f, System.currentTimeMillis()).declination
                }
                val target = (deg + 360) % 360
                // Smooth the needle, taking the short way round.
                var diff = target - heading
                if (diff > 180) diff -= 360
                if (diff < -180) diff += 360
                heading = (heading + diff * 0.15f + 360) % 360
            }

            override fun onAccuracyChanged(s: Sensor?, accuracy: Int) {
                accuracyLow = accuracy <= SensorManager.SENSOR_STATUS_ACCURACY_LOW
            }
        }
        if (sensor != null) sm.registerListener(listener, sensor, SensorManager.SENSOR_DELAY_UI)
        onDispose { sm.unregisterListener(listener) }
    }

    val qibla = location?.let { QiblaMath.bearing(it.point) }
    val turn = qibla?.let { QiblaMath.turn(heading.toDouble(), it) }
    val aligned = turn != null && abs(turn) < 5

    Column(Modifier.fillMaxSize().background(Palette.cream).systemBarsPadding()) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(4.dp)) {
            IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = t("Back")) }
            Text(t("Qibla Compass"), fontSize = 18.sp, fontWeight = FontWeight.Bold)
        }
        Column(
            Modifier.fillMaxWidth().padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            if (qibla == null) {
                Secondary(t("Finding your location…"))
                return@Column
            }
            Text(
                if (aligned) t("You're facing the Qibla") else if (turn!! > 0) tf("Turn right %d°", turn.roundToInt()) else tf("Turn left %d°", (-turn).roundToInt()),
                fontSize = 22.sp, fontWeight = FontWeight.Bold, color = if (aligned) Palette.green else Palette.textPrimary, textAlign = TextAlign.Center,
            )
            Box(Modifier.size(300.dp), contentAlignment = Alignment.Center) {
                val green = Palette.green
                val gold = Palette.gold
                val border = Palette.border
                Canvas(Modifier.fillMaxSize()) {
                    val r = size.minDimension / 2
                    drawCircle(color = androidx.compose.ui.graphics.Color.White, radius = r)
                    drawCircle(color = if (aligned) green else border, radius = r, style = Stroke(width = 6f))
                    rotate(-heading) {
                        for (i in 0 until 72) {
                            val long = i % 18 == 0
                            val angle = Math.toRadians(i * 5.0)
                            val inner = r - if (long) 26f else 12f
                            drawLine(
                                border, Offset(center.x + (inner * kotlin.math.sin(angle)).toFloat(), center.y - (inner * kotlin.math.cos(angle)).toFloat()),
                                Offset(center.x + ((r - 4) * kotlin.math.sin(angle)).toFloat(), center.y - ((r - 4) * kotlin.math.cos(angle)).toFloat()),
                                strokeWidth = if (long) 4f else 2f,
                            )
                        }
                        rotate(qibla.toFloat()) {
                            val path = Path().apply {
                                moveTo(center.x, center.y - r + 34)
                                lineTo(center.x - 22, center.y + 10)
                                lineTo(center.x, center.y - 4)
                                lineTo(center.x + 22, center.y + 10)
                                close()
                            }
                            drawPath(path, if (aligned) green else gold)
                            drawCircle(green, radius = 16f, center = Offset(center.x, center.y - r + 22))
                        }
                    }
                    drawCircle(green, radius = 10f)
                }
            }
            Text("🕋 " + tf("Qibla: %d° from north", qibla.roundToInt()), fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
            Secondary(tf("%d km to the Kaaba", QiblaMath.distanceKm(location!!.point).roundToInt()))
            if (!hasSensor) Secondary(t("This phone has no compass sensor. Use the angle above with a compass."), align = TextAlign.Center)
            if (accuracyLow) Secondary(t("Move your phone in a figure 8 to calibrate the compass."), align = TextAlign.Center)
            Secondary(t("Hold your phone flat, away from metal and magnets."), size = 13, align = TextAlign.Center)
        }
    }
}
