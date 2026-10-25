package com.salahalarm.core

import java.time.Duration
import java.time.Instant

/** Raw values match iOS `AlarmSoundOption`, which is what Firestore and the web funnel store. */
enum class AlarmSound(val raw: String, val displayName: String, val shortLabel: String, val asset: String) {
    MAKKAH("Makkah Adhan Loud", "Makkah Adhan", "Makkah", "alarm_makkah_loud"),
    MADINAH("Madinah Adhan Loud", "Madinah Adhan", "Madinah", "alarm_madinah_loud"),
    FAJR("Fajr Adhan Loud", "Fajr Adhan", "Fajr", "alarm_fajr_loud"),
    TAKBIR("Takbir Alarm Loud", "Takbir Alarm", "Takbir", "alarm_takbir_loud"),
    WAKE_UP("Funny Wake Up Bitch", "Wake-Up Alarm", "Wake-Up", "wake_up"),
    CUSTOM("Custom Audio", "Custom Audio", "Custom", "custom");

    companion object {
        fun fromRaw(raw: String?): AlarmSound = entries.firstOrNull { it.raw == raw } ?: MAKKAH
    }
}

enum class AlarmStrictness(val raw: String, val displayLabel: String, val detailText: String, val homeDescription: String) {
    STRICT(
        "strict", "Strict",
        "Rings until you dismiss it from the prayer flow.",
        "Strict mode - scan your prayer mat to dismiss",
    ),
    MODERATE(
        "moderate", "Moderate",
        "Lets the alarm expire after 10 minutes if you miss it.",
        "Moderate mode - auto-marks missed after 10 minutes",
    ),
    RELAXED(
        "relaxed", "Relaxed",
        "Allows one snooze before asking you to dismiss it.",
        "Relaxed mode - one snooze before scan is required",
    );

    val allowsManualDismiss: Boolean get() = this != STRICT
    val autoMissAfter: Duration? get() = if (this == MODERATE) Duration.ofMinutes(10) else null
    val snoozesAllowed: Int get() = if (this == RELAXED) 1 else 0

    companion object {
        fun fromRaw(raw: String?): AlarmStrictness = entries.firstOrNull { it.raw == raw } ?: STRICT
    }
}

data class AlarmSettings(
    val enabledPrayers: Set<PrayerName> = PrayerName.entries.toSet(),
    val strictness: AlarmStrictness = AlarmStrictness.STRICT,
    val sound: AlarmSound = AlarmSound.MAKKAH,
    val volume: Float = 1f,
    val vibrationEnabled: Boolean = true,
    val alarmsEnabled: Boolean = true,
    val matSetupCompleted: Boolean = false,
) {
    fun isEnabled(prayer: PrayerName) = prayer in enabledPrayers

    fun withPrayer(prayer: PrayerName, enabled: Boolean) =
        copy(enabledPrayers = if (enabled) enabledPrayers + prayer else enabledPrayers - prayer)

    companion object {
        /** Settings from the onboarding answers the web funnel saved in users/{uid}.onboardingProfile. */
        fun fromOnboarding(profile: Map<String, Any?>): AlarmSettings {
            val prayers = (profile["selectedAlarmPrayers"] as? List<*>)
                ?.mapNotNull { PrayerName.fromId(it as? String) }?.toSet()
                .orEmpty()
            return AlarmSettings(
                enabledPrayers = prayers.ifEmpty { PrayerName.entries.toSet() },
                strictness = AlarmStrictness.fromRaw(profile["alarmStrictness"] as? String),
                sound = AlarmSound.fromRaw(profile["alarmSoundName"] as? String),
                alarmsEnabled = true,
                matSetupCompleted = profile["matSetupCompleted"] as? Boolean ?: false,
            )
        }
    }
}

data class PlannedAlarm(val prayer: PrayerName, val time: Instant) {
    /** Stable per prayer and day, so rescheduling replaces rather than duplicates. */
    val requestCode: Int get() = (time.epochSecond / 60).toInt() * 8 + prayer.ordinal
    val id: String get() = "${prayer.id}-${time.epochSecond}"
}

object AlarmPlanner {
    /** Every enabled alarm still ahead of [now], in time order, across the given days. */
    fun upcoming(schedules: List<PrayerSchedule>, settings: AlarmSettings, now: Instant): List<PlannedAlarm> {
        if (!settings.alarmsEnabled) return emptyList()
        return schedules.flatMap { it.prayers }
            .filter { (prayer, time) -> settings.isEnabled(prayer) && time > now }
            .sortedBy { it.second }
            .map { (prayer, time) -> PlannedAlarm(prayer, time) }
    }

    fun next(schedules: List<PrayerSchedule>, settings: AlarmSettings, now: Instant): PlannedAlarm? =
        upcoming(schedules, settings, now).firstOrNull()

    /** iOS formats: "in 2h 5m" and "in 12m". */
    fun relativeCountdown(to: Instant, now: Instant): String {
        val secs = maxOf(0, Duration.between(now, to).seconds)
        val h = secs / 3600
        val m = (secs / 60) % 60
        return if (h > 0) "in ${h}h ${m}m" else "in ${m}m"
    }

    fun clock(to: Instant, now: Instant): String {
        val secs = maxOf(0, Duration.between(now, to).seconds)
        return "%02d:%02d:%02d".format(secs / 3600, (secs / 60) % 60, secs % 60)
    }
}
