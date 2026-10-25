package com.salahalarm.android.ui

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.RadioButton
import androidx.compose.material3.RadioButtonDefaults
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.salahalarm.android.Graph
import com.salahalarm.android.alarm.AlarmScheduler
import com.salahalarm.android.alarm.AlarmService
import com.salahalarm.android.alarm.Notifications
import com.salahalarm.android.data.Analytics
import com.salahalarm.android.data.LocationHelper
import com.salahalarm.android.t
import com.salahalarm.android.tf
import com.salahalarm.core.AlarmSound
import com.salahalarm.core.AlarmStrictness
import com.salahalarm.core.PrayerName
import kotlinx.coroutines.launch
import java.io.File
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/**
 * "Make sure alarms ring": the Android settings that decide whether Fajr
 * actually rings on a sideloaded app. Shown once after sign-in and from the
 * home screen warning whenever something is off.
 */
@Composable
fun SetupScreen(onDone: () -> Unit, standalone: Boolean = false) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val now by rememberNow(1500)
    val location by Graph.repo.location.collectAsState()

    val notifications = remember(now) { Notifications.enabled(context) }
    val exact = remember(now) { AlarmScheduler.canScheduleExact(context) }
    val fullScreen = remember(now) { Notifications.canFullScreen(context) }
    val battery = remember(now) { Notifications.ignoringBatteryOptimizations(context) }
    val precise = remember(now) { LocationHelper.hasPermission(context) }

    val notifPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {
        AlarmScheduler.reschedule(context)
    }
    val locationPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) {
        scope.launch { Graph.repo.refreshLocation() }
    }

    fun open(intent: Intent) {
        runCatching { context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
            .onFailure {
                runCatching {
                    context.startActivity(
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}"))
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    )
                }
            }
    }

    Column(Modifier.fillMaxSize().background(Palette.cream).systemBarsPadding()) {
        if (standalone) {
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(4.dp)) {
                IconButton(onClick = onDone) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = t("Back")) }
                Text(t("Make sure alarms ring"), fontSize = 18.sp, fontWeight = FontWeight.Bold)
            }
        }
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            if (!standalone) {
                Text(t("Finish the 1-minute setup"), fontSize = 26.sp, fontWeight = FontWeight.Bold)
                Secondary(t("Allow notifications and alarms, and turn off battery optimization so Fajr always rings."))
            }
            SetupRow(t("Notifications"), t("Shows the alarm screen when it's time to pray."), notifications) {
                if (Build.VERSION.SDK_INT >= 33) notifPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
                else open(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName))
            }
            if (Build.VERSION.SDK_INT >= 31) {
                SetupRow(t("Alarms & reminders"), t("Lets SalahAlarm ring at the exact prayer time."), exact) {
                    open(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:${context.packageName}")))
                }
            }
            if (Build.VERSION.SDK_INT >= 34) {
                SetupRow(t("Full-screen alarms"), t("Shows the alarm over the lock screen, like a clock alarm."), fullScreen) {
                    open(Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, Uri.parse("package:${context.packageName}")))
                }
            }
            SetupRow(t("Battery: unrestricted"), t("Stops Android from putting SalahAlarm to sleep before Fajr."), battery) {
                @Suppress("BatteryLife")
                open(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:${context.packageName}")))
            }
            SetupRow(
                t("Precise prayer times"),
                location?.city?.let { tf("Using %@. Allow location for times calculated for exactly where you are.", it) }
                    ?: t("Allow location for times calculated for exactly where you are."),
                precise,
            ) {
                locationPermission.launch(arrayOf(Manifest.permission.ACCESS_COARSE_LOCATION, Manifest.permission.ACCESS_FINE_LOCATION))
            }

            brandTip()?.let { (brand, tip) ->
                Column(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(Palette.warningBg).padding(14.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Text(tf("On %@ phones", brand), fontWeight = FontWeight.Bold, fontSize = 14.sp)
                    Secondary(t(tip), size = 13)
                    TextButton(onClick = {
                        open(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}")))
                    }) { Text(t("Open App info"), color = Palette.green) }
                }
            }

            SecondaryButton(t("Test alarm overlay")) {
                Analytics.capture("alarm_test_tapped")
                AlarmService.start(context, PrayerName.FAJR, System.currentTimeMillis(), test = true)
            }
        }
        Box(Modifier.padding(20.dp)) {
            PrimaryButton(t(if (standalone) "Done" else "Continue")) {
                Analytics.capture(
                    "android_setup_finished",
                    mapOf("notifications" to notifications, "exact" to exact, "full_screen" to fullScreen, "battery" to battery, "location" to precise),
                )
                AlarmScheduler.reschedule(context)
                onDone()
            }
        }
    }
}

@Composable
private fun SetupRow(title: String, detail: String, done: Boolean, onFix: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Color.White)
            .clickable(enabled = !done, onClick = onFix).padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier.size(28.dp).clip(CircleShape).background(if (done) Palette.green else Palette.border),
            contentAlignment = Alignment.Center,
        ) {
            if (done) Icon(Icons.Filled.Check, null, tint = Color.White, modifier = Modifier.size(18.dp))
        }
        Spacer(Modifier.width(14.dp))
        Column(Modifier.weight(1f)) {
            Text(title, fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
            Secondary(detail, size = 13)
        }
        if (!done) {
            Text(t("Allow"), color = Palette.green, fontWeight = FontWeight.Bold, fontSize = 14.sp)
        }
    }
}

/** The same per-brand advice as the website's install guide. */
private fun brandTip(): Pair<String, String>? {
    val m = Build.MANUFACTURER.lowercase()
    return when {
        m in setOf("xiaomi", "redmi", "poco") -> "Xiaomi, Redmi, POCO" to
            "Settings › Apps › SalahAlarm: turn on Autostart and set Battery saver to No restrictions."
        m == "samsung" -> "Samsung" to "Settings › Battery › Background usage limits: add SalahAlarm to Never sleeping apps."
        m in setOf("oppo", "realme", "vivo", "oneplus", "iqoo") -> "Oppo, Realme, Vivo, OnePlus" to
            "Settings › Battery › SalahAlarm: allow background activity and auto-launch."
        m in setOf("huawei", "honor") -> "Huawei, Honor" to
            "Settings › Battery › App launch: set SalahAlarm to Manage manually and turn on all switches."
        else -> null
    }
}

/** Port of iOS SAAlarmSettingsSheet: which prayers ring, strictness, sound, test, recent activity. */
@Composable
fun AlarmSettingsScreen(onBack: () -> Unit) {
    val context = LocalContext.current
    val repo = Graph.repo
    val settings by repo.settings.collectAsState()
    val premium = repo.isPremium()
    var previewing by remember { mutableStateOf<android.media.MediaPlayer?>(null) }

    fun stopPreview() {
        previewing?.runCatching { stop() }
        previewing?.release()
        previewing = null
    }

    fun preview(sound: AlarmSound) {
        stopPreview()
        val custom = File(context.filesDir, AlarmService.CUSTOM_SOUND_FILE)
        previewing = runCatching {
            if (sound == AlarmSound.CUSTOM && custom.exists()) {
                android.media.MediaPlayer().apply {
                    setDataSource(custom.path)
                    prepare()
                    start()
                }
            } else {
                android.media.MediaPlayer.create(context, AlarmService.soundRes(sound))?.apply { start() }
            }
        }.getOrNull()
    }
    DisposableEffect(Unit) { onDispose { stopPreview() } }

    val pickAudio = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) {
            runCatching {
                context.contentResolver.openInputStream(uri)?.use { input ->
                    File(context.filesDir, AlarmService.CUSTOM_SOUND_FILE).outputStream().use { input.copyTo(it) }
                }
                repo.updateSettings { it.copy(sound = AlarmSound.CUSTOM) }
                preview(AlarmSound.CUSTOM)
            }
        }
    }

    Column(Modifier.fillMaxSize().background(Palette.cream).systemBarsPadding()) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(4.dp)) {
            IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = t("Back")) }
            Text(t("Alarm Settings"), fontSize = 18.sp, fontWeight = FontWeight.Bold)
        }
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 20.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            Section(t("Prayer alarms")) {
                ToggleRow(t("Enable all alarms"), settings.alarmsEnabled && premium, enabled = premium) { on ->
                    repo.updateSettings { it.copy(alarmsEnabled = on) }
                }
                PrayerName.entries.forEach { p ->
                    ToggleRow(t(p.displayName), settings.isEnabled(p), enabled = premium) { on -> repo.updateSettings { it.withPrayer(p, on) } }
                }
            }
            Section(t("Strictness")) {
                PillRow(AlarmStrictness.entries.map { it.raw to t(it.displayLabel) }, settings.strictness.raw) { v ->
                    repo.updateSettings { it.copy(strictness = AlarmStrictness.fromRaw(v)) }
                }
                Secondary(t(settings.strictness.detailText), size = 13)
            }
            Section(t("Sound")) {
                AlarmSound.entries.forEach { sound ->
                    Row(
                        Modifier.fillMaxWidth().clickable {
                            if (sound == AlarmSound.CUSTOM) {
                                pickAudio.launch("audio/*")
                            } else {
                                repo.updateSettings { it.copy(sound = sound) }
                                preview(sound)
                            }
                        },
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        RadioButton(
                            selected = settings.sound == sound, onClick = null,
                            colors = RadioButtonDefaults.colors(selectedColor = Palette.green),
                        )
                        Spacer(Modifier.width(8.dp))
                        Text(t(sound.displayName), modifier = Modifier.weight(1f))
                        if (sound != AlarmSound.CUSTOM) {
                            IconButton(onClick = { preview(sound) }) { Icon(Icons.Filled.MusicNote, null, tint = Palette.textSecondary) }
                        }
                    }
                }
                Text(t("Volume"), fontSize = 14.sp, fontWeight = FontWeight.Medium)
                Slider(
                    value = settings.volume, onValueChange = { v -> repo.updateSettings { it.copy(volume = v) } }, valueRange = 0.2f..1f,
                    colors = SliderDefaults.colors(thumbColor = Palette.green, activeTrackColor = Palette.green),
                )
                ToggleRow(t("Vibrate"), settings.vibrationEnabled) { on -> repo.updateSettings { it.copy(vibrationEnabled = on) } }
                TextButton(onClick = {
                    stopPreview()
                    AlarmService.start(context, PrayerName.FAJR, System.currentTimeMillis(), test = true)
                }) { Text(t("Test alarm overlay"), color = Palette.alarmRed, fontWeight = FontWeight.SemiBold) }
            }
            val logs = remember { repo.alarmLogs().filter { it.method != "ringing" }.take(5) }
            if (logs.isNotEmpty()) {
                Section(t("Recent alarm activity")) {
                    logs.forEach { l ->
                        Column {
                            Text(
                                "${t(l.prayer.displayName)} • ${DateTimeFormatter.ofPattern("h:mm a", com.salahalarm.android.I18n.locale).format(Instant.ofEpochMilli(l.scheduled).atZone(ZoneId.systemDefault()))}",
                                fontWeight = FontWeight.SemiBold, fontSize = 15.sp,
                            )
                            Secondary(t(methodLabel(l.method)), size = 13)
                        }
                    }
                }
            }
            Spacer(Modifier.height(20.dp))
        }
    }
}

private fun methodLabel(m: String) = when (m) {
    "mat_scan" -> "Mat scan"
    "manual" -> "Manual"
    "missed" -> "Missed"
    "snoozed" -> "Snoozed"
    else -> "Ringing"
}
