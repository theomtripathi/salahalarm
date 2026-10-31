package com.salahalarm.android.ui

import android.Manifest
import android.content.Intent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.RadioButton
import androidx.compose.material3.RadioButtonDefaults
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.salahalarm.android.BuildConfig
import com.salahalarm.android.Graph
import com.salahalarm.android.I18n
import com.salahalarm.android.data.Api
import com.salahalarm.android.t
import com.salahalarm.android.tf
import com.salahalarm.core.AlarmStrictness
import com.salahalarm.core.PrayerCalculator
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

private val methodNames = mapOf(
    "MuslimWorldLeague" to "Muslim World League",
    "UmmAlQura" to "Umm al-Qura, Makkah",
    "Dubai" to "Dubai",
    "Qatar" to "Qatar",
    "Kuwait" to "Kuwait",
    "Egyptian" to "Egyptian General Authority",
    "Turkey" to "Diyanet, Turkey",
    "Tehran" to "Tehran",
    "Karachi" to "University of Islamic Sciences, Karachi",
    "Singapore" to "Singapore, Malaysia, Indonesia",
    "NorthAmerica" to "ISNA, North America",
    "MoonsightingCommittee" to "Moonsighting Committee",
)

private fun dateString(i: Instant?): String =
    i?.let { DateTimeFormatter.ofPattern("d MMM yyyy", I18n.locale).format(it.atZone(ZoneId.systemDefault())) } ?: "--"

/** Port of iOS ProfileView. */
@Composable
fun ProfileScreen() {
    val context = LocalContext.current
    val repo = Graph.repo
    val scope = rememberCoroutineScope()
    val user by repo.user.collectAsState()
    val streak by repo.streak.collectAsState()
    val settings by repo.settings.collectAsState()
    val prefs by repo.prayerPrefs.collectAsState()
    val location by repo.location.collectAsState()
    val entitlement by repo.entitlement.collectAsState()
    val quran by repo.quranPrefs.collectAsState()
    var dialog by remember { mutableStateOf<String?>(null) }
    var info by remember { mutableStateOf<Pair<String, String>?>(null) }
    var busy by remember { mutableStateOf(false) }
    val now = Instant.now()
    val premium = entitlement.isActive(now)
    val name = displayName(user?.displayName, user?.email)

    val locationPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) {
        scope.launch { repo.refreshLocation() }
    }

    Column(Modifier.verticalScroll(rememberScrollState())) {
        ScreenColumn {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Avatar(initialsOf(name), size = 64, filled = true)
                Spacer(Modifier.width(16.dp))
                Column {
                    Text(name, fontSize = 20.sp, fontWeight = FontWeight.Bold)
                    user?.email?.let { Secondary(it, size = 13) }
                    val since = user?.metadata?.creationTimestamp?.let { Instant.ofEpochMilli(it) }
                    Secondary(tf("Member since %@", since?.let { DateTimeFormatter.ofPattern("MMM yyyy", I18n.locale).format(it.atZone(ZoneId.systemDefault())) } ?: "--"), size = 12)
                }
            }

            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                StatCard("🔥", "${streak.displayed(repo.today())}", t("Current streak"), Modifier.weight(1f))
                StatCard("🕌", "${streak.totalPrayersConfirmed}", t("Total prayers"), Modifier.weight(1f))
                StatCard("📅", "${streak.totalPrayerDays}", t("Full days"), Modifier.weight(1f))
            }

            Section(t("Prayer Settings")) {
                ActionRow(t("App language"), I18n.languages.first { it.code == I18n.lang }.name) { dialog = "language" }
                ActionRow(t("Location"), location?.city ?: t("Not set")) {
                    locationPermission.launch(arrayOf(Manifest.permission.ACCESS_COARSE_LOCATION, Manifest.permission.ACCESS_FINE_LOCATION))
                }
                val methodLabel = if (prefs.method == "auto") tf("Automatic (%@)", t(methodNames[repo.method()] ?: repo.method())) else t(methodNames[prefs.method] ?: prefs.method)
                ActionRow(t("Prayer calculation method"), methodLabel) { dialog = "method" }
                Text(t("Asr time"), fontSize = 14.sp, fontWeight = FontWeight.Medium)
                PillRow(
                    listOf("auto" to t("Automatic"), "shafi" to t("Standard"), "hanafi" to t("Hanafi")),
                    prefs.asr,
                ) { v -> repo.updatePrayerPrefs { it.copy(asr = v) } }
            }

            Section(t("Alarm Settings")) {
                if (!premium) {
                    Column(
                        Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(Palette.alarmRedLight).padding(12.dp),
                        verticalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        Text(t("Prayer alarms are premium"), fontWeight = FontWeight.Bold, color = Palette.alarmRed)
                        Secondary(t("Alarms are available with an active paid plan."), size = 13)
                        TextButton(onClick = { openUrl(context, Api.paywallUrl("profile")) }) { Text(t("Unlock alarms"), color = Palette.green) }
                    }
                }
                ToggleRow(t("Prayer alarms"), settings.alarmsEnabled && premium, enabled = premium) { on -> repo.updateSettings { it.copy(alarmsEnabled = on) } }
                Text(t("Alarm mode"), fontSize = 14.sp, fontWeight = FontWeight.Medium)
                PillRow(AlarmStrictness.entries.map { it.raw to t(it.displayLabel) }, settings.strictness.raw) { v ->
                    if (premium) repo.updateSettings { it.copy(strictness = AlarmStrictness.fromRaw(v)) }
                }
                ActionRow(t("Alarm sound"), t(settings.sound.displayName)) { Nav.push(Route.AlarmSettings) }
                ActionRow(t("Open Alarm Dashboard"), null) {
                    if (premium) Nav.push(Route.AlarmSettings) else openUrl(context, Api.paywallUrl("profile"))
                }
                ActionRow(t("Make sure alarms ring"), null) { Nav.push(Route.Setup) }
            }

            Section(t("Quran Settings")) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(t("Font size"), modifier = Modifier.weight(1f))
                    Secondary("${quran.fontSize.toInt()}")
                }
                Slider(
                    value = quran.fontSize, onValueChange = { v -> repo.updateQuranPrefs { it.copy(fontSize = v) } },
                    valueRange = 16f..40f, steps = 11,
                    colors = SliderDefaults.colors(thumbColor = Palette.green, activeTrackColor = Palette.green),
                )
                ToggleRow(t("Show translation"), quran.showTranslation) { on -> repo.updateQuranPrefs { it.copy(showTranslation = on) } }
            }

            Section(t("Account")) {
                val status = when {
                    premium && entitlement.isTrial -> tf("Free trial · ends %@", dateString(entitlement.accessUntil))
                    entitlement.trialEnded(now) -> t("Your free trial has ended")
                    premium && entitlement.cancelAtPeriodEnd -> tf("Premium until %@", dateString(entitlement.accessUntil))
                    premium -> tf("Premium · renews %@", dateString(entitlement.currentPeriodEnd ?: entitlement.accessUntil))
                    else -> t("No active subscription")
                }
                ActionRow(t("Subscription"), status, chevron = false) {}
                ActionRow(t("Manage Subscription"), null) {
                    scope.launch {
                        busy = true
                        val link = if (entitlement.manageable && !entitlement.isTrial) repo.portalLink() else null
                        busy = false
                        if (link != null) openUrl(context, link) else openUrl(context, Api.paywallUrl("profile_manage"))
                    }
                }
                ActionRow(t("Restore Purchases"), null) {
                    scope.launch {
                        busy = true
                        val ok = repo.refreshEntitlement(force = true)
                        busy = false
                        info = if (ok) t("Purchases Restored") to t("Your purchases have been restored.")
                        else t("Restore Failed") to t("No active subscription was found for this account. Sign in with the account you paid with.")
                    }
                }
                if (user?.providerData?.any { it.providerId == "password" } == true) {
                    ActionRow(t("Change Password"), null) {
                        val email = user?.email ?: return@ActionRow
                        scope.launch {
                            info = try {
                                repo.sendPasswordReset(email)
                                t("Password Reset Sent") to tf("A reset link was sent to %@.", email)
                            } catch (e: Exception) {
                                t("Reset Failed") to (e.localizedMessage ?: "")
                            }
                        }
                    }
                }
                ActionRow(t("Sign Out"), null, destructive = true) { dialog = "signout" }
                ActionRow(t("Delete Account"), null, destructive = true) { dialog = "delete" }
            }

            Section(t("About")) {
                ActionRow(t("Version"), BuildConfig.VERSION_NAME, chevron = false) {}
                ActionRow(t("Privacy Policy"), null) { openUrl(context, Api.PRIVACY_URL) }
                ActionRow(t("Terms of Use"), null) { openUrl(context, Api.TERMS_URL) }
                ActionRow(t("Send Feedback"), null) { openUrl(context, Api.SUPPORT_URL) }
                ActionRow(t("Share SalahAlarm"), null) {
                    val send = Intent(Intent.ACTION_SEND).setType("text/plain")
                        .putExtra(Intent.EXTRA_TEXT, t("SalahAlarm wakes me up for every prayer. Try it:") + " https://salahalarm.com/get")
                    runCatching { context.startActivity(Intent.createChooser(send, null)) }
                }
            }
            Spacer(Modifier.height(12.dp))
        }
    }

    when (dialog) {
        "language" -> ChoiceDialog(
            t("Choose your language"),
            I18n.languages.map { it.code to it.name },
            I18n.lang,
            onPick = { repo.setLanguage(it) },
            onClose = { dialog = null },
        )
        "method" -> ChoiceDialog(
            t("Prayer calculation method"),
            listOf("auto" to tf("Automatic (%@)", t(methodNames[PrayerCalculator.methodFor(location?.country)] ?: ""))) +
                PrayerCalculator.methods.map { it to t(methodNames[it] ?: it) },
            prefs.method,
            onPick = { v -> repo.updatePrayerPrefs { it.copy(method = v) } },
            onClose = { dialog = null },
        )
        "signout" -> AlertDialog(
            onDismissRequest = { dialog = null },
            title = { Text(t("Sign Out")) },
            text = { Text(t("Are you sure you want to sign out?")) },
            confirmButton = {
                TextButton(onClick = {
                    dialog = null
                    repo.signOut()
                }) { Text(t("Sign Out"), color = Palette.alarmRed) }
            },
            dismissButton = { TextButton(onClick = { dialog = null }) { Text(t("Cancel")) } },
        )
        "delete" -> AlertDialog(
            onDismissRequest = { dialog = null },
            title = { Text(t("Delete Account")) },
            text = {
                Text(
                    t("This action cannot be undone. All your data will be permanently deleted.") + "\n\n" +
                        t("Deleting your account does not cancel your subscription. Cancel it first under Manage Subscription."),
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    dialog = null
                    scope.launch {
                        info = try {
                            repo.deleteAccount()
                            t("Delete Account") to t("Your account has been deleted.")
                        } catch (e: Exception) {
                            t("Delete Account") to t("For your security, sign out, sign in again, and then delete your account.")
                        }
                    }
                }) { Text(t("Delete Account"), color = Palette.alarmRed) }
            },
            dismissButton = { TextButton(onClick = { dialog = null }) { Text(t("Cancel")) } },
        )
    }

    info?.let { (title, message) ->
        AlertDialog(
            onDismissRequest = { info = null },
            title = { Text(title) },
            text = { Text(message) },
            confirmButton = { TextButton(onClick = { info = null }) { Text(t("OK")) } },
        )
    }
    if (busy) {
        androidx.compose.ui.window.Dialog(onDismissRequest = {}) {
            androidx.compose.material3.CircularProgressIndicator(color = Color.White)
        }
    }
}

@Composable
private fun StatCard(emoji: String, value: String, label: String, modifier: Modifier) {
    Column(
        modifier.clip(RoundedCornerShape(14.dp)).background(Color.White).padding(vertical = 14.dp, horizontal = 6.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(emoji, fontSize = 22.sp)
        Text(value, fontSize = 20.sp, fontWeight = FontWeight.Bold)
        Text(label, fontSize = 11.sp, color = Palette.textSecondary, maxLines = 1)
    }
}

@Composable
fun Section(title: String, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(title.uppercase(I18n.locale), fontSize = 12.sp, fontWeight = FontWeight.Bold, color = Palette.textSecondary, letterSpacing = 0.8.sp)
        SLCard(padding = 16) {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) { content() }
        }
    }
}

@Composable
fun ActionRow(title: String, value: String?, chevron: Boolean = true, destructive: Boolean = false, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().heightIn(min = 40.dp).clickable(onClick = onClick),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(title, fontSize = 15.sp, color = if (destructive) Palette.alarmRed else Palette.textPrimary, modifier = Modifier.weight(1f))
        if (value != null) Secondary(value, size = 13)
        if (chevron) Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = Palette.textSecondary)
    }
}

@Composable
fun ToggleRow(title: String, checked: Boolean, enabled: Boolean = true, onChange: (Boolean) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(title, fontSize = 15.sp, modifier = Modifier.weight(1f))
        Switch(checked = checked, enabled = enabled, onCheckedChange = onChange, colors = SwitchDefaults.colors(checkedTrackColor = Palette.green))
    }
}

@Composable
fun ChoiceDialog(title: String, options: List<Pair<String, String>>, selected: String, onPick: (String) -> Unit, onClose: () -> Unit) {
    AlertDialog(
        onDismissRequest = onClose,
        title = { Text(title) },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState())) {
                options.forEach { (value, label) ->
                    Row(
                        Modifier.fillMaxWidth().clickable {
                            onPick(value)
                            onClose()
                        }.padding(vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        RadioButton(selected = value == selected, onClick = {
                            onPick(value)
                            onClose()
                        }, colors = RadioButtonDefaults.colors(selectedColor = Palette.green))
                        Text(label, fontSize = 15.sp)
                    }
                    HorizontalDivider(color = Palette.border.copy(alpha = 0.5f))
                }
            }
        },
        confirmButton = { TextButton(onClick = onClose) { Text(t("Done")) } },
    )
}
