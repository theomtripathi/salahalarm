package com.salahalarm.android.ui

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Shader
import android.graphics.Typeface
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.RadioButtonUnchecked
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.FileProvider
import com.salahalarm.android.Graph
import com.salahalarm.android.data.Analytics
import com.salahalarm.android.data.Api
import com.salahalarm.android.t
import com.salahalarm.android.tf
import com.salahalarm.core.ChallengeProgress
import com.salahalarm.core.DailyPrayerLog
import com.salahalarm.core.DateKeys
import com.salahalarm.core.PrayerLogic
import com.salahalarm.core.PrayerName
import com.salahalarm.core.RamadanChallenge
import kotlinx.coroutines.launch
import java.io.File

/*
 * The free 90-Day Ramadan Ready challenge (#ImRamadanReady), ported from iOS
 * RamadanChallengeViews.swift: the Home card, the details screen with joining,
 * invites and rules, the share image, and the free home for joiners without a plan.
 */

private val prayerEmoji = mapOf(
    PrayerName.FAJR to "🌅", PrayerName.DHUHR to "☀️", PrayerName.ASR to "🌤",
    PrayerName.MAGHRIB to "🌇", PrayerName.ISHA to "🌙",
)

@Composable
private fun rememberProgress(): ChallengeProgress? {
    val enrollment by Graph.repo.challenge.collectAsState()
    val logs by Graph.repo.logs.collectAsState()
    val today = Graph.repo.today()
    return enrollment?.let { remember(it, logs, today) { ChallengeProgress.compute(it, logs, today) } }
}

@Composable
fun ChallengeCard(onOpen: () -> Unit) {
    val enrollment by Graph.repo.challenge.collectAsState()
    val progress = rememberProgress()
    val today = Graph.repo.today()
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Color.White)
            .border(1.dp, Palette.gold.copy(alpha = 0.5f), RoundedCornerShape(16.dp))
            .clickable { onOpen() }.padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("🌙", fontSize = 22.sp)
            Spacer(Modifier.width(8.dp))
            Text(t("90-Day Ramadan Ready challenge"), fontSize = 16.sp, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = Palette.textSecondary)
        }
        if (enrollment == null || progress == null) {
            val start = RamadanChallenge.daysUntilStart(today)
            Secondary(
                if (start > 0) tf("Starts in %d days. Ramadan is in %d days.", start, RamadanChallenge.daysUntilRamadan(today))
                else tf("Ramadan is in %d days. Lock in all five prayers and walk in ready.", RamadanChallenge.daysUntilRamadan(today)),
            )
            if (RamadanChallenge.joiningOpen(today)) Text(
                t("Join free"), color = Color.White, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(Palette.green).padding(vertical = 10.dp),
            )
        } else if (progress.day == 0) {
            Secondary(tf("You're in. Day 1 starts in %d days.", RamadanChallenge.daysUntilStart(today)))
        } else {
            Row(verticalAlignment = Alignment.Bottom) {
                Text(tf("Day %d", progress.day), fontSize = 28.sp, fontWeight = FontWeight.Bold, color = Palette.gold)
                Spacer(Modifier.width(6.dp))
                Secondary(tf("of %d", RamadanChallenge.LENGTH_DAYS), modifier = Modifier.padding(bottom = 4.dp))
                Spacer(Modifier.weight(1f))
                Text(
                    t(if (progress.todayComplete) "Today done" else "Today in progress"), fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                    color = if (progress.todayComplete) Palette.green else Palette.textSecondary, modifier = Modifier.padding(bottom = 4.dp),
                )
            }
            LinearProgressIndicator(
                progress = { progress.day / RamadanChallenge.LENGTH_DAYS.toFloat() },
                modifier = Modifier.fillMaxWidth(), color = Palette.green, trackColor = Palette.border,
            )
            Secondary(
                if (progress.isOnTrack) tf("%@ · %d grace days left", t(RamadanChallenge.phaseTitle(progress.phase)), progress.graceLeftThisPhase)
                else t("Off track for Ramadan Ready, but keep going for Silver and Bronze."),
                size = 13,
            )
        }
    }
}

@Composable
fun ChallengeScreen(onBack: () -> Unit) {
    val context = LocalContext.current
    val repo = Graph.repo
    val scope = rememberCoroutineScope()
    val enrollment by repo.challenge.collectAsState()
    val counts by repo.challengeCounts.collectAsState()
    val progress = rememberProgress()
    var typed by remember { mutableStateOf(repo.pendingInvite().orEmpty()) }
    var joining by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    BackHandler(onBack = onBack)
    LaunchedEffect(Unit) {
        Analytics.capture("challenge_screen_viewed", mapOf("joined" to (enrollment != null)))
        repo.refreshChallenge()
    }

    Column(Modifier.fillMaxSize().background(Palette.cream).systemBarsPadding()) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)) {
            IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = t("Done")) }
            Text(t("Ramadan Ready"), fontSize = 20.sp, fontWeight = FontWeight.Bold)
        }
        Column(Modifier.verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
            Text(t("Be Ramadan ready in 90 days"), fontSize = 24.sp, fontWeight = FontWeight.Bold)
            Secondary(t("Pray all five prayers on time every day from 10 November to 7 February, starting with Fajr. Free to join. No purchase needed."))
            counts.first?.takeIf { it > 0 }?.let { Text(tf("%d people have joined", it), color = Palette.green, fontWeight = FontWeight.SemiBold) }

            val e = enrollment
            if (e == null && !RamadanChallenge.joiningOpen(repo.today())) {
                Text(t("Joining closed on 9 January."), color = Palette.alarmRed, fontWeight = FontWeight.SemiBold)
            } else if (e == null) {
                OutlinedTextField(
                    value = typed, onValueChange = { typed = it.take(6).uppercase() }, singleLine = true,
                    label = { Text(t("Got an invite code? (optional)")) }, modifier = Modifier.fillMaxWidth(),
                )
                error?.let { Text(t(it), color = Palette.alarmRed, fontSize = 14.sp) }
                PrimaryButton(t("Join the challenge free"), enabled = !joining) {
                    scope.launch {
                        joining = true
                        error = repo.joinChallenge(typed.ifBlank { null })
                        joining = false
                    }
                }
                if (joining) CircularProgressIndicator(color = Palette.green, modifier = Modifier.align(Alignment.CenterHorizontally))
            } else {
                progress?.let { p ->
                    SLCard {
                        Text(
                            if (p.day == 0) tf("Day 1 starts in %d days", RamadanChallenge.daysUntilStart(repo.today())) else tf("Day %d of %d", p.day, RamadanChallenge.LENGTH_DAYS),
                            fontSize = 22.sp, fontWeight = FontWeight.Bold, color = Palette.gold,
                        )
                        Spacer(Modifier.height(10.dp))
                        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            Stat(t("Days done"), "${p.completedDays}", Modifier.weight(1f))
                            Stat(t("Missed"), "${p.missedDays}", Modifier.weight(1f))
                            Stat(t("Grace left"), "${p.graceLeftThisPhase}", Modifier.weight(1f))
                        }
                        Spacer(Modifier.height(8.dp))
                        Secondary(tf("Current tier: %@", t(p.tier.title)), size = 13)
                    }
                    EntriesCard(p, counts.second)
                }
                SectionTitle(t("Invite friends"))
                SLCard {
                    Secondary(tf("Your code: %@", e.code))
                    Text(RamadanChallenge.inviteUrl(e.code).removePrefix("https://"), fontWeight = FontWeight.SemiBold, fontSize = 17.sp)
                    if (counts.second > 0) Secondary(tf("%d friends joined with your link", counts.second), size = 13)
                    Spacer(Modifier.height(10.dp))
                    PrimaryButton(t("Share my invite")) { progress?.let { shareChallenge(context, it, e.code) } }
                    Spacer(Modifier.height(8.dp))
                    SecondaryButton(t("Copy invite link")) {
                        val cm = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                        cm.setPrimaryClip(ClipData.newPlainText("invite", RamadanChallenge.inviteUrl(e.code)))
                        Analytics.capture("challenge_link_copied")
                    }
                }
            }

            SectionTitle(t("Rewards"))
            Bullets(
                "3 friends join with your link and complete Day 1: 1 month of premium free",
                "10 friends join with your link and complete Day 1: 1 year of premium free",
                "Free Makkah Trip draw on 10 February 2027: an Umrah trip for 2",
                "30 full days = 1 entry, 60 = 2, 90 = 3",
                tf("Plus 1 entry for each friend who joins with your code and logs a full day (up to %d)", RamadanChallenge.MAX_REFERRAL_ENTRIES),
            )
            Secondary(t("A full day means all five prayers logged. Join by 9 January. No purchase necessary; see the official rules for the free entry method."), size = 13)

            SectionTitle(t("How it works"))
            Bullets(
                "Days 1 to 30: build Fajr, and log all five prayers",
                "Days 31 to 60: all five prayers on time, plus a page of Quran",
                "Days 61 to 90: Monday and Thursday sunnah fasts to train for Ramadan",
            )
            Secondary(tf("%d grace days per phase, so one missed day doesn't end your challenge", RamadanChallenge.GRACE_DAYS_PER_PHASE), size = 13)

            TextButton(onClick = { openUrl(context, RamadanChallenge.RULES_URL) }) { Text(t("Official rules"), color = Palette.green) }
            Secondary(t("Free to join. No purchase necessary, and a purchase does not improve your chances."), size = 12)
        }
    }
}

/** Free Makkah Trip draw entries, like iOS entriesCard. */
@Composable
private fun EntriesCard(p: ChallengeProgress, friends: Int) {
    val own = RamadanChallenge.dayEntries(p.completedDays)
    val total = RamadanChallenge.totalEntries(p.completedDays, friends)
    val nextMilestone = minOf(RamadanChallenge.LENGTH_DAYS, (own + 1) * 30)
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(Color(0xFF0F3D2E).copy(alpha = 0.06f)).padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text(tf("Your entries: %d", total), fontSize = 20.sp, fontWeight = FontWeight.Bold, color = Palette.gold)
        Text(t("Free Makkah Trip draw: an Umrah trip for 2, drawn on 10 February 2027."), fontSize = 13.sp)
        if (own < 3) Secondary(tf("%d of %d full days for your next entry", p.completedDays, nextMilestone), size = 13)
        if (own == 0 && friends > 0) Secondary(t("Friend entries count once you've earned your first entry."), size = 12)
    }
}

@Composable
private fun Stat(title: String, value: String, modifier: Modifier) {
    Column(modifier.clip(RoundedCornerShape(12.dp)).background(Palette.cream).padding(10.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, fontSize = 20.sp, fontWeight = FontWeight.Bold)
        Text(title, fontSize = 12.sp, color = Palette.textSecondary, textAlign = TextAlign.Center, maxLines = 1)
    }
}

@Composable
private fun Bullets(vararg items: String) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        items.forEach { item ->
            Row {
                Text("•", color = Palette.green, fontWeight = FontWeight.Bold)
                Spacer(Modifier.width(8.dp))
                Text(t(item), fontSize = 14.sp)
            }
        }
    }
}

/** Joined the challenge without a plan: today's prayers, the challenge, and the way to premium. */
@Composable
fun ChallengeFreeHome() {
    val context = LocalContext.current
    val repo = Graph.repo
    val logs by repo.logs.collectAsState()
    val location by repo.location.collectAsState()
    val prefs by repo.prayerPrefs.collectAsState()
    val now by rememberNow(30_000)
    var showChallenge by remember { mutableStateOf(com.salahalarm.android.ui.Nav.openChallenge) }
    var confirming by remember { mutableStateOf<PrayerName?>(null) }
    val today = repo.today()
    val schedule = remember(today, location, prefs) { repo.todaySchedule() }
    val todayLog = logs[DateKeys.of(today)] ?: DailyPrayerLog()

    LaunchedEffect(Unit) {
        Analytics.capture("challenge_free_home_viewed")
        repo.refreshChallenge()
    }
    LaunchedEffect(Nav.openChallenge) {
        if (Nav.openChallenge) {
            showChallenge = true
            Nav.openChallenge = false
        }
    }

    if (showChallenge) {
        ChallengeScreen(onBack = { showChallenge = false })
        return
    }

    Column(Modifier.fillMaxSize().background(Palette.cream).systemBarsPadding().verticalScroll(rememberScrollState()).padding(20.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
        Text(t("Today's prayers"), fontSize = 26.sp, fontWeight = FontWeight.Bold)
        ChallengeCard { showChallenge = true }
        Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Color.White)) {
            PrayerName.entries.forEach { p ->
                val done = todayLog.isConfirmed(p)
                Row(
                    Modifier.fillMaxWidth().clickable(enabled = !done) { confirming = p }.padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(prayerEmoji.getValue(p), fontSize = 20.sp)
                    Spacer(Modifier.width(12.dp))
                    Column(Modifier.weight(1f)) {
                        Text(t(p.displayName), fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
                        schedule?.let { Secondary(timeString(it.time(p)), size = 13) }
                    }
                    val missed = PrayerLogic.status(p, todayLog, schedule, now) == PrayerLogic.Status.MISSED
                    Icon(
                        if (done) Icons.Filled.CheckCircle else Icons.Filled.RadioButtonUnchecked, null,
                        tint = if (done) Palette.green else if (missed) Palette.alarmRed else Palette.border, modifier = Modifier.size(24.dp),
                    )
                }
            }
        }
        SLCard {
            Text(t("Never sleep through Fajr"), fontSize = 18.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(6.dp))
            Secondary(t("Premium adds the loud adhan alarm that won't stop until you're up, SalahLock, the Quran reader and widgets."))
            Spacer(Modifier.height(12.dp))
            PrimaryButton(t("Unlock premium"), color = Palette.gold) {
                Analytics.capture("challenge_unlock_premium_tapped")
                openUrl(context, Api.paywallUrl("challenge"))
            }
        }
        repo.user.value?.email?.let { Secondary(it, align = TextAlign.Center, modifier = Modifier.fillMaxWidth()) }
        TextButton(onClick = { repo.signOut() }, modifier = Modifier.align(Alignment.CenterHorizontally)) { Text(t("Sign Out"), color = Palette.green) }
    }

    confirming?.let { p ->
        ConfirmPrayerDialog(prayer = p, onConfirm = { repo.confirm(p); confirming = null }, onDismiss = { confirming = null })
    }
}

/** Draws the 9:16 share card (like iOS ChallengeShareCard) and opens the share sheet. */
fun shareChallenge(context: Context, progress: ChallengeProgress, code: String) {
    val w = 1080
    val hgt = 1920
    val bmp = Bitmap.createBitmap(w, hgt, Bitmap.Config.ARGB_8888)
    val c = Canvas(bmp)
    val bg = Paint().apply { shader = LinearGradient(0f, 0f, 0f, hgt.toFloat(), 0xFF0F3D2E.toInt(), 0xFF071A14.toInt(), Shader.TileMode.CLAMP) }
    c.drawRect(0f, 0f, w.toFloat(), hgt.toFloat(), bg)
    fun text(s: String, y: Float, size: Float, color: Int, bold: Boolean = true, mono: Boolean = false) {
        val p = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = color
            textSize = size
            textAlign = Paint.Align.CENTER
            typeface = if (mono) Typeface.MONOSPACE else Typeface.create(Typeface.DEFAULT, if (bold) Typeface.BOLD else Typeface.NORMAL)
        }
        c.drawText(s, w / 2f, y, p)
    }
    val today = Graph.repo.today()
    text("🌙", 700f, 150f, 0xFFFFFFFF.toInt())
    text(if (progress.day == 0) t("I'm in") else tf("Day %d of %d", progress.day, RamadanChallenge.LENGTH_DAYS), 900f, 120f, 0xFFFFFFFF.toInt())
    text(tf("%d days until Ramadan", RamadanChallenge.daysUntilRamadan(today)), 1010f, 60f, 0xFFC9A028.toInt())
    text(RamadanChallenge.HASHTAG, 1130f, 66f, 0xFFFFFFFF.toInt())
    text("salahalarm.com/c/$code", 1230f, 46f, 0xD9FFFFFF.toInt(), mono = true)

    val dir = File(context.cacheDir, "share").apply { mkdirs() }
    val file = File(dir, "ramadan-ready.png")
    file.outputStream().use { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }
    val uri = FileProvider.getUriForFile(context, context.packageName + ".files", file)
    val message = tf("I'm getting Ramadan ready in 90 days. Join me free: %@ %@", RamadanChallenge.inviteUrl(code), RamadanChallenge.HASHTAG)
    val send = Intent(Intent.ACTION_SEND).apply {
        type = "image/png"
        putExtra(Intent.EXTRA_STREAM, uri)
        putExtra(Intent.EXTRA_TEXT, message)
        putExtra(Intent.EXTRA_SUBJECT, t("Join me in the Ramadan Ready challenge"))
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }
    Analytics.capture("challenge_shared", mapOf("day" to progress.day))
    runCatching { context.startActivity(Intent.createChooser(send, t("Share my invite")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
}
