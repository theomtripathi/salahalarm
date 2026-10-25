package com.salahalarm.android.ui

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Apps
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.LockOpen
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CheckboxDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.core.graphics.drawable.toBitmap
import com.salahalarm.android.Graph
import com.salahalarm.android.data.Analytics
import com.salahalarm.android.lock.SalahLock
import com.salahalarm.android.t
import com.salahalarm.android.tf
import com.salahalarm.core.LockPolicy
import com.salahalarm.core.PrayerName
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** Port of iOS LockTabView, with Android's accessibility switch in place of Screen Time. */
@Composable
fun LockScreen() {
    val context = LocalContext.current
    val repo = Graph.repo
    val now by rememberNow(2000)
    val lock by repo.lock.collectAsState()
    val logs by repo.logs.collectAsState()
    var confirming by remember { mutableStateOf<PrayerName?>(null) }
    var picking by remember { mutableStateOf(false) }
    val connected = remember(now) { SalahLock.serviceEnabled(context) }
    val armed = lock.enabled && connected && lock.packages.isNotEmpty() && lock.enforced.isNotEmpty()
    val blocking = remember(now, logs, lock) { if (connected) SalahLock.blockingPrayer(now) else null }

    Column(Modifier.verticalScroll(rememberScrollState())) {
        ScreenColumn {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Filled.Lock, null, tint = Palette.green)
                Spacer(Modifier.width(10.dp))
                Text("SalahLock", fontSize = 22.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.weight(1f))
                Row(
                    Modifier.clip(RoundedCornerShape(50)).border(1.dp, Palette.border, RoundedCornerShape(50)).padding(horizontal = 10.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Box(Modifier.size(8.dp).clip(CircleShape).background(if (blocking != null) Palette.alarmRed else Palette.green))
                    Spacer(Modifier.width(6.dp))
                    Text(t(if (blocking != null) "locked" else if (armed) "armed" else "off"), fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                }
            }

            SLCard {
                if (blocking != null) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(Modifier.size(44.dp).clip(CircleShape).background(Palette.alarmRedLight), contentAlignment = Alignment.Center) {
                            Icon(Icons.Filled.Lock, null, tint = Palette.alarmRed)
                        }
                        Spacer(Modifier.width(12.dp))
                        Column {
                            Text(t("Your apps are locked"), fontWeight = FontWeight.Bold, fontSize = 17.sp)
                            Secondary(tf("Pray %@ (%@) to unlock your apps", t(blocking.displayName), blocking.arabicName), size = 13)
                        }
                    }
                    Spacer(Modifier.height(14.dp))
                    PrimaryButton(tf("I've prayed %@ 🤲", t(blocking.displayName))) { confirming = blocking }
                } else {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(Modifier.size(44.dp).clip(CircleShape).background(Palette.green.copy(alpha = 0.12f)), contentAlignment = Alignment.Center) {
                            Icon(Icons.Filled.LockOpen, null, tint = Palette.green)
                        }
                        Spacer(Modifier.width(12.dp))
                        Column {
                            Text(t("Apps unlocked"), fontWeight = FontWeight.Bold, fontSize = 17.sp)
                            Secondary(nextLockText(armed, now), size = 13)
                        }
                    }
                }
            }

            if (!connected) {
                SLCard {
                    SectionTitle(t("Turn on SalahLock"))
                    Spacer(Modifier.height(8.dp))
                    Secondary(t("Android needs you to switch SalahLock on in Accessibility. It only sees which app is open, so it can cover the apps you choose during prayer time. Nothing is tracked and nothing leaves your phone."))
                    Spacer(Modifier.height(12.dp))
                    PrimaryButton(t("Open Accessibility settings")) {
                        Analytics.capture("salahlock_connect_tapped")
                        runCatching { context.startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
                    }
                    Spacer(Modifier.height(10.dp))
                    Secondary(t("Find SalahLock under Downloaded apps and turn it on. If Android says the setting is restricted, open App info, tap ⋮, choose Allow restricted settings, then try again."), size = 13)
                    TextButton(onClick = {
                        runCatching {
                            context.startActivity(
                                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}"))
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                            )
                        }
                    }) { Text(t("Open App info"), color = Palette.green) }
                }
            }

            SLCard {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    SectionTitle(t("Locked apps"), Modifier.weight(1f))
                    Icon(Icons.Filled.Apps, null, tint = Palette.green)
                }
                Spacer(Modifier.height(8.dp))
                Secondary(
                    if (lock.packages.isEmpty()) t("Choose the apps that distract you from salah")
                    else tf("%d apps", lock.packages.size),
                )
                Spacer(Modifier.height(12.dp))
                SecondaryButton(t(if (lock.packages.isEmpty()) "Choose apps" else "Change apps")) { picking = true }
            }

            SLCard {
                SectionTitle(t("Lock for these prayers"))
                Spacer(Modifier.height(6.dp))
                Secondary(t("Your apps lock when prayer time arrives and unlock when you confirm you've prayed."), size = 13)
                Spacer(Modifier.height(12.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    PrayerName.entries.forEach { p ->
                        Pill(t(p.displayName), p in lock.enforced, Modifier.weight(1f)) {
                            repo.updateLock { l -> l.copy(enforced = if (p in l.enforced) l.enforced - p else l.enforced + p) }
                        }
                    }
                }
                if (lock.enforced.isEmpty()) {
                    Spacer(Modifier.height(8.dp))
                    Text(t("Select at least one prayer to activate the lock"), color = Palette.alarmRed, fontSize = 12.sp)
                }
            }

            SLCard {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(t("Prayer lock"), fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
                        Secondary(t("Turn off to pause app locking"), size = 13)
                    }
                    Switch(
                        checked = lock.enabled,
                        onCheckedChange = { on -> repo.updateLock { it.copy(enabled = on) } },
                        colors = SwitchDefaults.colors(checkedTrackColor = Palette.green),
                    )
                }
            }

            SLCard {
                SectionTitle(t("How it works"))
                Spacer(Modifier.height(10.dp))
                listOf(
                    "Prayer time arrives", "Your chosen apps get locked", "You pray", "Confirm that you've prayed to unlock",
                ).forEachIndexed { i, step ->
                    Row(Modifier.padding(vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                        Box(Modifier.size(26.dp).clip(CircleShape).background(Palette.green), contentAlignment = Alignment.Center) {
                            Text("${i + 1}", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                        }
                        Spacer(Modifier.width(12.dp))
                        Text(t(step), fontSize = 15.sp)
                    }
                }
                Spacer(Modifier.height(6.dp))
                Secondary(t("Keep SalahAlarm on your phone — deleting the app removes the lock."), size = 12)
            }
        }
    }

    if (picking) AppPicker(onDone = { picking = false })
    confirming?.let { p ->
        ConfirmPrayerDialog(p, onConfirm = {
            repo.confirm(p)
            confirming = null
        }, onDismiss = { confirming = null })
    }
}

private fun nextLockText(armed: Boolean, now: java.time.Instant): String {
    if (!armed) return t("Finish setup below to activate the prayer lock")
    val repo = Graph.repo
    if (repo.location.value == null) return t("Waiting for your prayer times…")
    val next = LockPolicy.nextLockTime(repo.schedules(repo.today(), 1), repo.lock.value.enforced, now)
        ?: return t("No more locks today — see you at the next prayer")
    return tf("Apps lock at %@, %@", t(next.first.displayName), timeString(next.second))
}

@Composable
private fun AppPicker(onDone: () -> Unit) {
    val context = LocalContext.current
    val repo = Graph.repo
    val lock by repo.lock.collectAsState()
    var apps by remember { mutableStateOf<List<SalahLock.AppInfo>?>(null) }
    var query by remember { mutableStateOf("") }
    LaunchedEffect(Unit) { apps = withContext(Dispatchers.IO) { SalahLock.launchableApps(context) } }

    Dialog(onDismissRequest = onDone, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Column(Modifier.fillMaxSize().background(Palette.cream).systemBarsPadding().padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(t("Choose apps"), fontSize = 20.sp, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                TextButton(onClick = onDone) { Text(t("Done"), color = Palette.green, fontWeight = FontWeight.SemiBold) }
            }
            OutlinedTextField(
                value = query, onValueChange = { query = it }, singleLine = true,
                placeholder = { Text(t("Search apps")) }, modifier = Modifier.fillMaxWidth(),
            )
            Spacer(Modifier.height(8.dp))
            val list = apps
            if (list == null) {
                Box(Modifier.fillMaxWidth().padding(40.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = Palette.green) }
            } else {
                val shown = list.filter { query.isBlank() || it.label.contains(query, ignoreCase = true) }
                    .sortedByDescending { it.packageName in lock.packages }
                LazyColumn {
                    items(shown, key = { it.packageName }) { app ->
                        val checked = app.packageName in lock.packages
                        Row(
                            Modifier.fillMaxWidth().clickable {
                                repo.updateLock { l -> l.copy(packages = if (checked) l.packages - app.packageName else l.packages + app.packageName) }
                            }.padding(vertical = 8.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            val bmp = remember(app.packageName) { runCatching { app.icon?.toBitmap(96, 96)?.asImageBitmap() }.getOrNull() }
                            if (bmp != null) Image(bmp, null, Modifier.size(36.dp)) else Spacer(Modifier.size(36.dp))
                            Spacer(Modifier.width(12.dp))
                            Text(app.label, fontSize = 15.sp, modifier = Modifier.weight(1f))
                            Checkbox(
                                checked = checked,
                                onCheckedChange = {
                                    repo.updateLock { l -> l.copy(packages = if (checked) l.packages - app.packageName else l.packages + app.packageName) }
                                },
                                colors = CheckboxDefaults.colors(checkedColor = Palette.green),
                            )
                        }
                    }
                }
            }
        }
    }
}
