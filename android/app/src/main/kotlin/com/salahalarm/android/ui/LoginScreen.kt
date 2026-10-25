package com.salahalarm.android.ui

import android.app.Activity
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.OutlinedTextField
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.credentials.exceptions.GetCredentialCancellationException
import com.salahalarm.android.Graph
import com.salahalarm.android.R
import com.salahalarm.android.data.Analytics
import com.salahalarm.android.data.Api
import com.salahalarm.android.data.ApiException
import com.salahalarm.android.t
import kotlinx.coroutines.launch

/**
 * Sign in with the account used on the website. The fastest path is the
 * "Open SalahAlarm, signed in" link on the welcome page; Google and email
 * sign-in cover everyone else.
 */
@Composable
fun LoginScreen() {
    val context = LocalContext.current
    val repo = Graph.repo
    val scope = rememberCoroutineScope()
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var showEmail by remember { mutableStateOf(false) }
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var notice by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(Unit) { Analytics.capture("android_login_viewed") }

    // A code from the welcome page link signs in without any typing.
    val code = Nav.loginCode
    LaunchedEffect(code) {
        if (code == null) return@LaunchedEffect
        busy = true
        error = try {
            repo.signInWithCode(code)
            null
        } catch (e: ApiException) {
            if (e.status == 404 || e.status == 410) t("That sign-in link has expired. Sign in below with the same account.") else t("Could not sign in. Check your connection and try again.")
        } catch (e: Exception) {
            t("Could not sign in. Check your connection and try again.")
        }
        Nav.loginCode = null
        busy = false
    }

    fun run(block: suspend () -> Unit) {
        scope.launch {
            busy = true
            error = null
            try {
                block()
            } catch (e: GetCredentialCancellationException) {
                // Closed the Google sheet.
            } catch (e: Exception) {
                error = friendly(e)
            }
            busy = false
        }
    }

    Box(Modifier.fillMaxSize().systemBarsPadding().imePadding()) {
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Spacer(Modifier.height(24.dp))
            Image(painterResource(R.drawable.logo), contentDescription = null, modifier = Modifier.size(84.dp).clip(RoundedCornerShape(20.dp)))
            Text(t("Welcome to SalahAlarm"), fontSize = 26.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
            Secondary(t("Sign in with the account you used on salahalarm.com."), align = TextAlign.Center)
            Spacer(Modifier.height(8.dp))

            PrimaryButton(t("Continue with Google"), enabled = !busy) {
                run { repo.signInWithGoogle(context as Activity) }
            }
            if (!showEmail) {
                SecondaryButton(t("Sign in with email")) { showEmail = true }
            } else {
                OutlinedTextField(
                    value = email, onValueChange = { email = it }, singleLine = true, label = { Text(t("Email")) },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email), modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = password, onValueChange = { password = it }, singleLine = true, label = { Text(t("Password")) },
                    visualTransformation = PasswordVisualTransformation(),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password), modifier = Modifier.fillMaxWidth(),
                )
                PrimaryButton(t("sign in"), enabled = !busy && email.isNotBlank() && password.isNotBlank()) {
                    run { repo.signInWithEmail(email, password) }
                }
                TextButton(onClick = {
                    if (email.isBlank()) {
                        error = t("Please enter a valid email address.")
                    } else {
                        run {
                            repo.sendPasswordReset(email)
                            notice = t("Check your email for a link to reset your password.")
                        }
                    }
                }) { Text(t("Forgot password?"), color = Palette.green) }
            }

            if (busy) CircularProgressIndicator(color = Palette.green)
            error?.let { Text(it, color = Palette.alarmRed, fontSize = 14.sp, textAlign = TextAlign.Center) }
            notice?.let { Text(it, color = Palette.green, fontSize = 14.sp, textAlign = TextAlign.Center) }

            Spacer(Modifier.height(16.dp))
            Secondary(t("New to SalahAlarm?"), size = 13)
            TextButton(onClick = { openUrl(context, Api.paywallUrl("app_login").replace("?resume=paywall&", "?")) }) {
                Text(t("Get started on salahalarm.com"), color = Palette.green, fontWeight = FontWeight.SemiBold)
            }
        }
    }
}

private fun friendly(e: Exception): String {
    val msg = e.message.orEmpty()
    return when {
        "INVALID_LOGIN_CREDENTIALS" in msg || "password is invalid" in msg || "no user record" in msg ->
            t("That email and password don't match. Try again or reset your password.")
        "network" in msg.lowercase() -> t("Could not sign in. Check your connection and try again.")
        e is androidx.credentials.exceptions.GetCredentialException ->
            t("Google sign-in isn't available right now. Use the link on the website or sign in with email.")
        else -> t("Could not sign in. Check your connection and try again.")
    }
}
