package com.salahalarm.android.data

import android.content.Context
import android.content.SharedPreferences
import androidx.core.content.edit
import com.salahalarm.core.AlarmSettings
import com.salahalarm.core.AlarmSound
import com.salahalarm.core.AlarmStrictness
import com.salahalarm.core.DailyPrayerLog
import com.salahalarm.core.DateKeys
import com.salahalarm.core.Entitlement
import com.salahalarm.core.GeoPoint
import com.salahalarm.core.PrayerName
import com.salahalarm.core.StreakData
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.time.LocalDate

data class SavedLocation(
    val point: GeoPoint,
    val city: String?,
    val country: String?,
    val precise: Boolean,
)

data class LockSettings(
    val enabled: Boolean = true,
    val enforced: Set<PrayerName> = PrayerName.entries.toSet(),
    val packages: Set<String> = emptySet(),
)

data class PrayerPrefs(
    /** "auto" follows the country, otherwise a PrayerCalculator method name. */
    val method: String = "auto",
    /** "auto", "hanafi" or "shafi". */
    val asr: String = "auto",
)

data class QuranPrefs(
    val fontSize: Float = 24f,
    val showTranslation: Boolean = true,
)

data class LastRead(val surah: Int, val name: String, val ayah: Int)

data class Bookmark(val id: String, val surah: Int, val ayah: Int, val timestamp: Long)

data class AlarmLogEntry(val prayer: PrayerName, val scheduled: Long, val at: Long, val method: String)

/** Everything the app keeps on the phone, so alarms and the lock work offline. */
class Store(context: Context) {
    private val prefs: SharedPreferences = context.getSharedPreferences("salahalarm", Context.MODE_PRIVATE)

    private fun obj(key: String): JSONObject? = prefs.getString(key, null)?.let { runCatching { JSONObject(it) }.getOrNull() }
    private fun put(key: String, value: Any?) = prefs.edit { putString(key, value?.toString()) }

    // ---- language & flags ----------------------------------------------------

    fun language(): String? = prefs.getString("language", null)
    fun setLanguage(code: String) = prefs.edit { putString("language", code) }

    fun flag(name: String): Boolean = prefs.getBoolean("flag_$name", false)
    fun setFlag(name: String, value: Boolean = true) = prefs.edit { putBoolean("flag_$name", value) }

    fun long(name: String): Long = prefs.getLong(name, 0L)
    fun setLong(name: String, value: Long) = prefs.edit { putLong(name, value) }

    fun string(name: String): String? = prefs.getString(name, null)
    fun setString(name: String, value: String?) = prefs.edit { putString(name, value) }

    // ---- alarm settings ------------------------------------------------------

    fun alarmSettings(): AlarmSettings {
        val o = obj("alarm_settings") ?: return AlarmSettings()
        return AlarmSettings(
            enabledPrayers = o.optJSONArray("prayers").strings().mapNotNull { PrayerName.fromId(it) }.toSet(),
            strictness = AlarmStrictness.fromRaw(o.optString("strictness")),
            sound = AlarmSound.fromRaw(o.optString("sound")),
            volume = o.optDouble("volume", 1.0).toFloat(),
            vibrationEnabled = o.optBoolean("vibration", true),
            alarmsEnabled = o.optBoolean("enabled", true),
            matSetupCompleted = o.optBoolean("matSetup", false),
        )
    }

    fun saveAlarmSettings(s: AlarmSettings) = put(
        "alarm_settings",
        JSONObject()
            .put("prayers", JSONArray(s.enabledPrayers.map { it.id }))
            .put("strictness", s.strictness.raw)
            .put("sound", s.sound.raw)
            .put("volume", s.volume.toDouble())
            .put("vibration", s.vibrationEnabled)
            .put("enabled", s.alarmsEnabled)
            .put("matSetup", s.matSetupCompleted),
    )

    // ---- prayer log & streak -------------------------------------------------

    fun logs(): Map<String, DailyPrayerLog> {
        val o = obj("prayer_logs") ?: return emptyMap()
        return o.keys().asSequence().associateWith { logFrom(o.getJSONObject(it)) }
    }

    fun saveLogs(logs: Map<String, DailyPrayerLog>) {
        // Keep about a year on the phone; Firestore has the full history.
        val cutoff = DateKeys.of(LocalDate.now().minusDays(400))
        val o = JSONObject()
        logs.filterKeys { it >= cutoff }.forEach { (k, v) -> o.put(k, logJson(v)) }
        put("prayer_logs", o)
    }

    fun streak(): StreakData {
        val o = obj("streak") ?: return StreakData()
        return StreakData(
            currentStreak = o.optInt("currentStreak"),
            longestStreak = o.optInt("longestStreak"),
            lastStreakDate = o.optString("lastStreakDate"),
            totalPrayerDays = o.optInt("totalPrayerDays"),
            totalPrayersConfirmed = o.optInt("totalPrayersConfirmed"),
        )
    }

    fun saveStreak(s: StreakData) = put(
        "streak",
        JSONObject()
            .put("currentStreak", s.currentStreak)
            .put("longestStreak", s.longestStreak)
            .put("lastStreakDate", s.lastStreakDate)
            .put("totalPrayerDays", s.totalPrayerDays)
            .put("totalPrayersConfirmed", s.totalPrayersConfirmed),
    )

    // ---- location & calculation ----------------------------------------------

    fun location(): SavedLocation? {
        val o = obj("location") ?: return null
        return SavedLocation(
            GeoPoint(o.getDouble("lat"), o.getDouble("lon")),
            o.optString("city").ifEmpty { null },
            o.optString("country").ifEmpty { null },
            o.optBoolean("precise"),
        )
    }

    fun saveLocation(l: SavedLocation) = put(
        "location",
        JSONObject().put("lat", l.point.latitude).put("lon", l.point.longitude)
            .put("city", l.city ?: "").put("country", l.country ?: "").put("precise", l.precise),
    )

    fun prayerPrefs() = PrayerPrefs(
        method = prefs.getString("prayer_method", "auto") ?: "auto",
        asr = prefs.getString("prayer_asr", "auto") ?: "auto",
    )

    fun savePrayerPrefs(p: PrayerPrefs) = prefs.edit {
        putString("prayer_method", p.method)
        putString("prayer_asr", p.asr)
    }

    // ---- entitlement -----------------------------------------------------------

    fun entitlement(): Entitlement {
        val o = obj("entitlement") ?: return Entitlement.NONE
        return Entitlement.fromMap(o.toMap(), Instant.ofEpochMilli(o.optLong("_checkedAt")))
    }

    fun saveEntitlement(json: JSONObject, checkedAt: Instant) = put("entitlement", JSONObject(json.toString()).put("_checkedAt", checkedAt.toEpochMilli()))

    fun clearEntitlement() = prefs.edit { remove("entitlement") }

    // ---- SalahLock -------------------------------------------------------------

    fun lockSettings(): LockSettings {
        val o = obj("lock") ?: return LockSettings()
        return LockSettings(
            enabled = o.optBoolean("enabled", true),
            enforced = o.optJSONArray("enforced").strings().mapNotNull { PrayerName.fromId(it) }.toSet(),
            packages = o.optJSONArray("packages").strings().toSet(),
        )
    }

    fun saveLockSettings(l: LockSettings) = put(
        "lock",
        JSONObject().put("enabled", l.enabled)
            .put("enforced", JSONArray(l.enforced.map { it.id }))
            .put("packages", JSONArray(l.packages.toList())),
    )

    // ---- Quran ------------------------------------------------------------------

    fun quranPrefs() = QuranPrefs(
        fontSize = prefs.getFloat("quran_font", 24f),
        showTranslation = prefs.getBoolean("quran_translation", true),
    )

    fun saveQuranPrefs(q: QuranPrefs) = prefs.edit {
        putFloat("quran_font", q.fontSize)
        putBoolean("quran_translation", q.showTranslation)
    }

    fun lastRead(): LastRead? = obj("last_read")?.let { LastRead(it.getInt("surah"), it.optString("name"), it.optInt("ayah", 1)) }
    fun saveLastRead(l: LastRead) = put("last_read", JSONObject().put("surah", l.surah).put("name", l.name).put("ayah", l.ayah))

    fun bookmarks(): List<Bookmark> {
        val a = prefs.getString("bookmarks", null)?.let { runCatching { JSONArray(it) }.getOrNull() } ?: return emptyList()
        return (0 until a.length()).map {
            val o = a.getJSONObject(it)
            Bookmark(o.getString("id"), o.getInt("surah"), o.getInt("ayah"), o.optLong("ts"))
        }
    }

    fun saveBookmarks(list: List<Bookmark>) = put(
        "bookmarks",
        JSONArray(list.map { JSONObject().put("id", it.id).put("surah", it.surah).put("ayah", it.ayah).put("ts", it.timestamp) }),
    )

    // ---- alarm history -------------------------------------------------------------

    fun alarmLogs(): List<AlarmLogEntry> {
        val a = prefs.getString("alarm_logs", null)?.let { runCatching { JSONArray(it) }.getOrNull() } ?: return emptyList()
        return (0 until a.length()).mapNotNull {
            val o = a.getJSONObject(it)
            val prayer = PrayerName.fromId(o.optString("prayer")) ?: return@mapNotNull null
            AlarmLogEntry(prayer, o.optLong("scheduled"), o.optLong("at"), o.optString("method"))
        }
    }

    fun appendAlarmLog(e: AlarmLogEntry) {
        val list = (listOf(e) + alarmLogs()).take(30)
        put(
            "alarm_logs",
            JSONArray(list.map { JSONObject().put("prayer", it.prayer.id).put("scheduled", it.scheduled).put("at", it.at).put("method", it.method) }),
        )
    }

    fun clearAccountData() = prefs.edit {
        listOf("prayer_logs", "streak", "entitlement", "bookmarks", "last_read", "alarm_logs").forEach { remove(it) }
        remove("flag_onboarding_applied")
    }

    companion object {
        fun logJson(l: DailyPrayerLog): JSONObject = JSONObject()
            .put("fajr", l.fajr).put("dhuhr", l.dhuhr).put("asr", l.asr).put("maghrib", l.maghrib).put("isha", l.isha)
            .put("confirmedAt", JSONArray(l.confirmedAt.map { it.toEpochMilli() }))

        fun logFrom(o: JSONObject): DailyPrayerLog {
            val at = o.optJSONArray("confirmedAt")
            return DailyPrayerLog(
                fajr = o.optBoolean("fajr"),
                dhuhr = o.optBoolean("dhuhr"),
                asr = o.optBoolean("asr"),
                maghrib = o.optBoolean("maghrib"),
                isha = o.optBoolean("isha"),
                confirmedAt = if (at == null) emptyList() else (0 until at.length()).map { Instant.ofEpochMilli(at.getLong(it)) },
            )
        }
    }
}

fun JSONArray?.strings(): List<String> = if (this == null) emptyList() else (0 until length()).map { getString(it) }

fun JSONObject.toMap(): Map<String, Any?> = keys().asSequence().associateWith { key ->
    when (val v = opt(key)) {
        JSONObject.NULL -> null
        is JSONObject -> v.toMap()
        is JSONArray -> (0 until v.length()).map { v.opt(it) }
        else -> v
    }
}
