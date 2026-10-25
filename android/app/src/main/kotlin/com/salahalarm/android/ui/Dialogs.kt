package com.salahalarm.android.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.salahalarm.android.Graph
import com.salahalarm.android.t
import com.salahalarm.android.tf
import com.salahalarm.core.ConfirmationVerse
import com.salahalarm.core.PrayerName

/** "Did you pray Asr?" with the verse of the day. Port of iOS SLPrayerConfirmationSheet. */
@Composable
fun ConfirmPrayerDialog(prayer: PrayerName, onConfirm: () -> Unit, onDismiss: () -> Unit) {
    val verse = ConfirmationVerse.forDay(Graph.repo.today())
    Dialog(onDismissRequest = onDismiss) {
        Column(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(24.dp)).background(Color.White).padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            Box(Modifier.size(48.dp).clip(CircleShape).background(Palette.green), contentAlignment = Alignment.Center) {
                Icon(Icons.Filled.Lock, contentDescription = null, tint = Color.White, modifier = Modifier.size(22.dp))
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(tf("Did you pray %@?", t(prayer.displayName)), fontSize = 20.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
                Text(prayer.arabicName, fontSize = 16.sp, fontWeight = FontWeight.Medium, color = Palette.gold)
            }
            Column(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Palette.cream).padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Text("“${t(verse.quote)}”", fontSize = 15.sp, fontStyle = FontStyle.Italic, color = Palette.textPrimary)
                Text(verse.attribution, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Palette.gold)
            }
            PrimaryButton(t("i prayed 🤲"), onClick = onConfirm)
            SecondaryButton(t("not yet"), onClick = onDismiss)
        }
    }
}
