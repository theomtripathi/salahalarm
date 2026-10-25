package com.salahalarm.android.alarm

import android.app.Activity
import android.app.KeyguardManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.addCallback
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.salahalarm.android.Graph
import com.salahalarm.android.t
import com.salahalarm.android.ui.MainActivity
import com.salahalarm.android.ui.Palette
import com.salahalarm.android.ui.PrimaryButton
import com.salahalarm.android.ui.SalahTheme
import com.salahalarm.android.ui.SecondaryButton
import com.salahalarm.android.ui.rememberNow
import com.salahalarm.android.ui.timeString
import com.salahalarm.core.AlarmStrictness

/** The ringing screen, shown over the lock screen. Port of iOS SAActiveAlarmOverlay and SAMatScanView. */
class AlarmActivity : ComponentActivity() {
    companion object {
        fun intent(context: Context): Intent =
            Intent(context, AlarmActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_USER_ACTION)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Graph.init(this)
        if (Build.VERSION.SDK_INT >= 27) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        // Back does not silence the alarm.
        onBackPressedDispatcher.addCallback(this) { }
        setContent { SalahTheme { AlarmScreen(this) } }
    }
}

/** Runs [then] once the phone is unlocked, since the camera can't open over the lock screen. */
private fun unlockThen(activity: Activity, then: () -> Unit) {
    val km = activity.getSystemService(KeyguardManager::class.java)
    if (km == null || !km.isKeyguardLocked) {
        then()
        return
    }
    km.requestDismissKeyguard(activity, object : KeyguardManager.KeyguardDismissCallback() {
        override fun onDismissSucceeded() = then()
    })
}

@Composable
private fun AlarmScreen(activity: ComponentActivity) {
    val alarm by AlarmService.active.collectAsState()
    val now by rememberNow()
    val settings by Graph.repo.settings.collectAsState()
    var photo by remember { mutableStateOf<Bitmap?>(null) }
    var scanning by remember { mutableStateOf(false) }
    var confirmManual by remember { mutableStateOf(false) }
    var cameraMissing by remember { mutableStateOf(false) }
    var seen by remember { mutableStateOf(false) }

    LaunchedEffect(alarm) {
        if (alarm != null) seen = true
        // The alarm ended elsewhere (lapsed, or dismissed from another screen).
        if (alarm == null && seen) activity.finish()
    }
    LaunchedEffect(Unit) {
        kotlinx.coroutines.delay(1500)
        if (AlarmService.active.value == null) activity.finish()
    }

    val camera = rememberLauncherForActivityResult(ActivityResultContracts.TakePicturePreview()) { bmp ->
        if (bmp != null) photo = bmp
    }
    val openCamera = {
        unlockThen(activity) {
            try {
                camera.launch(null)
            } catch (e: ActivityNotFoundException) {
                cameraMissing = true
            }
        }
    }
    val current = alarm
    val prayer = current?.prayer

    Box(
        Modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(listOf(Palette.alarmRed, Palette.alarmRedDark))),
    ) {
        Column(
            Modifier.fillMaxSize().systemBarsPadding().verticalScroll(rememberScrollState()).padding(20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(24.dp),
        ) {
            Spacer(Modifier.height(28.dp))
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(prayer?.let { t(it.displayName) } ?: "", color = Color.White, fontSize = 42.sp, fontWeight = FontWeight.Bold)
                Text(prayer?.arabicName ?: "", color = Color.White.copy(alpha = 0.92f), fontSize = 26.sp)
                Text(timeString(now), color = Color.White.copy(alpha = 0.82f), fontSize = 18.sp, fontWeight = FontWeight.Medium)
            }

            if (!scanning) Pulse()

            Column(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(28.dp)).background(Color.White).padding(24.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                if (!scanning) {
                    Text(t("scan your prayer mat to dismiss"), fontSize = 20.sp, fontWeight = FontWeight.Bold, color = Palette.textPrimary)
                    Text(t("Point your camera at your janamaz and confirm the scan."), fontSize = 14.sp, color = Palette.textSecondary)
                    PrimaryButton(t("scan mat")) {
                        scanning = true
                        openCamera()
                    }
                    if (settings.strictness == AlarmStrictness.RELAXED && (current?.snoozes ?: 0) < settings.strictness.snoozesAllowed) {
                        SecondaryButton(t("Snooze 5 min")) { AlarmService.snooze(activity) }
                    }
                    if (settings.strictness.allowsManualDismiss) {
                        TextButton(onClick = { confirmManual = true }, modifier = Modifier.align(Alignment.CenterHorizontally)) {
                            Text(t("dismiss manually"), color = Palette.textSecondary, fontSize = 14.sp)
                        }
                    }
                } else {
                    Text(t("Mat Scan"), fontSize = 20.sp, fontWeight = FontWeight.Bold)
                    val bmp = photo
                    if (bmp != null) {
                        Image(
                            bmp.asImageBitmap(), contentDescription = null, contentScale = ContentScale.Crop,
                            modifier = Modifier.fillMaxWidth().height(260.dp).clip(RoundedCornerShape(24.dp)),
                        )
                        PrimaryButton(t("confirm mat scan")) {
                            AlarmService.stop(activity, "mat_scan")
                            activity.startActivity(
                                Intent(activity, MainActivity::class.java)
                                    .putExtra(MainActivity.EXTRA_CONFIRM_PRAYER, prayer?.id)
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
                            )
                            activity.finish()
                        }
                        SecondaryButton(t("retake photo")) { openCamera() }
                    } else {
                        Box(
                            Modifier.fillMaxWidth().height(200.dp)
                                .border(2.dp, Palette.green, RoundedCornerShape(24.dp)),
                            contentAlignment = Alignment.Center,
                        ) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.padding(20.dp)) {
                                Text(t("Point your camera at your prayer mat."), fontWeight = FontWeight.SemiBold, fontSize = 17.sp, textAlign = TextAlign.Center)
                                Spacer(Modifier.height(6.dp))
                                Text(t("Capture a photo of your janamaz to dismiss this alarm."), color = Palette.textSecondary, fontSize = 14.sp, textAlign = TextAlign.Center)
                            }
                        }
                        PrimaryButton(t("open camera")) { openCamera() }
                        TextButton(onClick = { scanning = false }, modifier = Modifier.align(Alignment.CenterHorizontally)) {
                            Text(t("Cancel"), color = Palette.textSecondary)
                        }
                    }
                }
            }
        }
    }

    if (confirmManual) {
        AlertDialog(
            onDismissRequest = { confirmManual = false },
            title = { Text(t("Dismiss without praying?")) },
            text = { Text(t("Use manual dismissal only if you need to come back later.")) },
            confirmButton = {
                TextButton(onClick = {
                    confirmManual = false
                    AlarmService.stop(activity, "manual")
                    activity.finish()
                }) { Text(t("Yes, I'll pray later"), color = Palette.alarmRed) }
            },
            dismissButton = { TextButton(onClick = { confirmManual = false }) { Text(t("Cancel")) } },
        )
    }
    if (cameraMissing) {
        AlertDialog(
            onDismissRequest = { cameraMissing = false },
            title = { Text(t("Camera unavailable")) },
            text = { Text(t("No camera app was found on this phone.")) },
            confirmButton = { TextButton(onClick = { cameraMissing = false }) { Text(t("OK")) } },
        )
    }
}

@Composable
private fun Pulse() {
    val transition = rememberInfiniteTransition(label = "pulse")
    val scale by transition.animateFloat(
        initialValue = 0.88f, targetValue = 1.08f,
        animationSpec = infiniteRepeatable(tween(1800, easing = LinearEasing), RepeatMode.Restart), label = "scale",
    )
    Box(Modifier.size(220.dp), contentAlignment = Alignment.Center) {
        for (i in 0..2) {
            Box(
                Modifier.size((120 + i * 48).dp).scale(scale)
                    .border(2.dp, Color.White.copy(alpha = 0.35f - i * 0.08f), CircleShape),
            )
        }
        Icon(Icons.Filled.Notifications, contentDescription = null, tint = Color.White, modifier = Modifier.size(40.dp))
    }
}
