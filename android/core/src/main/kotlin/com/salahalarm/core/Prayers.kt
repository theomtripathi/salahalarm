package com.salahalarm.core

import com.batoulapps.adhan.CalculationMethod
import com.batoulapps.adhan.CalculationParameters
import com.batoulapps.adhan.Coordinates
import com.batoulapps.adhan.Madhab
import com.batoulapps.adhan.PrayerTimes
import com.batoulapps.adhan.Qibla
import com.batoulapps.adhan.data.DateComponents
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import kotlin.math.asin
import kotlin.math.cos
import kotlin.math.pow
import kotlin.math.sin
import kotlin.math.sqrt

/** Raw values match the iOS `PrayerName` enum, so Firestore data is shared. */
enum class PrayerName(val id: String, val displayName: String, val arabicName: String) {
    FAJR("fajr", "Fajr", "الفجر"),
    DHUHR("dhuhr", "Dhuhr", "الظهر"),
    ASR("asr", "Asr", "العصر"),
    MAGHRIB("maghrib", "Maghrib", "المغرب"),
    ISHA("isha", "Isha", "العشاء");

    companion object {
        fun fromId(id: String?): PrayerName? = entries.firstOrNull { it.id == id }
    }
}

data class PrayerSchedule(
    val date: LocalDate,
    val fajr: Instant,
    val sunrise: Instant,
    val dhuhr: Instant,
    val asr: Instant,
    val maghrib: Instant,
    val isha: Instant,
) {
    fun time(prayer: PrayerName): Instant = when (prayer) {
        PrayerName.FAJR -> fajr
        PrayerName.DHUHR -> dhuhr
        PrayerName.ASR -> asr
        PrayerName.MAGHRIB -> maghrib
        PrayerName.ISHA -> isha
    }

    val prayers: List<Pair<PrayerName, Instant>> get() = PrayerName.entries.map { it to time(it) }
}

data class GeoPoint(val latitude: Double, val longitude: Double)

/**
 * Prayer times by country convention. The web funnel uses the same table
 * (web/src/prayer.js) so the plan screen and the app agree.
 */
object PrayerCalculator {
    private val methodByCountry = mapOf(
        "SA" to "UmmAlQura", "YE" to "UmmAlQura",
        "AE" to "Dubai", "OM" to "Dubai", "BH" to "Dubai",
        "QA" to "Qatar", "KW" to "Kuwait",
        "EG" to "Egyptian", "SD" to "Egyptian", "LY" to "Egyptian", "SY" to "Egyptian", "LB" to "Egyptian",
        "JO" to "Egyptian", "PS" to "Egyptian", "IQ" to "Egyptian",
        "TR" to "Turkey", "AZ" to "Turkey",
        "IR" to "Tehran",
        "PK" to "Karachi", "IN" to "Karachi", "BD" to "Karachi", "AF" to "Karachi", "LK" to "Karachi", "NP" to "Karachi",
        "SG" to "Singapore", "MY" to "Singapore", "ID" to "Singapore", "BN" to "Singapore",
        "US" to "NorthAmerica", "CA" to "NorthAmerica",
        "GB" to "MoonsightingCommittee", "IE" to "MoonsightingCommittee",
    )
    private val hanafiCountries = setOf("PK", "IN", "BD", "AF", "TR", "UZ", "TJ", "KG", "TM", "KZ")

    val methods = listOf(
        "MuslimWorldLeague", "UmmAlQura", "Dubai", "Qatar", "Kuwait", "Egyptian", "Turkey", "Tehran",
        "Karachi", "Singapore", "NorthAmerica", "MoonsightingCommittee",
    )

    fun methodFor(country: String?): String = methodByCountry[country?.uppercase()] ?: "MuslimWorldLeague"
    fun hanafiFor(country: String?): Boolean = country?.uppercase() in hanafiCountries

    fun parameters(method: String, hanafi: Boolean): CalculationParameters {
        val params = when (method) {
            "UmmAlQura" -> CalculationMethod.UMM_AL_QURA.parameters
            "Dubai" -> CalculationMethod.DUBAI.parameters
            "Qatar" -> CalculationMethod.QATAR.parameters
            "Kuwait" -> CalculationMethod.KUWAIT.parameters
            "Egyptian" -> CalculationMethod.EGYPTIAN.parameters
            "Karachi" -> CalculationMethod.KARACHI.parameters
            "Singapore" -> CalculationMethod.SINGAPORE.parameters
            "NorthAmerica" -> CalculationMethod.NORTH_AMERICA.parameters
            "MoonsightingCommittee" -> CalculationMethod.MOON_SIGHTING_COMMITTEE.parameters
            // Not built into adhan-java 1.2.1; Diyanet and Tehran angles.
            "Turkey" -> CalculationParameters(18.0, 17.0)
            "Tehran" -> CalculationParameters(17.7, 14.0)
            else -> CalculationMethod.MUSLIM_WORLD_LEAGUE.parameters
        }
        params.madhab = if (hanafi) Madhab.HANAFI else Madhab.SHAFI
        return params
    }

    fun schedule(point: GeoPoint, date: LocalDate, method: String, hanafi: Boolean): PrayerSchedule {
        val times = PrayerTimes(
            Coordinates(point.latitude, point.longitude),
            DateComponents(date.year, date.monthValue, date.dayOfMonth),
            parameters(method, hanafi),
        )
        return PrayerSchedule(
            date = date,
            fajr = times.fajr.toInstant(),
            sunrise = times.sunrise.toInstant(),
            dhuhr = times.dhuhr.toInstant(),
            asr = times.asr.toInstant(),
            maghrib = times.maghrib.toInstant(),
            isha = times.isha.toInstant(),
        )
    }

    fun schedules(point: GeoPoint, from: LocalDate, days: Int, method: String, hanafi: Boolean): List<PrayerSchedule> =
        (0 until days).map { schedule(point, from.plusDays(it.toLong()), method, hanafi) }

    /** The next prayer at or after [now] across today and tomorrow. */
    fun nextPrayer(schedules: List<PrayerSchedule>, now: Instant): Pair<PrayerName, Instant>? =
        schedules.flatMap { it.prayers }.firstOrNull { it.second > now }

    fun today(zone: ZoneId, now: Instant = Instant.now()): LocalDate = now.atZone(zone).toLocalDate()
}

object QiblaMath {
    private val kaaba = GeoPoint(21.4225, 39.8262)

    /** Degrees clockwise from true north. */
    fun bearing(from: GeoPoint): Double = Qibla(Coordinates(from.latitude, from.longitude)).direction

    fun distanceKm(from: GeoPoint): Double {
        val r = 6371.0
        val dLat = Math.toRadians(kaaba.latitude - from.latitude)
        val dLon = Math.toRadians(kaaba.longitude - from.longitude)
        val a = sin(dLat / 2).pow(2) +
            cos(Math.toRadians(from.latitude)) * cos(Math.toRadians(kaaba.latitude)) * sin(dLon / 2).pow(2)
        return 2 * r * asin(sqrt(a))
    }

    /** Signed turn in degrees (-180..180) from the phone's heading to the qibla. */
    fun turn(heading: Double, qibla: Double): Double {
        var d = (qibla - heading) % 360.0
        if (d > 180) d -= 360
        if (d < -180) d += 360
        return d
    }
}
