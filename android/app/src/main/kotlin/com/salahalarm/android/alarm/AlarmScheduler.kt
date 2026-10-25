package com.salahalarm.android.alarm

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import androidx.core.app.NotificationManagerCompat
import com.salahalarm.android.Graph
import com.salahalarm.android.t
import com.salahalarm.android.ui.MainActivity
import com.salahalarm.android.widget.Widgets
import com.salahalarm.core.AlarmPlanner
import com.salahalarm.core.PrayerName
import java.time.Instant
import java.time.ZoneId

/**
 * Queues the next prayer alarms with AlarmManager.setAlarmClock, the same API
 * the stock clock app uses, so they fire on time in Doze. Alarms are re-planned
 * whenever settings, location or the day change, after a reboot, and each time
 * one fires.
 */
object AlarmScheduler {
    const val ACTION_FIRE = "com.salahalarm.android.ALARM_FIRE"
    const val ACTION_REFRESH = "com.salahalarm.android.ALARM_REFRESH"
    const val EXTRA_PRAYER = "prayer"
    const val EXTRA_TIME = "time"
    const val EXTRA_SNOOZES = "snoozes"

    private const val MAX_QUEUED = 6
    private const val REFRESH_CODE = 900_000_001
    private const val SNOOZE_CODE = 900_000_002

    fun canScheduleExact(context: Context): Boolean =
        Build.VERSION.SDK_INT < 31 || context.getSystemService(AlarmManager::class.java).canScheduleExactAlarms()

    fun fireIntent(context: Context, prayer: PrayerName, time: Long, snoozes: Int): Intent =
        Intent(context, AlarmReceiver::class.java)
            .setAction(ACTION_FIRE)
            .putExtra(EXTRA_PRAYER, prayer.id)
            .putExtra(EXTRA_TIME, time)
            .putExtra(EXTRA_SNOOZES, snoozes)

    fun reschedule(context: Context) {
        val repo = Graph.repo
        val store = Graph.store
        val am = context.getSystemService(AlarmManager::class.java) ?: return

        store.string("scheduled_codes")?.split(",")?.mapNotNull { it.toIntOrNull() }?.forEach { code ->
            val existing = PendingIntent.getBroadcast(
                context, code, Intent(context, AlarmReceiver::class.java).setAction(ACTION_FIRE),
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
            )
            if (existing != null) {
                am.cancel(existing)
                existing.cancel()
            }
        }

        val now = Instant.now()
        val alarms = if (repo.isPremium(now)) {
            AlarmPlanner.upcoming(repo.schedules(repo.today(), 2), repo.settings.value, now).take(MAX_QUEUED)
        } else {
            emptyList()
        }
        for (a in alarms) {
            val pi = PendingIntent.getBroadcast(
                context, a.requestCode, fireIntent(context, a.prayer, a.time.toEpochMilli(), 0),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            set(context, am, a.time.toEpochMilli(), pi)
        }
        store.setString("scheduled_codes", alarms.joinToString(",") { it.requestCode.toString() })

        // Just after midnight, so tomorrow's alarms are queued even if the app is never opened.
        val refreshAt = repo.today().plusDays(1).atStartOfDay(ZoneId.systemDefault()).plusMinutes(5).toInstant().toEpochMilli()
        val refresh = PendingIntent.getBroadcast(
            context, REFRESH_CODE, Intent(context, AlarmReceiver::class.java).setAction(ACTION_REFRESH),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, refreshAt, refresh)
    }

    fun snooze(context: Context, prayer: PrayerName, scheduled: Long, snoozes: Int, minutes: Long = 5) {
        val am = context.getSystemService(AlarmManager::class.java) ?: return
        val pi = PendingIntent.getBroadcast(
            context, SNOOZE_CODE, fireIntent(context, prayer, scheduled, snoozes),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        set(context, am, System.currentTimeMillis() + minutes * 60_000, pi)
    }

    private fun set(context: Context, am: AlarmManager, at: Long, pi: PendingIntent) {
        if (canScheduleExact(context)) {
            val show = PendingIntent.getActivity(
                context, 0, Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            am.setAlarmClock(AlarmManager.AlarmClockInfo(at, show), pi)
        } else {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
        }
    }
}

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Graph.init(context)
        when (intent.action) {
            AlarmScheduler.ACTION_FIRE -> {
                val prayer = PrayerName.fromId(intent.getStringExtra(AlarmScheduler.EXTRA_PRAYER)) ?: return
                val time = intent.getLongExtra(AlarmScheduler.EXTRA_TIME, System.currentTimeMillis())
                val snoozes = intent.getIntExtra(AlarmScheduler.EXTRA_SNOOZES, 0)
                val repo = Graph.repo
                val s = repo.settings.value
                // An alarm delivered long after its time (phone was off) would only confuse.
                val stale = snoozes == 0 && System.currentTimeMillis() - time > 30 * 60_000
                val ring = repo.isPremium() && s.alarmsEnabled && s.isEnabled(prayer) && !stale && !repo.todayLog().isConfirmed(prayer)
                if (ring) AlarmService.start(context, prayer, time, snoozes)
                AlarmScheduler.reschedule(context)
                Widgets.updateAll(context)
            }
            AlarmScheduler.ACTION_REFRESH -> {
                AlarmScheduler.reschedule(context)
                Widgets.updateAll(context)
            }
        }
    }
}

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Graph.init(context)
        AlarmScheduler.reschedule(context)
        Widgets.updateAll(context)
    }
}

object Notifications {
    const val CHANNEL_ALARMS = "prayer_alarms"
    const val CHANNEL_GENERAL = "general"
    const val ALARM_ID = 1001

    fun createChannels(context: Context) {
        val nm = context.getSystemService(NotificationManager::class.java) ?: return
        val alarms = NotificationChannel(CHANNEL_ALARMS, t("Prayer alarms"), NotificationManager.IMPORTANCE_HIGH).apply {
            // The alarm service plays the adhan itself, at alarm volume.
            setSound(null, null)
            enableVibration(false)
            setBypassDnd(true)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
        }
        val general = NotificationChannel(CHANNEL_GENERAL, t("Reminders"), NotificationManager.IMPORTANCE_DEFAULT)
        nm.createNotificationChannels(listOf(alarms, general))
    }

    fun enabled(context: Context): Boolean = NotificationManagerCompat.from(context).areNotificationsEnabled()

    fun canFullScreen(context: Context): Boolean =
        Build.VERSION.SDK_INT < 34 || context.getSystemService(NotificationManager::class.java).canUseFullScreenIntent()

    fun ignoringBatteryOptimizations(context: Context): Boolean =
        context.getSystemService(PowerManager::class.java)?.isIgnoringBatteryOptimizations(context.packageName) ?: true
}
