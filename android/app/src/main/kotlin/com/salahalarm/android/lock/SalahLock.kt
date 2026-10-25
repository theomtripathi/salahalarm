package com.salahalarm.android.lock

import android.accessibilityservice.AccessibilityService
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.drawable.Drawable
import android.os.Bundle
import android.provider.Settings
import android.view.accessibility.AccessibilityEvent
import androidx.activity.ComponentActivity
import androidx.activity.addCallback
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.salahalarm.android.Graph
import com.salahalarm.android.t
import com.salahalarm.android.tf
import com.salahalarm.android.ui.ConfirmPrayerDialog
import com.salahalarm.android.ui.Palette
import com.salahalarm.android.ui.PrimaryButton
import com.salahalarm.android.ui.SalahTheme
import com.salahalarm.android.ui.SecondaryButton
import com.salahalarm.android.ui.rememberNow
import com.salahalarm.core.LockPolicy
import com.salahalarm.core.PrayerName
import java.time.Instant

/**
 * SalahLock for Android. iOS uses Screen Time; Android has no equivalent for
 * other apps, so an accessibility service watches which app comes to the front
 * and covers a locked app with the "pray to unlock" screen. The rule is the
 * same as iOS (LockPolicy): during an enforced prayer's window, until that
 * prayer is confirmed.
 */
class SalahLockService : AccessibilityService() {
    private var lastShown = 0L

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return
        if (pkg == packageName) return
        Graph.init(this)
        val lock = Graph.repo.lock.value
        if (!lock.enabled || pkg !in lock.packages) return
        val prayer = SalahLock.blockingPrayer() ?: return
        val now = System.currentTimeMillis()
        if (now - lastShown < 700) return
        lastShown = now
        startActivity(
            Intent(this, LockActivity::class.java)
                .putExtra(LockActivity.EXTRA_PRAYER, prayer.id)
                .putExtra(LockActivity.EXTRA_PACKAGE, pkg)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
        )
    }

    override fun onInterrupt() {}
}

object SalahLock {
    fun blockingPrayer(now: Instant = Instant.now()): PrayerName? {
        val repo = Graph.repo
        val lock = repo.lock.value
        if (!lock.enabled || lock.packages.isEmpty()) return null
        return LockPolicy.blockingPrayer(repo.todaySchedule(), repo.todayLog(), lock.enforced, now, repo.endOfToday())
    }

    fun serviceEnabled(context: Context): Boolean {
        val enabled = Settings.Secure.getString(context.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: return false
        val me = ComponentName(context, SalahLockService::class.java)
        return enabled.split(':').any { ComponentName.unflattenFromString(it) == me }
    }

    data class AppInfo(val packageName: String, val label: String, val icon: Drawable?)

    /** Apps with a launcher icon, except this one and the phone's own launcher/settings. */
    fun launchableApps(context: Context): List<AppInfo> {
        val pm = context.packageManager
        val main = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val home = pm.resolveActivity(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME), PackageManager.MATCH_DEFAULT_ONLY)
            ?.activityInfo?.packageName
        val skip = setOf(context.packageName, home, "com.android.settings", "com.android.dialer", "com.google.android.dialer")
        return pm.queryIntentActivities(main, 0)
            .map { it.activityInfo }
            .filter { it.packageName !in skip }
            .distinctBy { it.packageName }
            .map { AppInfo(it.packageName, it.loadLabel(pm).toString(), runCatching { it.loadIcon(pm) }.getOrNull()) }
            .sortedBy { it.label.lowercase() }
    }

    fun appLabel(context: Context, pkg: String): String =
        runCatching { context.packageManager.getApplicationInfo(pkg, 0).loadLabel(context.packageManager).toString() }.getOrDefault(pkg)
}

/** The shield shown over a locked app. Port of the iOS SalahLock shield. */
class LockActivity : ComponentActivity() {
    companion object {
        const val EXTRA_PRAYER = "prayer"
        const val EXTRA_PACKAGE = "package"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Graph.init(this)
        onBackPressedDispatcher.addCallback(this) { goHome() }
        setContent { SalahTheme { LockShield() } }
    }

    private fun goHome() {
        startActivity(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        finish()
    }

    @Composable
    private fun LockShield() {
        val now by rememberNow(5000)
        val logs by Graph.repo.logs.collectAsState()
        var confirming by remember { mutableStateOf(false) }
        val prayer = remember(now, logs) { SalahLock.blockingPrayer(now) }
        val pkg = intent.getStringExtra(EXTRA_PACKAGE)
        val appName = remember(pkg) { pkg?.let { SalahLock.appLabel(this, it) } }

        if (prayer == null) {
            // Prayer confirmed or its window ended: let them back into the app.
            androidx.compose.runtime.LaunchedEffect(Unit) {
                if (pkg != null) packageManager.getLaunchIntentForPackage(pkg)?.let { startActivity(it) }
                finish()
            }
            return
        }

        Box(Modifier.fillMaxSize().background(Palette.cream).systemBarsPadding().padding(24.dp), contentAlignment = Alignment.Center) {
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
                Box(Modifier.size(84.dp).clip(CircleShape).background(Palette.alarmRedLight), contentAlignment = Alignment.Center) {
                    Icon(Icons.Filled.Lock, contentDescription = null, tint = Palette.alarmRed, modifier = Modifier.size(38.dp))
                }
                Text(t("Your apps are locked"), fontSize = 24.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
                Text(
                    tf("Pray %@ (%@) to unlock your apps", t(prayer.displayName), prayer.arabicName),
                    fontSize = 16.sp, color = Palette.textSecondary, textAlign = TextAlign.Center,
                )
                if (appName != null) Text(appName, fontSize = 13.sp, color = Palette.textSecondary)
                Spacer(Modifier.height(10.dp))
                PrimaryButton(tf("I've prayed %@ 🤲", t(prayer.displayName))) { confirming = true }
                SecondaryButton(t("Go to home screen")) { goHome() }
            }
        }

        if (confirming) {
            ConfirmPrayerDialog(
                prayer = prayer,
                onConfirm = {
                    Graph.repo.confirm(prayer)
                    confirming = false
                },
                onDismiss = { confirming = false },
            )
        }
    }
}
