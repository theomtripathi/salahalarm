package com.salahalarm.android.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.State
import androidx.compose.runtime.produceState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.salahalarm.android.I18n
import com.salahalarm.android.t
import kotlinx.coroutines.delay
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/** The iOS SalahLock palette (AppColors.swift). */
object Palette {
    val green = Color(0xFF1A9E3F)
    val deepGreen = Color(0xFF157832)
    val gold = Color(0xFFC9A028)
    val cream = Color(0xFFF9F7F2)
    val textPrimary = Color(0xFF111111)
    val textSecondary = Color(0xFF666666)
    val border = Color(0xFFE0E0E0)
    val tabUnselected = Color(0xFF999999)
    val alarmRed = Color(0xFFE53935)
    val alarmRedDark = Color(0xFFB71C1C)
    val alarmRedLight = Color(0xFFFFEBEE)
    val warningBg = Color(0xFFFFF8E7)
}

@Composable
fun SalahTheme(content: @Composable () -> Unit) {
    val colors = lightColorScheme(
        primary = Palette.green,
        onPrimary = Color.White,
        secondary = Palette.gold,
        background = Palette.cream,
        surface = Color.White,
        onSurface = Palette.textPrimary,
        onBackground = Palette.textPrimary,
        error = Palette.alarmRed,
    )
    MaterialTheme(colorScheme = colors) {
        CompositionLocalProvider(LocalLayoutDirection provides if (I18n.isRtl) LayoutDirection.Rtl else LayoutDirection.Ltr) {
            content()
        }
    }
}

/** Ticks every [periodMs], for countdowns and day rollover. */
@Composable
fun rememberNow(periodMs: Long = 1000): State<Instant> = produceState(Instant.now()) {
    while (true) {
        delay(periodMs - System.currentTimeMillis() % periodMs)
        value = Instant.now()
    }
}

fun timeString(instant: Instant?): String {
    if (instant == null) return "--"
    return DateTimeFormatter.ofPattern("h:mm a", I18n.locale).format(instant.atZone(ZoneId.systemDefault()))
}

@Composable
fun SLCard(modifier: Modifier = Modifier, padding: Int = 20, content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier
            .fillMaxWidth()
            .shadow(6.dp, RoundedCornerShape(16.dp), ambientColor = Color(0x14000000), spotColor = Color(0x14000000))
            .clip(RoundedCornerShape(16.dp))
            .background(Color.White)
            .padding(padding.dp),
        content = content,
    )
}

@Composable
fun PrimaryButton(text: String, modifier: Modifier = Modifier, enabled: Boolean = true, color: Color = Palette.green, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier.fillMaxWidth().heightIn(min = 54.dp),
        shape = RoundedCornerShape(14.dp),
        colors = ButtonDefaults.buttonColors(containerColor = color, contentColor = Color.White),
    ) {
        Text(text, fontSize = 17.sp, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center)
    }
}

@Composable
fun SecondaryButton(text: String, modifier: Modifier = Modifier, onClick: () -> Unit) {
    OutlinedButton(
        onClick = onClick,
        modifier = modifier.fillMaxWidth().heightIn(min = 50.dp),
        shape = RoundedCornerShape(14.dp),
        border = BorderStroke(1.5.dp, Palette.border),
        colors = ButtonDefaults.outlinedButtonColors(contentColor = Palette.textPrimary),
    ) {
        Text(text, fontSize = 16.sp, fontWeight = FontWeight.Medium, textAlign = TextAlign.Center)
    }
}

/** A selectable pill, used where iOS has segmented pickers. */
@Composable
fun Pill(text: String, selected: Boolean, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Box(
        modifier
            .clip(RoundedCornerShape(10.dp))
            .background(if (selected) Palette.green else Palette.cream)
            .border(1.dp, if (selected) Palette.green else Palette.border, RoundedCornerShape(10.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 10.dp, vertical = 9.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text,
            color = if (selected) Color.White else Palette.textPrimary,
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            maxLines = 1,
            textAlign = TextAlign.Center,
        )
    }
}

@Composable
fun PillRow(options: List<Pair<String, String>>, selected: String, onSelect: (String) -> Unit) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        options.forEach { (value, label) ->
            Pill(label, value == selected, Modifier.weight(1f)) { onSelect(value) }
        }
    }
}

@Composable
fun SectionTitle(text: String, modifier: Modifier = Modifier) {
    Text(text, modifier = modifier, fontSize = 18.sp, fontWeight = FontWeight.Bold, color = Palette.textPrimary)
}

@Composable
fun Secondary(text: String, modifier: Modifier = Modifier, size: Int = 14, align: TextAlign? = null) {
    Text(text, modifier = modifier, fontSize = size.sp, color = Palette.textSecondary, textAlign = align)
}

@Composable
fun StreakBadge(streak: Int, active: Boolean) {
    Surface(
        shape = RoundedCornerShape(50),
        color = if (active) Palette.gold.copy(alpha = 0.14f) else Palette.border.copy(alpha = 0.5f),
    ) {
        Text(
            "🔥 $streak",
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
            fontWeight = FontWeight.Bold,
            color = if (active) Palette.gold else Palette.textSecondary,
            fontSize = 14.sp,
        )
    }
}

@Composable
fun Avatar(initials: String, size: Int = 38, filled: Boolean = false, onClick: (() -> Unit)? = null) {
    Box(
        Modifier
            .size(size.dp)
            .clip(CircleShape)
            .background(if (filled) Palette.green else Palette.green.copy(alpha = 0.16f))
            .let { if (onClick != null) it.clickable(onClick = onClick) else it },
        contentAlignment = Alignment.Center,
    ) {
        Text(initials, color = if (filled) Color.White else Palette.green, fontWeight = FontWeight.Bold, fontSize = (size * 0.37).sp)
    }
}

@Composable
fun ScreenColumn(content: @Composable ColumnScope.() -> Unit) {
    Column(
        Modifier.fillMaxWidth().padding(PaddingValues(horizontal = 20.dp, vertical = 12.dp)),
        verticalArrangement = Arrangement.spacedBy(18.dp),
        content = content,
    )
}

@Composable
fun RowScope.Spacer1() = androidx.compose.foundation.layout.Spacer(Modifier.weight(1f))

@Composable
fun OnceEffect(key: Any?, block: suspend () -> Unit) = LaunchedEffect(key) { block() }

fun initialsOf(name: String): String =
    name.split(" ").filter { it.isNotBlank() }.take(2).joinToString("") { it.take(1) }.uppercase().ifEmpty { "S" }

/** The account's name, else a first name read from the email ("amina.k@..." -> "Amina"), else "Friend". */
fun displayName(name: String?, email: String? = null): String {
    name?.trim()?.takeIf { it.isNotEmpty() }?.let { return it }
    val fromEmail = email?.substringBefore("@")?.split('.', '_', '-', '+')?.firstOrNull()
        ?.takeWhile { it.isLetter() }?.takeIf { it.length >= 2 }
    return fromEmail?.lowercase()?.replaceFirstChar { it.titlecase() } ?: t("Friend")
}
