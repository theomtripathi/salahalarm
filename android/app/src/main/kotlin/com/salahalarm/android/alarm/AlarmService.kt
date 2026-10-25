package com.salahalarm.android.alarm

import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import com.salahalarm.android.Graph
import com.salahalarm.android.R
import com.salahalarm.android.data.Analytics
import com.salahalarm.android.t
import com.salahalarm.android.tf
import com.salahalarm.core.AlarmSettings
import com.salahalarm.core.AlarmSound
import com.salahalarm.core.AlarmStrictness
import com.salahalarm.core.PrayerName
import kotlinx.coroutines.flow.MutableStateFlow
import java.io.File
import java.time.Instant

data class ActiveAlarm(
    val prayer: PrayerName,
    val scheduled: Long,
    val snoozes: Int,
    val startedAt: Long,
    val test: Boolean,
)

/**
 * Rings an alarm: loops the chosen adhan on the alarm stream, vibrates, and
 * shows AlarmActivity over the lock screen through a full-screen notification.
 * It keeps ringing until the mat is scanned (or, outside strict mode, until it
 * is dismissed), the same rules as the iOS alarm.
 */
class AlarmService : Service() {
    companion object {
        private const val ACTION_START = "start"
        private const val ACTION_STOP = "stop"
        private const val ACTION_SNOOZE = "snooze"
        private const val EXTRA_METHOD = "method"
        private const val EXTRA_TEST = "test"
        private const val MAX_RING_MS = 60 * 60_000L

        val active = MutableStateFlow<ActiveAlarm?>(null)

        const val CUSTOM_SOUND_FILE = "custom_alarm_sound"

        fun start(context: Context, prayer: PrayerName, scheduled: Long, snoozes: Int = 0, test: Boolean = false) {
            val intent = Intent(context, AlarmService::class.java)
                .setAction(ACTION_START)
                .putExtra(AlarmScheduler.EXTRA_PRAYER, prayer.id)
                .putExtra(AlarmScheduler.EXTRA_TIME, scheduled)
                .putExtra(AlarmScheduler.EXTRA_SNOOZES, snoozes)
                .putExtra(EXTRA_TEST, test)
            ContextCompat.startForegroundService(context, intent)
        }

        /** method: mat_scan, manual, missed. */
        fun stop(context: Context, method: String) {
            context.startService(Intent(context, AlarmService::class.java).setAction(ACTION_STOP).putExtra(EXTRA_METHOD, method))
        }

        fun snooze(context: Context) {
            context.startService(Intent(context, AlarmService::class.java).setAction(ACTION_SNOOZE))
        }

        fun soundRes(sound: AlarmSound): Int = when (sound) {
            AlarmSound.MAKKAH -> R.raw.alarm_makkah_loud
            AlarmSound.MADINAH -> R.raw.alarm_madinah_loud
            AlarmSound.FAJR -> R.raw.alarm_fajr_loud
            AlarmSound.TAKBIR -> R.raw.alarm_takbir_loud
            AlarmSound.WAKE_UP -> R.raw.wake_up
            AlarmSound.CUSTOM -> R.raw.alarm_makkah_loud
        }
    }

    private var player: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var restoreVolume: Int? = null
    private val handler = Handler(Looper.getMainLooper())

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Graph.init(this)
        when (intent?.action) {
            ACTION_START -> {
                val prayer = PrayerName.fromId(intent.getStringExtra(AlarmScheduler.EXTRA_PRAYER)) ?: PrayerName.FAJR
                val alarm = ActiveAlarm(
                    prayer = prayer,
                    scheduled = intent.getLongExtra(AlarmScheduler.EXTRA_TIME, System.currentTimeMillis()),
                    snoozes = intent.getIntExtra(AlarmScheduler.EXTRA_SNOOZES, 0),
                    startedAt = System.currentTimeMillis(),
                    test = intent.getBooleanExtra(EXTRA_TEST, false),
                )
                begin(alarm)
            }
            ACTION_STOP -> finish(intent.getStringExtra(EXTRA_METHOD) ?: "manual")
            ACTION_SNOOZE -> {
                val a = active.value
                if (a != null) {
                    AlarmScheduler.snooze(this, a.prayer, a.scheduled, a.snoozes + 1)
                    finish("snoozed")
                } else {
                    stopSelf()
                }
            }
            else -> if (active.value == null) stopSelf()
        }
        return START_NOT_STICKY
    }

    private fun begin(alarm: ActiveAlarm) {
        val settings = Graph.repo.settings.value
        ServiceCompat.startForeground(
            this, Notifications.ALARM_ID, notification(alarm, settings),
            if (Build.VERSION.SDK_INT >= 29) ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK else 0,
        )
        stopSound()
        handler.removeCallbacksAndMessages(null)
        active.value = alarm

        wakeLock = getSystemService(PowerManager::class.java)
            ?.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "SalahAlarm:alarm")
            ?.apply { acquire(MAX_RING_MS + 60_000) }
        playSound(settings)
        if (settings.vibrationEnabled) vibrate()

        // Moderate mode lets the alarm lapse after 10 minutes; nothing rings forever.
        val limit = settings.strictness.autoMissAfter?.toMillis() ?: MAX_RING_MS
        handler.postDelayed({ finish("missed") }, limit)

        if (!alarm.test) Graph.repo.logAlarm(alarm.prayer, Instant.ofEpochMilli(alarm.scheduled), "ringing")
        Analytics.capture(
            "alarm_fired",
            mapOf("prayer" to alarm.prayer.id, "strictness" to settings.strictness.raw, "sound" to settings.sound.raw, "test" to alarm.test, "snoozes" to alarm.snoozes),
        )
        // When the screen is already on, Android shows the notification instead of the full-screen activity.
        runCatching { startActivity(AlarmActivity.intent(this)) }
    }

    private fun notification(alarm: ActiveAlarm, settings: AlarmSettings): android.app.Notification {
        val open = PendingIntent.getActivity(
            this, 1, AlarmActivity.intent(this),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val name = t(alarm.prayer.displayName)
        val builder = NotificationCompat.Builder(this, Notifications.CHANNEL_ALARMS)
            .setSmallIcon(R.drawable.ic_stat_alarm)
            .setColor(0xFF1A9E3F.toInt())
            .setContentTitle("🕌 " + tf("%@ Prayer", name))
            .setContentText(tf("It's time for %@. Tap to confirm.", name))
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setFullScreenIntent(open, true)
            .setContentIntent(open)
            .addAction(0, t("scan mat"), open)
        if (settings.strictness == AlarmStrictness.RELAXED && alarm.snoozes < settings.strictness.snoozesAllowed) {
            val snooze = PendingIntent.getService(
                this, 2, Intent(this, AlarmService::class.java).setAction(ACTION_SNOOZE),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            builder.addAction(0, t("Snooze 5 min"), snooze)
        }
        return builder.build()
    }

    private fun playSound(settings: AlarmSettings) {
        val audio = getSystemService(AudioManager::class.java)
        if (audio != null) {
            // A muted alarm stream would make Fajr silent; raise it for this alarm only.
            val max = audio.getStreamMaxVolume(AudioManager.STREAM_ALARM)
            val current = audio.getStreamVolume(AudioManager.STREAM_ALARM)
            val wanted = (max * 0.8f).toInt().coerceAtLeast(1)
            if (current < wanted) {
                restoreVolume = current
                runCatching { audio.setStreamVolume(AudioManager.STREAM_ALARM, wanted, 0) }
            }
        }
        val p = MediaPlayer()
        try {
            p.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            val custom = File(filesDir, CUSTOM_SOUND_FILE)
            if (settings.sound == AlarmSound.CUSTOM && custom.exists()) {
                p.setDataSource(custom.path)
            } else {
                resources.openRawResourceFd(soundRes(settings.sound)).use { afd ->
                    p.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                }
            }
            p.isLooping = true
            p.setVolume(settings.volume, settings.volume)
            p.prepare()
            p.start()
            player = p
        } catch (e: Exception) {
            p.release()
            // Fall back to the built-in adhan if a custom file can't be played.
            if (settings.sound != AlarmSound.MAKKAH) playSound(settings.copy(sound = AlarmSound.MAKKAH))
        }
    }

    private fun vibrate() {
        val v = if (Build.VERSION.SDK_INT >= 31) {
            getSystemService(VibratorManager::class.java)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Vibrator::class.java)
        }
        vibrator = v
        val effect = VibrationEffect.createWaveform(longArrayOf(0, 900, 700), 0)
        @Suppress("DEPRECATION")
        v?.vibrate(effect, AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).build())
    }

    private fun stopSound() {
        player?.runCatching { stop() }
        player?.release()
        player = null
        vibrator?.cancel()
        vibrator = null
        restoreVolume?.let { v ->
            runCatching { getSystemService(AudioManager::class.java)?.setStreamVolume(AudioManager.STREAM_ALARM, v, 0) }
        }
        restoreVolume = null
    }

    private fun finish(method: String) {
        val alarm = active.value
        handler.removeCallbacksAndMessages(null)
        stopSound()
        wakeLock?.takeIf { it.isHeld }?.release()
        wakeLock = null
        if (alarm != null) {
            if (!alarm.test) Graph.repo.logAlarm(alarm.prayer, Instant.ofEpochMilli(alarm.scheduled), method)
            Analytics.capture(
                "alarm_dismissed",
                mapOf("prayer" to alarm.prayer.id, "method" to method, "seconds_ringing" to (System.currentTimeMillis() - alarm.startedAt) / 1000, "test" to alarm.test),
            )
        }
        active.value = null
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        stopSound()
        wakeLock?.takeIf { it.isHeld }?.release()
        active.value = null
        super.onDestroy()
    }
}
