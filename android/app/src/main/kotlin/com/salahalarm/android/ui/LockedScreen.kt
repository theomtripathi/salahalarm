package com.salahalarm.android.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.salahalarm.android.Graph
import com.salahalarm.android.data.Analytics
import com.salahalarm.android.data.Api
import com.salahalarm.android.t
import kotlinx.coroutines.launch

/**
 * Shown instead of the app to a signed-in account without a plan: the free
 * trial ran out, or they never paid (someone shared the APK). Plans are sold on
 * salahalarm.com, so the only way forward is the website; the page opens once by
 * itself, and "I've already paid" re-checks the account.
 */
@Composable
fun LockedScreen() {
    val context = LocalContext.current
    val repo = Graph.repo
    val scope = rememberCoroutineScope()
    val entitlement by repo.entitlement.collectAsState()
    var checking by remember { mutableStateOf(false) }
    var notFound by remember { mutableStateOf(false) }
    val unchecked = entitlement.checkedAt == null
    val trialEnded = entitlement.isTrial
    val source = if (trialEnded) "trial_ended" else "no_plan"

    // Right after sign-in nothing is known yet: ask the server before deciding.
    LaunchedEffect(unchecked) {
        if (unchecked) {
            checking = true
            repo.refreshEntitlement(force = true)
            checking = false
        }
    }

    LaunchedEffect(unchecked, entitlement.accessUntil) {
        if (unchecked) return@LaunchedEffect
        Analytics.capture("android_locked_viewed", mapOf("reason" to source))
        val key = "locked_redirect_${source}_${entitlement.accessUntil?.epochSecond}"
        if (!Graph.store.flag(key)) {
            Graph.store.setFlag(key)
            openUrl(context, Api.paywallUrl(source))
        }
    }

    Column(
        Modifier.fillMaxSize().systemBarsPadding().verticalScroll(rememberScrollState()).padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Spacer(Modifier.height(40.dp))
        Text("🌙", fontSize = 56.sp)
        if (unchecked) {
            Text(t("Checking your plan…"), fontSize = 22.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
            if (checking) {
                CircularProgressIndicator(color = Palette.green)
            } else {
                Secondary(t("Couldn't reach salahalarm.com. Check your internet connection."), align = TextAlign.Center)
                PrimaryButton(t("Try again")) {
                    scope.launch {
                        checking = true
                        repo.refreshEntitlement(force = true)
                        checking = false
                    }
                }
            }
        } else {
            if (trialEnded) {
                Text(t("Your free trial has ended"), fontSize = 26.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
                Secondary(t("We hope SalahAlarm helped you pray on time. Pick a plan on salahalarm.com to keep your alarms ringing for every prayer."), align = TextAlign.Center)
            } else {
                Text(t("Choose a plan to start"), fontSize = 26.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
                Secondary(t("This account doesn't have a SalahAlarm plan yet. Pick one on salahalarm.com and your alarms start ringing for every prayer."), align = TextAlign.Center)
            }
            Spacer(Modifier.height(8.dp))
            PrimaryButton(t("Choose a plan")) {
                Analytics.capture("android_locked_choose_plan", mapOf("reason" to source))
                openUrl(context, Api.paywallUrl(source))
            }
            SecondaryButton(t("I've already paid")) {
                scope.launch {
                    checking = true
                    notFound = !repo.refreshEntitlement(force = true)
                    checking = false
                }
            }
            if (checking) CircularProgressIndicator(color = Palette.green)
            if (notFound) {
                Text(
                    t("No active subscription was found for this account. Sign in with the account you paid with."),
                    color = Palette.alarmRed, fontSize = 14.sp, textAlign = TextAlign.Center,
                )
            }
        }
        repo.user.value?.email?.let { Secondary(it, align = TextAlign.Center) }
        TextButton(onClick = { repo.signOut() }) { Text(t("Sign Out"), color = Palette.green) }
    }
}
