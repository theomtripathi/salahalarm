package com.salahalarm.android.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.salahalarm.android.Graph
import com.salahalarm.android.I18n
import com.salahalarm.android.t
import com.salahalarm.android.tf
import com.salahalarm.core.DailyPrayerLog
import com.salahalarm.core.DateKeys
import com.salahalarm.core.PrayerName
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.temporal.TemporalAdjusters

/** Port of iOS PrayerHistoryView: totals, weekly heatmap or monthly calendar, and the last 14 days. */
@Composable
fun PrayersScreen() {
    val repo = Graph.repo
    val logs by repo.logs.collectAsState()
    val streak by repo.streak.collectAsState()
    var monthly by remember { mutableStateOf(false) }
    var offset by remember { mutableIntStateOf(0) }
    val today = repo.today()
    fun log(d: LocalDate): DailyPrayerLog = logs[DateKeys.of(d)] ?: DailyPrayerLog()
    val todayCount = log(today).prayedCount

    Column(Modifier.verticalScroll(rememberScrollState())) {
        ScreenColumn {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(t("Prayer History"), fontSize = 22.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.weight(1f))
                StreakBadge(streak.displayed(today), todayCount > 0)
            }

            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                StatTile("🔥", "${streak.displayed(today)}", t("day streak"))
                StatTile("🕌", "${streak.totalPrayersConfirmed}", t("prayers total"))
                StatTile("📅", "${streak.totalPrayerDays}", t("full days"))
                StatTile("⏱", String.format(java.util.Locale.US, "%.1f", streak.hoursInSalah), t("hours in salah"))
            }

            SLCard(padding = 18) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Pill(t("Weekly"), !monthly, Modifier.weight(1f)) { monthly = false; offset = 0 }
                    Pill(t("Monthly"), monthly, Modifier.weight(1f)) { monthly = true; offset = 0 }
                    IconButton(onClick = { offset -= 1 }) { Icon(Icons.AutoMirrored.Filled.KeyboardArrowLeft, null) }
                    IconButton(onClick = { offset += 1 }, enabled = offset < 0) { Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null) }
                }
                Spacer(Modifier.height(14.dp))
                if (monthly) {
                    val month = today.plusMonths(offset.toLong()).withDayOfMonth(1)
                    Text(month.format(DateTimeFormatter.ofPattern("MMMM yyyy", I18n.locale)), fontWeight = FontWeight.SemiBold)
                    Spacer(Modifier.height(10.dp))
                    MonthGrid(month, today, ::log)
                } else {
                    val start = today.plusWeeks(offset.toLong()).with(TemporalAdjusters.previousOrSame(DayOfWeek.SUNDAY))
                    val days = (0..6).map { start.plusDays(it.toLong()) }
                    Row {
                        Spacer(Modifier.width(52.dp))
                        days.forEach { d ->
                            Text(
                                d.format(DateTimeFormatter.ofPattern("EEEEE", I18n.locale)), modifier = Modifier.weight(1f),
                                textAlign = TextAlign.Center, fontSize = 11.sp, color = Palette.textSecondary,
                            )
                        }
                    }
                    Spacer(Modifier.height(6.dp))
                    PrayerName.entries.forEach { p ->
                        Row(Modifier.padding(vertical = 5.dp), verticalAlignment = Alignment.CenterVertically) {
                            Text(t(shortLabel(p)), fontSize = 12.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.width(52.dp), maxLines = 1)
                            days.forEach { d ->
                                val done = log(d).isConfirmed(p)
                                val color = when {
                                    done -> Palette.green
                                    d < today -> Color(0xFFFFE5E5)
                                    else -> Color.Transparent
                                }
                                Box(Modifier.weight(1f), contentAlignment = Alignment.Center) {
                                    Box(Modifier.size(16.dp).clip(CircleShape).background(color).border(1.dp, Palette.border, CircleShape))
                                }
                            }
                        }
                    }
                }
            }

            SectionTitle(t("Recent Prayer Log"))
            (0 until 14).forEach { back ->
                val d = today.minusDays(back.toLong())
                val l = log(d)
                Row(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(Color.White).padding(14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(d.format(DateTimeFormatter.ofPattern("EEE, MMM d", I18n.locale)), fontSize = 14.sp, fontWeight = FontWeight.Medium, modifier = Modifier.weight(1f))
                    PrayerName.entries.forEach { p ->
                        Text(if (l.isConfirmed(p)) "✅" else "•", color = if (l.isConfirmed(p)) Palette.green else Palette.tabUnselected, modifier = Modifier.padding(horizontal = 3.dp))
                    }
                    Spacer(Modifier.width(8.dp))
                    Text("${l.prayedCount}/5", color = Palette.gold, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                }
            }
        }
    }
}

@Composable
private fun MonthGrid(month: LocalDate, today: LocalDate, log: (LocalDate) -> DailyPrayerLog) {
    val days = (1..month.lengthOfMonth()).map { month.withDayOfMonth(it) }
    days.chunked(7).forEach { week ->
        Row(Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
            week.forEach { d ->
                val count = log(d).prayedCount
                val color = when {
                    d > today -> Palette.border
                    count == 5 -> Palette.green
                    count >= 3 -> Palette.gold
                    count >= 1 -> Color(0xFFFF9800)
                    else -> Color.Red
                }
                Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text("${d.dayOfMonth}", fontSize = 12.sp, fontWeight = FontWeight.Medium)
                    Box(Modifier.size(10.dp).clip(CircleShape).background(color))
                }
            }
            repeat(7 - week.size) { Spacer(Modifier.weight(1f)) }
        }
    }
}

@Composable
fun StatTile(emoji: String, value: String, label: String) {
    Column(
        Modifier.size(width = 96.dp, height = 96.dp).clip(RoundedCornerShape(14.dp)).background(Color.White).padding(8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(emoji, fontSize = 22.sp)
        Text(value, fontSize = 20.sp, fontWeight = FontWeight.Bold)
        Text(label, fontSize = 11.sp, color = Palette.textSecondary, textAlign = TextAlign.Center, maxLines = 2)
    }
}

@Suppress("unused")
private fun summary(count: Int) = tf("%d / 5 prayed", count)
