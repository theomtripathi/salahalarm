package com.salahalarm.android.ui

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Explore
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.LockOpen
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.SystemUpdate
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.salahalarm.android.Graph
import com.salahalarm.android.R
import com.salahalarm.android.alarm.AlarmScheduler
import com.salahalarm.android.alarm.Notifications
import com.salahalarm.android.data.Api
import com.salahalarm.android.lock.SalahLock
import com.salahalarm.android.t
import com.salahalarm.android.tf
import com.salahalarm.core.AlarmPlanner
import com.salahalarm.core.AlarmStrictness
import com.salahalarm.core.DuaLibrary
import com.salahalarm.core.PrayerCalculator
import com.salahalarm.core.PrayerLogic
import com.salahalarm.core.PrayerName
import kotlinx.coroutines.launch

private val emoji = mapOf(
    PrayerName.FAJR to "🌅", PrayerName.DHUHR to "☀️", PrayerName.ASR to "🌤",
    PrayerName.MAGHRIB to "🌇", PrayerName.ISHA to "🌙",
)

fun openUrl(context: android.content.Context, url: String) {
    runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
}

/** Port of iOS HomeView. */
@Composable
fun HomeScreen() {
    val context = LocalContext.current
    val repo = Graph.repo
    val scope = rememberCoroutineScope()
    val now by rememberNow()
    val user by repo.user.collectAsState()
    val logs by repo.logs.collectAsState()
    val streak by repo.streak.collectAsState()
    val settings by repo.settings.collectAsState()
    val location by repo.location.collectAsState()
    val prefs by repo.prayerPrefs.collectAsState()
    val entitlement by repo.entitlement.collectAsState()
    val lock by repo.lock.collectAsState()
    val update by repo.update.collectAsState()
    var confirming by remember { mutableStateOf<PrayerName?>(null) }
    var hideWidgetPromo by remember { mutableStateOf(Graph.store.flag("hide_widget_promo")) }

    val today = repo.today()
    val schedules = remember(today, location, prefs) { repo.schedules(today, 2) }
    val schedule = schedules.firstOrNull()
    val todayLog = logs[com.salahalarm.core.DateKeys.of(today)] ?: com.salahalarm.core.DailyPrayerLog()
    val premium = entitlement.isActive(now)
    val name = displayName(user?.displayName, user?.email)
    val shownStreak = streak.displayed(today)
    val needsAttention = remember(now.epochSecond / 30) {
        premium && settings.alarmsEnabled && (
            !Notifications.enabled(context) || !AlarmScheduler.canScheduleExact(context) ||
                !Notifications.canFullScreen(context) || !Notifications.ignoringBatteryOptimizations(context)
            )
    }

    Column(Modifier.verticalScroll(rememberScrollState())) {
        ScreenColumn {
            // Header
            Row(verticalAlignment = Alignment.CenterVertically) {
                Image(painterResource(R.drawable.logo), contentDescription = null, modifier = Modifier.size(28.dp).clip(RoundedCornerShape(7.dp)))
                Spacer(Modifier.width(10.dp))
                Text("SalahAlarm", fontSize = 22.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.weight(1f))
                StreakBadge(shownStreak, todayLog.prayedCount > 0)
                Spacer(Modifier.width(10.dp))
                Avatar(initialsOf(name)) { Nav.tab = 4 }
            }

            update?.let { u ->
                Banner(
                    icon = { Icon(Icons.Filled.SystemUpdate, null, tint = Palette.green) },
                    title = t("Update available"),
                    body = u.versionName?.let { tf("Version %@ is ready to install.", it) } ?: t("A new version is ready to install."),
                    action = t("Update"),
                    background = Palette.green.copy(alpha = 0.08f),
                    border = Palette.green.copy(alpha = 0.3f),
                ) { scope.launch { openUrl(context, repo.apkLink() ?: Api.installGuideUrl) } }
            }

            val trialLeft = entitlement.trialDaysLeft(now)
            if (trialLeft in 1..2) {
                Banner(
                    icon = { Icon(Icons.Filled.Warning, null, tint = Palette.gold) },
                    title = if (trialLeft == 1L) t("Your free trial ends tomorrow") else tf("Your free trial ends in %d days", trialLeft.toInt()),
                    body = t("Pick a plan to keep your alarms ringing for every prayer."),
                    action = t("Choose a plan ->"),
                    background = Palette.warningBg,
                    border = Palette.gold,
                ) { openUrl(context, Api.paywallUrl("trial_ending")) }
            }

            if (needsAttention) {
                Banner(
                    icon = { Icon(Icons.Filled.Warning, null, tint = Palette.gold) },
                    title = t("alarm sound requires action"),
                    body = t("A few phone settings can stop alarms from ringing. Fix them once so Fajr always rings."),
                    action = t("fix ->"),
                    background = Palette.warningBg,
                    border = Palette.gold,
                ) { Nav.push(Route.Setup) }
            }

            // Next prayer
            SLCard {
                Text(tf("Assalamu Alaikum, %@ 🌙", name), fontSize = 18.sp, fontWeight = FontWeight.SemiBold)
                Secondary(location?.city ?: t("Your city"), size = 13)
                Spacer(Modifier.size(14.dp))
                val next = schedule?.prayers?.firstOrNull { it.second > now }
                if (location == null) {
                    Secondary(t("Finding your location…"))
                } else if (next != null) {
                    Text(t(next.first.displayName), fontSize = 24.sp, fontWeight = FontWeight.Bold, color = Palette.green)
                    Text(AlarmPlanner.clock(next.second, now), fontSize = 32.sp, fontWeight = FontWeight.Bold, color = Palette.gold, fontFamily = FontFamily.Monospace)
                    Secondary(tf("%@ at %@", t(next.first.displayName), timeString(next.second)))
                } else {
                    Text(t("Today's prayers are complete"), fontSize = 22.sp, fontWeight = FontWeight.Bold, color = Palette.green)
                }
                if (schedule != null) {
                    Spacer(Modifier.size(14.dp))
                    Row(Modifier.fillMaxWidth()) {
                        PrayerName.entries.forEach { p ->
                            val status = PrayerLogic.status(p, todayLog, schedule, now)
                            Column(
                                Modifier.weight(1f).clickable { confirming = p },
                                horizontalAlignment = Alignment.CenterHorizontally,
                                verticalArrangement = Arrangement.spacedBy(5.dp),
                            ) {
                                Text(t(shortLabel(p)), fontSize = 11.sp, fontWeight = FontWeight.SemiBold, maxLines = 1)
                                Text(timeString(schedule.time(p)), fontSize = 11.sp, color = Palette.textSecondary, maxLines = 1)
                                Box(Modifier.size(8.dp).clip(CircleShape).background(statusColor(status)))
                            }
                        }
                    }
                }
            }

            // Next alarm
            SLCard(Modifier.clickable { if (premium) Nav.push(Route.AlarmSettings) else openUrl(context, Api.paywallUrl("home_alarm_card")) }) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Filled.Notifications, null, tint = Palette.textPrimary, modifier = Modifier.size(20.dp))
                    Spacer(Modifier.width(8.dp))
                    Text(t("Next Alarm"), fontSize = 18.sp, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.weight(1f))
                    Switch(
                        checked = settings.alarmsEnabled && premium,
                        enabled = premium,
                        onCheckedChange = { on -> repo.updateSettings { it.copy(alarmsEnabled = on) } },
                        colors = SwitchDefaults.colors(checkedTrackColor = Palette.green),
                    )
                }
                Spacer(Modifier.size(12.dp))
                val nextAlarm = AlarmPlanner.next(schedules, settings, now)
                when {
                    !premium -> {
                        Text(t("Alarm access is locked"), fontSize = 22.sp, fontWeight = FontWeight.Bold, color = Palette.alarmRed)
                        Secondary(t("Your subscription is inactive. Renew to keep prayer alarms running."))
                        Spacer(Modifier.size(10.dp))
                        PrimaryButton(t("Unlock alarms")) { openUrl(context, Api.paywallUrl("home_alarm_card")) }
                    }
                    nextAlarm != null -> {
                        Text(t(nextAlarm.prayer.displayName), fontSize = 24.sp, fontWeight = FontWeight.Bold, color = Palette.green)
                        Text(timeString(nextAlarm.time), fontSize = 28.sp, fontWeight = FontWeight.Bold, color = Palette.gold)
                        Secondary(tf("%@ · %@", t(nextAlarm.prayer.displayName), relative(nextAlarm.time, now)))
                        Spacer(Modifier.size(12.dp))
                        val modeColor = when (settings.strictness) {
                            AlarmStrictness.MODERATE -> Palette.gold
                            AlarmStrictness.RELAXED -> Palette.textSecondary
                            AlarmStrictness.STRICT -> Palette.green
                        }
                        Text(
                            t(settings.strictness.homeDescription),
                            modifier = Modifier.clip(RoundedCornerShape(50)).background(modeColor.copy(alpha = 0.1f)).padding(horizontal = 12.dp, vertical = 10.dp),
                            color = modeColor, fontSize = 14.sp, fontWeight = FontWeight.SemiBold,
                        )
                    }
                    else -> {
                        Text(t("No more alarms scheduled today."), fontSize = 18.sp, fontWeight = FontWeight.SemiBold)
                        Secondary(t("Tomorrow's prayer alarms will refresh automatically."))
                    }
                }
            }

            // SalahLock strip
            if (lock.enabled && lock.packages.isNotEmpty() && SalahLock.serviceEnabled(context)) {
                val blocking = remember(now.epochSecond / 15, logs) { SalahLock.blockingPrayer(now) }
                Row(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Color.White).clickable { Nav.tab = 2 }.padding(14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(
                        if (blocking != null) Icons.Filled.Lock else Icons.Filled.LockOpen, null,
                        tint = if (blocking != null) Palette.alarmRed else Palette.green,
                    )
                    Spacer(Modifier.width(12.dp))
                    Text(
                        blocking?.let { tf("apps locked — pray %@ to unlock", t(it.displayName)) } ?: t("SalahLock armed · apps unlocked"),
                        fontSize = 14.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f),
                    )
                    Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = Palette.textSecondary)
                }
            }

            DuaCard(now)

            // Streak
            SLCard {
                Row {
                    Column {
                        Text("🔥", fontSize = 36.sp)
                        Text("$shownStreak", fontSize = 36.sp, fontWeight = FontWeight.Bold, color = Palette.gold)
                        Secondary(t("day streak"))
                    }
                    Spacer(Modifier.weight(1f))
                    Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            (6 downTo 0).forEach { back ->
                                val day = today.minusDays(back.toLong())
                                val log = logs[com.salahalarm.core.DateKeys.of(day)]
                                val full = log?.allFivePrayed == true
                                val isToday = back == 0
                                Box(
                                    Modifier.size(20.dp).clip(CircleShape)
                                        .background(if (full) Palette.green else if (isToday) Color.Transparent else Palette.border)
                                        .border(if (isToday) 2.dp else 1.dp, if (isToday) Palette.gold else Palette.border, CircleShape),
                                    contentAlignment = Alignment.Center,
                                ) {
                                    if (full) Icon(Icons.Filled.Check, null, tint = Color.White, modifier = Modifier.size(11.dp))
                                }
                            }
                        }
                        Secondary(
                            if (todayLog.allFivePrayed) t("Streak maintained! ✓") else tf("%d prayers today to keep your streak", 5 - todayLog.prayedCount),
                            size = 13, align = TextAlign.End,
                        )
                    }
                }
            }

            // Today's prayers
            SLCard {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    SectionTitle(t("Today's Prayers"))
                    Spacer(Modifier.weight(1f))
                    Text(tf("%d / 5 prayed", todayLog.prayedCount), color = Palette.gold, fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
                }
                Spacer(Modifier.size(8.dp))
                PrayerName.entries.forEach { p ->
                    Row(Modifier.fillMaxWidth().padding(vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text(emoji.getValue(p), fontSize = 20.sp)
                        Spacer(Modifier.width(12.dp))
                        Column(Modifier.weight(1f)) {
                            Text(t(p.displayName), fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
                            Secondary(timeString(schedule?.time(p)), size = 13)
                        }
                        when (PrayerLogic.status(p, todayLog, schedule, now)) {
                            PrayerLogic.Status.CONFIRMED -> Icon(Icons.Filled.CheckCircle, null, tint = Palette.green)
                            PrayerLogic.Status.MISSED -> TextButton(onClick = { confirming = p }) {
                                Text(t("Missed"), color = Color.Red, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                            }
                            PrayerLogic.Status.UPCOMING -> Text(
                                t("Confirm 🤲"),
                                modifier = Modifier.clip(RoundedCornerShape(50)).background(Palette.gold.copy(alpha = 0.12f))
                                    .clickable { confirming = p }.padding(horizontal = 12.dp, vertical = 8.dp),
                                color = Palette.gold, fontWeight = FontWeight.SemiBold, fontSize = 13.sp,
                            )
                        }
                    }
                }
            }

            // Qibla shortcut
            Row(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Color.White).clickable { Nav.push(Route.Qibla) }.padding(14.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(Modifier.size(40.dp).clip(CircleShape).background(Palette.green.copy(alpha = 0.12f)), contentAlignment = Alignment.Center) {
                    Icon(Icons.Filled.Explore, null, tint = Palette.green)
                }
                Spacer(Modifier.width(12.dp))
                Column(Modifier.weight(1f)) {
                    Text(t("Qibla Compass"), fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
                    Secondary(t("Find the direction of the Kaaba"), size = 13)
                }
                Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = Palette.textSecondary)
            }

            if (!hideWidgetPromo) {
                Column(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(Palette.cream)
                        .border(1.dp, Palette.gold.copy(alpha = 0.45f), RoundedCornerShape(14.dp)).padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(t("Add SalahAlarm to your Home Screen"), fontWeight = FontWeight.Bold, fontSize = 16.sp, modifier = Modifier.weight(1f))
                        IconButton(onClick = {
                            Graph.store.setFlag("hide_widget_promo")
                            hideWidgetPromo = true
                        }) { Icon(Icons.Filled.Close, null, tint = Palette.textSecondary) }
                    }
                    Secondary(t("See your streak and next prayer time without opening the app."))
                    Secondary(t("Touch and hold your home screen, tap Widgets, then find SalahAlarm."), size = 13)
                }
            }
        }
    }

    confirming?.let { p ->
        ConfirmPrayerDialog(p, onConfirm = {
            repo.confirm(p)
            confirming = null
        }, onDismiss = { confirming = null })
    }
}

@Composable
fun Banner(
    icon: @Composable () -> Unit,
    title: String,
    body: String,
    action: String,
    background: Color,
    border: Color,
    onClick: () -> Unit,
) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(background)
            .border(1.dp, border, RoundedCornerShape(12.dp)).clickable(onClick = onClick).padding(14.dp),
    ) {
        icon()
        Spacer(Modifier.width(12.dp))
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(title, fontWeight = FontWeight.Bold, fontSize = 14.sp)
            Secondary(body, size = 12)
            Text(action, color = Palette.gold, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
        }
    }
}

@Composable
private fun DuaCard(now: java.time.Instant) {
    val dua = DuaLibrary.dua(now)
    val theme = DuaLibrary.theme(now)
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp))
            .background(Brush.linearGradient(listOf(Color(theme.top), Color(theme.bottom))))
            .padding(18.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text(t("DUA OF THE MOMENT"), fontSize = 10.sp, fontWeight = FontWeight.Bold, color = Color.White.copy(alpha = 0.75f), letterSpacing = 1.1.sp)
        Text("“${dua.english}”", fontSize = 17.sp, fontWeight = FontWeight.SemiBold, fontFamily = FontFamily.Serif, color = Color.White)
        androidx.compose.runtime.CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
            Text(dua.arabic, fontSize = 19.sp, fontWeight = FontWeight.Medium, color = Color(theme.accent), modifier = Modifier.fillMaxWidth())
        }
        Text(dua.reference, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Color.White.copy(alpha = 0.7f))
    }
}

fun statusColor(s: PrayerLogic.Status): Color = when (s) {
    PrayerLogic.Status.CONFIRMED -> Palette.green
    PrayerLogic.Status.MISSED -> Color.Red
    PrayerLogic.Status.UPCOMING -> Palette.border
}

/** iOS short labels ("Mghrb" for Maghrib keeps five columns on narrow phones). */
fun shortLabel(p: PrayerName): String = if (p == PrayerName.MAGHRIB) "Mghrb" else p.displayName

fun relative(to: java.time.Instant, now: java.time.Instant): String {
    val secs = maxOf(0L, java.time.Duration.between(now, to).seconds)
    val h = secs / 3600
    val m = (secs / 60) % 60
    return if (h > 0) tf("in %dh %dm", h, m) else tf("in %dm", m)
}

@Suppress("unused")
private fun nextPrayerOf(now: java.time.Instant) = PrayerCalculator.nextPrayer(Graph.repo.schedules(), now)
