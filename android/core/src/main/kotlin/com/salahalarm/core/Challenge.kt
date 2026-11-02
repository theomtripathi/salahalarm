package com.salahalarm.core

import java.time.LocalDate
import java.time.temporal.ChronoUnit
import kotlin.random.Random

/**
 * The 90-Day Ramadan Ready challenge (#ImRamadanReady), ported from iOS
 * RamadanChallenge.swift: one shared cohort from 10 Nov 2026 to 7 Feb 2027.
 * Progress comes from the existing daily prayer log.
 */
object RamadanChallenge {
    const val LENGTH_DAYS = 90
    const val PHASE_LENGTH = 30
    const val GRACE_DAYS_PER_PHASE = 3
    const val HASHTAG = "#ImRamadanReady"
    const val INVITE_BASE = "https://salahalarm.com/c/"
    const val LANDING_URL = "https://salahalarm.com/ramadan-2027"
    const val RULES_URL = "https://salahalarm.com/ramadan-2027/rules"

    val startDate: LocalDate = LocalDate.of(2026, 11, 10)
    val expectedRamadanStart: LocalDate = LocalDate.of(2027, 2, 8)

    /** 1-based challenge day: 0 or less before Day 1, above 90 after the end. */
    fun dayNumber(on: LocalDate): Int = ChronoUnit.DAYS.between(startDate, on).toInt() + 1
    fun daysUntilStart(from: LocalDate): Int = maxOf(0, ChronoUnit.DAYS.between(from, startDate).toInt())
    fun daysUntilRamadan(from: LocalDate): Int = maxOf(0, ChronoUnit.DAYS.between(from, expectedRamadanStart).toInt())
    fun phase(day: Int): Int = minOf(3, maxOf(1, (day - 1) / PHASE_LENGTH + 1))
    fun phaseTitle(phase: Int): String = when (phase) {
        1 -> "Phase 1: Fajr foundation"
        2 -> "Phase 2: Five a day"
        else -> "Phase 3: Sha'ban training"
    }
    fun inviteUrl(code: String) = INVITE_BASE + code
}

data class ChallengeEnrollment(val joinedAt: LocalDate, val code: String, val invitedBy: String? = null)

enum class ChallengeTier(val title: String) {
    NONE("Getting started"), BRONZE("Bronze"), SILVER("Silver"), RAMADAN_READY("Ramadan Ready"),
}

data class ChallengeProgress(
    /** Current challenge day, clamped to 0..90 (0 = not started yet). */
    val day: Int,
    val completedDays: Int,
    val missedDays: Int,
    val phase: Int,
    val graceLeftThisPhase: Int,
    val isOnTrack: Boolean,
    val todayComplete: Boolean,
) {
    val tier: ChallengeTier
        get() {
            if (day >= RamadanChallenge.LENGTH_DAYS && isOnTrack) return ChallengeTier.RAMADAN_READY
            val counted = completedDays + missedDays
            if (counted >= 30 && completedDays >= counted * 0.8) return ChallengeTier.SILVER
            if (completedDays >= 30) return ChallengeTier.BRONZE
            return ChallengeTier.NONE
        }

    companion object {
        /** A day counts when all five prayers were confirmed. Days before joining don't count against anyone. */
        fun compute(enrollment: ChallengeEnrollment, logs: Map<String, DailyPrayerLog>, today: LocalDate): ChallengeProgress {
            val todayNumber = RamadanChallenge.dayNumber(today)
            val clamped = todayNumber.coerceIn(0, RamadanChallenge.LENGTH_DAYS)
            if (clamped < 1) return ChallengeProgress(0, 0, 0, 1, RamadanChallenge.GRACE_DAYS_PER_PHASE, true, false)

            val first = maxOf(1, RamadanChallenge.dayNumber(enrollment.joinedAt))
            var completed = 0
            var missed = 0
            val missedByPhase = IntArray(4)
            var todayComplete = false
            for (n in first..clamped) {
                val date = RamadanChallenge.startDate.plusDays((n - 1).toLong())
                val done = logs[DateKeys.of(date)]?.allFivePrayed == true
                val isToday = n == todayNumber
                if (done) {
                    completed++
                    if (isToday) todayComplete = true
                } else if (!isToday) {
                    missed++
                    missedByPhase[RamadanChallenge.phase(n)]++
                }
            }
            val phase = RamadanChallenge.phase(clamped)
            val onTrack = missedByPhase.all { it <= RamadanChallenge.GRACE_DAYS_PER_PHASE }
            val graceLeft = maxOf(0, RamadanChallenge.GRACE_DAYS_PER_PHASE - missedByPhase[phase])
            return ChallengeProgress(clamped, completed, missed, phase, graceLeft, onTrack, todayComplete)
        }
    }
}

/** Invite codes, the same format as iOS ChallengeInvite and the website. */
object ChallengeInvite {
    const val CODE_LENGTH = 6
    private const val ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"

    fun normalize(raw: String?): String? {
        val code = raw?.trim()?.uppercase() ?: return null
        return code.takeIf { it.length == CODE_LENGTH && it.all { c -> c in ALPHABET } }
    }

    fun random(rng: Random = Random.Default): String = (1..CODE_LENGTH).map { ALPHABET[rng.nextInt(ALPHABET.length)] }.joinToString("")

    /** What a challenge link asks for: an invite code, the invite screen, or just the challenge. */
    sealed interface Link {
        data class Invite(val code: String) : Link
        data object OpenInvite : Link
        data object Join : Link
    }

    /** Reads https://salahalarm.com/c/CODE or salahalarm://c/CODE (scheme, host, path segments). */
    fun parse(scheme: String?, host: String?, segments: List<String>): Link? {
        val parts = if (scheme == "salahalarm" && host != null) listOf(host) + segments else segments
        val i = parts.indexOfFirst { it.equals("c", ignoreCase = true) }
        if (i < 0 || i + 1 >= parts.size) return null
        val target = parts[i + 1]
        return when (target.lowercase()) {
            "invite" -> Link.OpenInvite
            "join" -> Link.Join
            else -> normalize(target)?.let { Link.Invite(it) }
        }
    }
}
