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
import com.salahalarm.core.Entitlement
import kotlinx.coroutines.launch

/**
 * Shown over the app once the free trial from salahalarm.com has run out.
 * Plans are sold on the website, so the first time this appears it opens the
 * paywall there; the buttons below take the user back to it or re-check after paying.
 */
@Composable
fun TrialEndedScreen(entitlement: Entitlement, onContinueFree: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var checking by remember { mutableStateOf(false) }
    var notFound by remember { mutableStateOf(false) }
    val openPaywall = { source: String ->
        Analytics.capture("android_trial_ended_paywall_opened", mapOf("source" to source))
        openUrl(context, Api.paywallUrl(source))
    }

    LaunchedEffect(entitlement.accessUntil) {
        Analytics.capture("android_trial_ended_viewed")
        val key = "trial_end_redirect_${entitlement.accessUntil?.epochSecond}"
        if (!Graph.store.flag(key)) {
            Graph.store.setFlag(key)
            openPaywall("trial_ended_auto")
        }
    }

    Column(
        Modifier.fillMaxSize().systemBarsPadding().verticalScroll(rememberScrollState()).padding(horizontal = 24.dp, vertical = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text("🌙", fontSize = 56.sp)
        Spacer(Modifier.height(16.dp))
        Text(t("Your free trial has ended"), fontSize = 26.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
        Spacer(Modifier.height(10.dp))
        Secondary(
            t("We hope SalahAlarm helped you pray on time. Choose a plan on salahalarm.com to keep your prayer alarms ringing, with the same account."),
            size = 16, align = TextAlign.Center,
        )
        Spacer(Modifier.height(28.dp))
        PrimaryButton(t("Choose a plan")) { openPaywall("trial_ended") }
        Spacer(Modifier.height(10.dp))
        SecondaryButton(t("I've already paid")) {
            scope.launch {
                checking = true
                notFound = !Graph.repo.refreshEntitlement(force = true)
                checking = false
            }
        }
        if (checking) {
            Spacer(Modifier.height(12.dp))
            CircularProgressIndicator(color = Palette.green)
        }
        if (notFound) {
            Spacer(Modifier.height(12.dp))
            Secondary(t("No active subscription was found for this account. Sign in with the account you paid with."), align = TextAlign.Center)
        }
        Spacer(Modifier.height(8.dp))
        TextButton(onClick = onContinueFree) {
            Text(t("Continue without alarms"), color = Palette.textSecondary)
        }
    }
}
