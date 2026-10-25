package com.salahalarm.android.widget

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import com.salahalarm.android.Graph
import com.salahalarm.android.R
import com.salahalarm.android.alarm.AlarmReceiver
import com.salahalarm.android.alarm.AlarmScheduler
import com.salahalarm.android.t
import com.salahalarm.android.tf
import com.salahalarm.android.ui.MainActivity
import com.salahalarm.android.ui.timeString
import com.salahalarm.core.DuaLibrary
import com.salahalarm.core.PrayerCalculator
import java.time.Instant

/** Home-screen widgets, matching the iOS SalahAlarm and Dua of the Moment widgets. */
object Widgets {
    private const val WIDGET_REFRESH_CODE = 900_000_003

    fun updateAll(context: Context) {
        val mgr = AppWidgetManager.getInstance(context) ?: return
        val prayerIds = mgr.getAppWidgetIds(ComponentName(context, PrayerWidget::class.java))
        val duaIds = mgr.getAppWidgetIds(ComponentName(context, DuaWidget::class.java))
        if (prayerIds.isNotEmpty()) mgr.updateAppWidget(prayerIds, prayerViews(context))
        if (duaIds.isNotEmpty()) mgr.updateAppWidget(duaIds, duaViews(context))
        if (prayerIds.isNotEmpty()) scheduleNextRefresh(context)
    }

    private fun openApp(context: Context): PendingIntent = PendingIntent.getActivity(
        context, 10, Intent(context, MainActivity::class.java),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    fun prayerViews(context: Context): RemoteViews {
        val repo = Graph.repo
        val now = Instant.now()
        val next = PrayerCalculator.nextPrayer(repo.schedules(repo.today(), 2), now)
        val v = RemoteViews(context.packageName, R.layout.widget_prayer)
        v.setTextViewText(R.id.widget_city, repo.location.value?.city ?: "SalahAlarm")
        v.setTextViewText(R.id.widget_streak, "🔥 ${repo.streak.value.displayed(repo.today())}")
        v.setTextViewText(R.id.widget_label, t("Next Prayer"))
        v.setTextViewText(R.id.widget_prayer, next?.let { t(it.first.displayName) } ?: "--")
        v.setTextViewText(R.id.widget_time, timeString(next?.second))
        v.setTextViewText(R.id.widget_today, tf("%d / 5 prayers today", repo.todayLog().prayedCount))
        v.setOnClickPendingIntent(R.id.widget_root, openApp(context))
        return v
    }

    fun duaViews(context: Context): RemoteViews {
        val now = Instant.now()
        val dua = DuaLibrary.dua(now)
        val theme = DuaLibrary.theme(now)
        val v = RemoteViews(context.packageName, R.layout.widget_dua)
        v.setTextViewText(R.id.dua_label, t("DUA OF THE MOMENT"))
        v.setTextViewText(R.id.dua_english, "“${dua.english}”")
        v.setTextViewText(R.id.dua_arabic, dua.arabic)
        v.setTextColor(R.id.dua_arabic, theme.accent.toInt())
        v.setTextViewText(R.id.dua_reference, dua.reference)
        v.setOnClickPendingIntent(R.id.dua_root, openApp(context))
        return v
    }

    /** Refreshes the "next prayer" widget right after each prayer time, without waking the phone. */
    private fun scheduleNextRefresh(context: Context) {
        val repo = Graph.repo
        val next = PrayerCalculator.nextPrayer(repo.schedules(repo.today(), 2), Instant.now()) ?: return
        val am = context.getSystemService(AlarmManager::class.java) ?: return
        val pi = PendingIntent.getBroadcast(
            context, WIDGET_REFRESH_CODE,
            Intent(context, AlarmReceiver::class.java).setAction(AlarmScheduler.ACTION_REFRESH),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        am.set(AlarmManager.RTC, next.second.toEpochMilli() + 30_000, pi)
    }
}

class PrayerWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        Graph.init(context)
        manager.updateAppWidget(ids, Widgets.prayerViews(context))
    }
}

class DuaWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        Graph.init(context)
        manager.updateAppWidget(ids, Widgets.duaViews(context))
    }
}
