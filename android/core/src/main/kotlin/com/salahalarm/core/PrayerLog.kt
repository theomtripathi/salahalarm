package com.salahalarm.core

import java.time.Instant
import java.time.LocalDate
import java.time.format.DateTimeFormatter

/** Same shape as iOS `DailyPrayerLog`, stored at users/{uid}.prayerLog.{yyyy-MM-dd}. */
data class DailyPrayerLog(
    val fajr: Boolean = false,
    val dhuhr: Boolean = false,
    val asr: Boolean = false,
    val maghrib: Boolean = false,
    val isha: Boolean = false,
    val confirmedAt: List<Instant> = emptyList(),
) {
    fun isConfirmed(prayer: PrayerName): Boolean = when (prayer) {
        PrayerName.FAJR -> fajr
        PrayerName.DHUHR -> dhuhr
        PrayerName.ASR -> asr
        PrayerName.MAGHRIB -> maghrib
        PrayerName.ISHA -> isha
    }

    val prayedCount: Int get() = PrayerName.entries.count { isConfirmed(it) }
    val allFivePrayed: Boolean get() = prayedCount == 5

    fun confirming(prayer: PrayerName, at: Instant): DailyPrayerLog {
        val marked = when (prayer) {
            PrayerName.FAJR -> copy(fajr = true)
            PrayerName.DHUHR -> copy(dhuhr = true)
            PrayerName.ASR -> copy(asr = true)
            PrayerName.MAGHRIB -> copy(maghrib = true)
            PrayerName.ISHA -> copy(isha = true)
        }
        return marked.copy(confirmedAt = confirmedAt + at)
    }

    /** Union of two copies of the same day, e.g. local and Firestore. */
    fun merged(other: DailyPrayerLog) = DailyPrayerLog(
        fajr = fajr || other.fajr,
        dhuhr = dhuhr || other.dhuhr,
        asr = asr || other.asr,
        maghrib = maghrib || other.maghrib,
        isha = isha || other.isha,
        confirmedAt = (confirmedAt + other.confirmedAt).distinct().sorted(),
    )
}

/** Same shape as iOS `StreakData`, stored at users/{uid}.streakData. */
data class StreakData(
    val currentStreak: Int = 0,
    val longestStreak: Int = 0,
    val lastStreakDate: String = "",
    val totalPrayerDays: Int = 0,
    val totalPrayersConfirmed: Int = 0,
) {
    /** Hours spent in salah, at iOS's 10 minutes per prayer. */
    val hoursInSalah: Double get() = totalPrayersConfirmed * 10 / 60.0

    /** The streak to show today: it lapses once a full day has been missed. */
    fun displayed(today: LocalDate): Int {
        if (lastStreakDate.isEmpty()) return 0
        val last = runCatching { LocalDate.parse(lastStreakDate) }.getOrNull() ?: return currentStreak
        return if (last >= today.minusDays(1)) currentStreak else 0
    }
}

object DateKeys {
    private val format = DateTimeFormatter.ofPattern("yyyy-MM-dd")
    fun of(date: LocalDate): String = date.format(format)
    fun parse(key: String): LocalDate? = runCatching { LocalDate.parse(key, format) }.getOrNull()
}

data class ConfirmResult(val log: DailyPrayerLog, val streak: StreakData, val changed: Boolean)

/** Port of iOS `PrayerLogViewModel.confirmPrayer`. */
object PrayerLogic {
    fun confirm(
        log: DailyPrayerLog,
        streak: StreakData,
        prayer: PrayerName,
        today: LocalDate,
        at: Instant,
    ): ConfirmResult {
        if (log.isConfirmed(prayer)) return ConfirmResult(log, streak, false)
        val updated = log.confirming(prayer, at)
        val todayKey = DateKeys.of(today)
        var s = streak.copy(totalPrayersConfirmed = streak.totalPrayersConfirmed + 1)
        if (updated.allFivePrayed && s.lastStreakDate != todayKey) {
            val current = if (s.lastStreakDate == DateKeys.of(today.minusDays(1))) s.currentStreak + 1 else 1
            s = s.copy(
                currentStreak = current,
                longestStreak = maxOf(s.longestStreak, current),
                lastStreakDate = todayKey,
                totalPrayerDays = s.totalPrayerDays + 1,
            )
        }
        return ConfirmResult(updated, s, true)
    }

    /** Status dot colour on the home card: confirmed, missed (time passed) or upcoming. */
    enum class Status { CONFIRMED, MISSED, UPCOMING }

    fun status(prayer: PrayerName, log: DailyPrayerLog, schedule: PrayerSchedule?, now: Instant): Status = when {
        log.isConfirmed(prayer) -> Status.CONFIRMED
        schedule != null && schedule.time(prayer) <= now -> Status.MISSED
        else -> Status.UPCOMING
    }
}

/** SalahLock rule, ported from iOS `AppLockManager.evaluate`. */
object LockPolicy {
    /**
     * The enforced prayer whose window is open (its time has come and the next
     * prayer's hasn't) and which isn't confirmed yet, or null when apps are free.
     */
    fun blockingPrayer(
        schedule: PrayerSchedule?,
        log: DailyPrayerLog,
        enforced: Set<PrayerName>,
        now: Instant,
        endOfDay: Instant,
    ): PrayerName? {
        if (schedule == null || enforced.isEmpty()) return null
        val prayers = schedule.prayers
        for ((index, entry) in prayers.withIndex()) {
            val (prayer, time) = entry
            val windowEnd = if (index + 1 < prayers.size) prayers[index + 1].second else endOfDay
            if (now < time || now >= windowEnd) continue
            return if (prayer in enforced && !log.isConfirmed(prayer)) prayer else null
        }
        return null
    }

    /** Next moment the lock state could change on its own: the next enforced prayer time. */
    fun nextLockTime(schedules: List<PrayerSchedule>, enforced: Set<PrayerName>, now: Instant): Pair<PrayerName, Instant>? =
        schedules.flatMap { it.prayers }.firstOrNull { (p, t) -> p in enforced && t > now }
}

data class ConfirmationVerse(val quote: String, val attribution: String) {
    companion object {
        val rotation = listOf(
            ConfirmationVerse("Establish prayer and give zakah, and bow with those who bow.", "Quran 2:43"),
            ConfirmationVerse("Indeed, prayer prohibits immorality and wrongdoing.", "Quran 29:45"),
            ConfirmationVerse("Seek help through patience and prayer.", "Quran 2:45"),
            ConfirmationVerse("And establish prayer for My remembrance.", "Quran 20:14"),
            ConfirmationVerse("Successful indeed are the believers, those who are humble in their prayer.", "Quran 23:1-2"),
        )

        fun forDay(date: LocalDate): ConfirmationVerse = rotation[date.dayOfYear % rotation.size]
    }
}
