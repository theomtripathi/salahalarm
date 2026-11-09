package com.salahalarm.core

import java.time.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class ChallengeTest {
    private val full = DailyPrayerLog(fajr = true, dhuhr = true, asr = true, maghrib = true, isha = true)
    private fun key(day: Int) = DateKeys.of(RamadanChallenge.startDate.plusDays((day - 1).toLong()))

    @Test fun datesMatchIos() {
        assertEquals(1, RamadanChallenge.dayNumber(LocalDate.of(2026, 11, 10)))
        assertEquals(90, RamadanChallenge.dayNumber(LocalDate.of(2027, 2, 7)))
        assertEquals(8, RamadanChallenge.daysUntilStart(LocalDate.of(2026, 11, 2)))
        assertEquals(98, RamadanChallenge.daysUntilRamadan(LocalDate.of(2026, 11, 2)))
        assertEquals(1, RamadanChallenge.phase(30))
        assertEquals(2, RamadanChallenge.phase(31))
        assertEquals(3, RamadanChallenge.phase(90))
    }

    @Test fun beforeDayOneNothingCounts() {
        val p = ChallengeProgress.compute(ChallengeEnrollment(LocalDate.of(2026, 11, 2), "ABC234"), emptyMap(), LocalDate.of(2026, 11, 5))
        assertEquals(0, p.day)
        assertTrue(p.isOnTrack)
    }

    @Test fun countsFullDaysAndGraceAndSkipsDaysBeforeJoining() {
        val logs = mapOf(key(5) to full, key(6) to full, key(8) to full)
        // Joined on day 5; today is day 8 and done; day 7 was missed.
        val joined = RamadanChallenge.startDate.plusDays(4)
        val p = ChallengeProgress.compute(ChallengeEnrollment(joined, "ABC234"), logs, RamadanChallenge.startDate.plusDays(7))
        assertEquals(8, p.day)
        assertEquals(3, p.completedDays)
        assertEquals(1, p.missedDays)
        assertEquals(2, p.graceLeftThisPhase)
        assertTrue(p.todayComplete)
        assertTrue(p.isOnTrack)
    }

    @Test fun todayInProgressIsNotAMiss() {
        val p = ChallengeProgress.compute(ChallengeEnrollment(RamadanChallenge.startDate, "ABC234"), emptyMap(), RamadanChallenge.startDate)
        assertEquals(0, p.missedDays)
        assertFalse(p.todayComplete)
    }

    @Test fun fourMissesInAPhaseIsOffTrack() {
        val p = ChallengeProgress.compute(ChallengeEnrollment(RamadanChallenge.startDate, "ABC234"), emptyMap(), RamadanChallenge.startDate.plusDays(4))
        assertEquals(4, p.missedDays)
        assertFalse(p.isOnTrack)
        assertEquals(0, p.graceLeftThisPhase)
    }

    @Test fun inviteCodesAndLinks() {
        assertEquals("ABC234", ChallengeInvite.normalize(" abc234 "))
        assertNull(ChallengeInvite.normalize("ABC10I"))
        assertTrue(ChallengeInvite.random().matches(Regex("[ABCDEFGHJKMNPQRSTUVWXYZ2-9]{6}")))
        assertEquals(ChallengeInvite.Link.Invite("ABC234"), ChallengeInvite.parse("https", "salahalarm.com", listOf("c", "abc234")))
        assertEquals(ChallengeInvite.Link.Invite("ABC234"), ChallengeInvite.parse("salahalarm", "c", listOf("ABC234")))
        assertEquals(ChallengeInvite.Link.OpenInvite, ChallengeInvite.parse("https", "salahalarm.com", listOf("c", "invite")))
        assertNull(ChallengeInvite.parse("https", "salahalarm.com", listOf("go", "ig1")))
    }

    @Test fun makkahDrawEntries() {
        assertEquals(0, RamadanChallenge.dayEntries(29))
        assertEquals(1, RamadanChallenge.dayEntries(30))
        assertEquals(2, RamadanChallenge.dayEntries(60))
        assertEquals(3, RamadanChallenge.dayEntries(90))
        assertEquals(0, RamadanChallenge.totalEntries(29, 10)) // friends wait for your own first entry
        assertEquals(11, RamadanChallenge.totalEntries(30, 10))
        assertEquals(53, RamadanChallenge.totalEntries(90, 80)) // friend entries capped at 50
        assertTrue(RamadanChallenge.joiningOpen(LocalDate.of(2027, 1, 9)))
        assertFalse(RamadanChallenge.joiningOpen(LocalDate.of(2027, 1, 10)))
    }
}
