package com.salahalarm.core

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class PrayerCalculatorTest {
    private val karachi = GeoPoint(24.8607, 67.0011)
    private val zone = ZoneId.of("Asia/Karachi")

    @Test fun countryDefaultsMatchTheWebFunnel() {
        assertEquals("Karachi", PrayerCalculator.methodFor("pk"))
        assertEquals("UmmAlQura", PrayerCalculator.methodFor("SA"))
        assertEquals("Turkey", PrayerCalculator.methodFor("TR"))
        assertEquals("MuslimWorldLeague", PrayerCalculator.methodFor("FR"))
        assertEquals("MuslimWorldLeague", PrayerCalculator.methodFor(null))
        assertTrue(PrayerCalculator.hanafiFor("PK"))
        assertFalse(PrayerCalculator.hanafiFor("ID"))
    }

    @Test fun karachiTimesAreInOrderAndPlausible() {
        val s = PrayerCalculator.schedule(karachi, LocalDate.of(2026, 10, 25), "Karachi", true)
        val times = listOf(s.fajr, s.sunrise, s.dhuhr, s.asr, s.maghrib, s.isha)
        assertEquals(times.sorted(), times)
        val fajr = s.fajr.atZone(zone).toLocalTime()
        val maghrib = s.maghrib.atZone(zone).toLocalTime()
        assertTrue(fajr.hour == 5, "fajr $fajr")
        assertTrue(maghrib.hour == 17 || maghrib.hour == 18, "maghrib $maghrib")
    }

    @Test fun customMethodsCompute() {
        for (m in PrayerCalculator.methods) {
            val s = PrayerCalculator.schedule(GeoPoint(41.0082, 28.9784), LocalDate.of(2026, 6, 1), m, false)
            assertTrue(s.fajr < s.isha, m)
        }
    }

    @Test fun nextPrayerRollsIntoTomorrow() {
        val days = PrayerCalculator.schedules(karachi, LocalDate.of(2026, 10, 25), 2, "Karachi", true)
        val afterIsha = days[0].isha.plusSeconds(60)
        val next = PrayerCalculator.nextPrayer(days, afterIsha)!!
        assertEquals(PrayerName.FAJR, next.first)
        assertEquals(days[1].fajr, next.second)
    }

    @Test fun qiblaFromLondonPointsSouthEast() {
        val bearing = QiblaMath.bearing(GeoPoint(51.5074, -0.1278))
        assertTrue(bearing in 118.0..120.5, "bearing $bearing")
        assertEquals(-10.0, QiblaMath.turn(130.0, 120.0), 1e-9)
        assertEquals(20.0, QiblaMath.turn(350.0, 10.0), 1e-9)
        assertTrue(QiblaMath.distanceKm(GeoPoint(24.8607, 67.0011)) in 2800.0..3000.0)
    }
}

class PrayerLogTest {
    private val today = LocalDate.of(2026, 10, 25)
    private val at = Instant.parse("2026-10-25T12:00:00Z")

    private fun allFive(log: DailyPrayerLog, streak: StreakData): ConfirmResult {
        var r = ConfirmResult(log, streak, false)
        for (p in PrayerName.entries) r = PrayerLogic.confirm(r.log, r.streak, p, today, at)
        return r
    }

    @Test fun confirmingTwiceDoesNothing() {
        val first = PrayerLogic.confirm(DailyPrayerLog(), StreakData(), PrayerName.FAJR, today, at)
        val second = PrayerLogic.confirm(first.log, first.streak, PrayerName.FAJR, today, at)
        assertFalse(second.changed)
        assertEquals(1, second.streak.totalPrayersConfirmed)
        assertEquals(1, second.log.confirmedAt.size)
    }

    @Test fun streakContinuesFromYesterday() {
        val r = allFive(DailyPrayerLog(), StreakData(currentStreak = 4, longestStreak = 4, lastStreakDate = "2026-10-24", totalPrayerDays = 4))
        assertEquals(5, r.streak.currentStreak)
        assertEquals(5, r.streak.longestStreak)
        assertEquals("2026-10-25", r.streak.lastStreakDate)
        assertEquals(5, r.streak.totalPrayerDays)
        assertEquals(5, r.streak.totalPrayersConfirmed)
    }

    @Test fun streakRestartsAfterAGap() {
        val r = allFive(DailyPrayerLog(), StreakData(currentStreak = 9, longestStreak = 9, lastStreakDate = "2026-10-20"))
        assertEquals(1, r.streak.currentStreak)
        assertEquals(9, r.streak.longestStreak)
    }

    @Test fun displayedStreakLapsesAfterAMissedDay() {
        val s = StreakData(currentStreak = 3, lastStreakDate = "2026-10-24")
        assertEquals(3, s.displayed(today))
        assertEquals(0, s.displayed(today.plusDays(2)))
    }

    @Test fun mergeIsAUnion() {
        val a = DailyPrayerLog(fajr = true, confirmedAt = listOf(at))
        val b = DailyPrayerLog(isha = true, confirmedAt = listOf(at, at.plusSeconds(5)))
        val m = a.merged(b)
        assertEquals(2, m.prayedCount)
        assertEquals(2, m.confirmedAt.size)
    }
}

class LockPolicyTest {
    private val schedule = PrayerCalculator.schedule(GeoPoint(24.86, 67.0), LocalDate.of(2026, 10, 25), "Karachi", true)
    private val endOfDay = Instant.parse("2026-10-25T18:59:59Z")

    @Test fun locksDuringAnUnconfirmedEnforcedWindow() {
        val now = schedule.asr.plusSeconds(60)
        assertEquals(PrayerName.ASR, LockPolicy.blockingPrayer(schedule, DailyPrayerLog(), setOf(PrayerName.ASR), now, endOfDay))
        assertNull(LockPolicy.blockingPrayer(schedule, DailyPrayerLog(asr = true), setOf(PrayerName.ASR), now, endOfDay))
        assertNull(LockPolicy.blockingPrayer(schedule, DailyPrayerLog(), setOf(PrayerName.FAJR), now, endOfDay))
        assertNull(LockPolicy.blockingPrayer(schedule, DailyPrayerLog(), setOf(PrayerName.ASR), schedule.asr.minusSeconds(1), endOfDay))
        assertNull(LockPolicy.blockingPrayer(schedule, DailyPrayerLog(), setOf(PrayerName.ASR), schedule.maghrib, endOfDay))
    }

    @Test fun ishaWindowRunsToEndOfDay() {
        assertEquals(PrayerName.ISHA, LockPolicy.blockingPrayer(schedule, DailyPrayerLog(), setOf(PrayerName.ISHA), endOfDay.minusSeconds(1), endOfDay))
    }
}

class AlarmsTest {
    private val days = PrayerCalculator.schedules(GeoPoint(24.86, 67.0), LocalDate.of(2026, 10, 25), 2, "Karachi", true)

    @Test fun plansOnlyEnabledFutureAlarms() {
        val settings = AlarmSettings(enabledPrayers = setOf(PrayerName.FAJR, PrayerName.ISHA))
        val now = days[0].dhuhr
        val planned = AlarmPlanner.upcoming(days, settings, now)
        assertEquals(listOf(PrayerName.ISHA, PrayerName.FAJR, PrayerName.ISHA), planned.map { it.prayer })
        assertEquals(planned.size, planned.map { it.requestCode }.toSet().size)
        assertTrue(AlarmPlanner.upcoming(days, settings.copy(alarmsEnabled = false), now).isEmpty())
    }

    @Test fun onboardingProfileMapsToSettings() {
        val s = AlarmSettings.fromOnboarding(
            mapOf(
                "selectedAlarmPrayers" to listOf("fajr", "isha", "bogus"),
                "alarmStrictness" to "relaxed",
                "alarmSoundName" to "Takbir Alarm Loud",
            ),
        )
        assertEquals(setOf(PrayerName.FAJR, PrayerName.ISHA), s.enabledPrayers)
        assertEquals(AlarmStrictness.RELAXED, s.strictness)
        assertEquals(AlarmSound.TAKBIR, s.sound)
        assertEquals(PrayerName.entries.toSet(), AlarmSettings.fromOnboarding(emptyMap()).enabledPrayers)
    }

    @Test fun countdownFormats() {
        val now = Instant.parse("2026-10-25T00:00:00Z")
        assertEquals("in 2h 5m", AlarmPlanner.relativeCountdown(now.plusSeconds(7500), now))
        assertEquals("in 12m", AlarmPlanner.relativeCountdown(now.plusSeconds(720), now))
        assertEquals("01:00:05", AlarmPlanner.clock(now.plusSeconds(3605), now))
    }
}

class MiscTest {
    @Test fun duaRotationMatchesIos() {
        // Expected values computed with Swift's UInt64 wrapping arithmetic.
        val at = Instant.ofEpochSecond(1761400000)
        assertEquals(55, DuaLibrary.index(at, 100))
        assertEquals(2, DuaLibrary.index(at, 8, 7))
        assertEquals(100, DuaLibrary.all.size)
        assertEquals(8, DuaLibrary.themes.size)
    }

    @Test fun entitlementParsing() {
        val now = Instant.parse("2026-10-25T00:00:00Z")
        val e = Entitlement.fromMap(
            mapOf("active" to true, "plan" to "yearly", "accessUntil" to "2027-10-27T00:00:00.000Z", "manageable" to true),
            now,
        )
        assertTrue(e.isActive(now))
        assertFalse(e.isActive(Instant.parse("2027-10-28T00:00:00Z")))
        assertFalse(e.needsRefresh(now.plusSeconds(3600)))
        assertTrue(e.needsRefresh(now.plusSeconds(13 * 3600)))
        assertFalse(Entitlement.fromMap(null, now).isActive(now))
        assertFalse(e.trialEnded(Instant.parse("2027-10-28T00:00:00Z")))
    }

    @Test fun freeTrialDaysLeftAndEnd() {
        val start = Instant.parse("2026-10-25T10:00:00Z")
        val t = Entitlement.fromMap(
            mapOf("active" to true, "trial" to true, "status" to "trialing", "accessUntil" to "2026-11-01T10:00:00.000Z"),
            start,
        )
        assertEquals(7, t.trialDaysLeft(start))
        assertEquals(1, t.trialDaysLeft(Instant.parse("2026-11-01T09:00:00Z")))
        assertFalse(t.trialEnded(start))
        val after = Instant.parse("2026-11-01T10:00:01Z")
        assertTrue(t.trialEnded(after))
        assertEquals(null, t.trialDaysLeft(after))
    }
}
