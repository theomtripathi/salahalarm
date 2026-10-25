package com.salahalarm.android.data

import android.app.Activity
import android.content.Context
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.google.firebase.Timestamp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.FirebaseUser
import com.google.firebase.auth.GoogleAuthProvider
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions
import com.salahalarm.android.BuildConfig
import com.salahalarm.android.Graph
import com.salahalarm.android.I18n
import com.salahalarm.android.alarm.AlarmScheduler
import com.salahalarm.android.widget.Widgets
import com.salahalarm.core.AlarmSettings
import com.salahalarm.core.DailyPrayerLog
import com.salahalarm.core.DateKeys
import com.salahalarm.core.Entitlement
import com.salahalarm.core.PrayerCalculator
import com.salahalarm.core.PrayerLogic
import com.salahalarm.core.PrayerName
import com.salahalarm.core.PrayerSchedule
import com.salahalarm.core.StreakData
import com.salahalarm.core.Versions
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.util.Date
import java.util.UUID

data class UpdateInfo(val versionName: String?, val versionCode: Int)

/**
 * The app's state and the rules that change it. Everything is saved on the
 * phone first and mirrored to Firestore in the same places the iOS app uses
 * (users/{uid}.prayerLog, .streakData, bookmarks), so one account works on both.
 */
class Repo(private val context: Context, private val store: Store) {
    private val auth = FirebaseAuth.getInstance()
    private val db: FirebaseFirestore by lazy { FirebaseFirestore.getInstance() }

    val user = MutableStateFlow<FirebaseUser?>(auth.currentUser)
    val settings = MutableStateFlow(store.alarmSettings())
    val logs = MutableStateFlow(store.logs())
    val streak = MutableStateFlow(store.streak())
    val location = MutableStateFlow(store.location())
    val prayerPrefs = MutableStateFlow(store.prayerPrefs())
    val entitlement = MutableStateFlow(store.entitlement())
    val lock = MutableStateFlow(store.lockSettings())
    val quranPrefs = MutableStateFlow(store.quranPrefs())
    val bookmarks = MutableStateFlow(store.bookmarks())
    val lastRead = MutableStateFlow(store.lastRead())
    val update = MutableStateFlow<UpdateInfo?>(null)

    init {
        auth.addAuthStateListener { a ->
            val u = a.currentUser
            val previous = user.value?.uid
            user.value = u
            if (u != null && (u.uid != previous || !store.flag("synced_${u.uid}"))) {
                Graph.scope.launch { onSignedIn(u) }
            }
        }
    }

    // ---- prayer times ----------------------------------------------------------

    fun today(): LocalDate = LocalDate.now()
    fun endOfToday(): Instant = today().plusDays(1).atStartOfDay(ZoneId.systemDefault()).toInstant().minusSeconds(1)

    fun method(): String = prayerPrefs.value.method.let { if (it == "auto") PrayerCalculator.methodFor(location.value?.country) else it }

    fun hanafi(): Boolean = when (prayerPrefs.value.asr) {
        "hanafi" -> true
        "shafi" -> false
        else -> PrayerCalculator.hanafiFor(location.value?.country)
    }

    fun schedules(from: LocalDate = today(), days: Int = 2): List<PrayerSchedule> {
        val loc = location.value ?: return emptyList()
        return PrayerCalculator.schedules(loc.point, from, days, method(), hanafi())
    }

    fun todaySchedule(): PrayerSchedule? = schedules(today(), 1).firstOrNull()

    fun setLocation(l: SavedLocation) {
        location.value = l
        store.saveLocation(l)
        scheduleChanged()
    }

    fun updatePrayerPrefs(f: (PrayerPrefs) -> PrayerPrefs) {
        val p = f(prayerPrefs.value)
        prayerPrefs.value = p
        store.savePrayerPrefs(p)
        scheduleChanged()
    }

    /** Uses the GPS fix when allowed, otherwise the city the website saw, so times show from the first launch. */
    suspend fun refreshLocation() {
        val precise = runCatching { LocationHelper.current(context) }.getOrNull()
        if (precise != null) {
            setLocation(precise)
            return
        }
        if (location.value != null) return
        runCatching {
            val geo = Api.config().getJSONObject("geo")
            if (!geo.isNull("latitude") && !geo.isNull("longitude")) {
                setLocation(
                    SavedLocation(
                        com.salahalarm.core.GeoPoint(geo.getDouble("latitude"), geo.getDouble("longitude")),
                        geo.optString("city").ifEmpty { null },
                        geo.optString("country").ifEmpty { null },
                        precise = false,
                    ),
                )
            }
        }
    }

    private fun scheduleChanged() {
        AlarmScheduler.reschedule(context)
        Widgets.updateAll(context)
    }

    // ---- prayer log --------------------------------------------------------------

    fun log(date: LocalDate): DailyPrayerLog = logs.value[DateKeys.of(date)] ?: DailyPrayerLog()
    fun todayLog(): DailyPrayerLog = log(today())

    fun confirm(prayer: PrayerName) {
        val today = today()
        val key = DateKeys.of(today)
        val r = PrayerLogic.confirm(todayLog(), streak.value, prayer, today, Instant.now())
        if (!r.changed) return
        logs.value = logs.value + (key to r.log)
        store.saveLogs(logs.value)
        streak.value = r.streak
        store.saveStreak(r.streak)
        Analytics.capture("prayer_confirmed", mapOf("prayer" to prayer.id, "prayed_today" to r.log.prayedCount, "streak" to r.streak.currentStreak))
        Widgets.updateAll(context)
        Graph.scope.launch {
            pushLog(key, r.log)
            pushStreak(r.streak)
        }
    }

    private fun userDoc() = user.value?.uid?.let { db.collection("users").document(it) }

    private suspend fun pushLog(key: String, log: DailyPrayerLog) {
        val doc = userDoc() ?: return
        runCatching { doc.set(mapOf("prayerLog" to mapOf(key to logMap(log))), SetOptions.merge()).await() }
    }

    private suspend fun pushStreak(s: StreakData) {
        val doc = userDoc() ?: return
        runCatching { doc.set(mapOf("streakData" to streakMap(s)), SetOptions.merge()).await() }
    }

    /** Pulls history, streak and the web onboarding answers; local and remote logs are merged day by day. */
    suspend fun syncFromCloud() {
        val doc = userDoc() ?: return
        val data = runCatching { doc.get().await().data }.getOrNull() ?: return

        val merged = logs.value.toMutableMap()
        val remoteLogs = (data["prayerLog"] as? Map<*, *>).orEmpty()
        for ((k, v) in remoteLogs) {
            val key = k as? String ?: continue
            val remote = parseLog(v as? Map<*, *> ?: continue)
            merged[key] = merged[key]?.merged(remote) ?: remote
        }
        logs.value = merged
        store.saveLogs(merged)
        // Push days that were confirmed offline.
        for ((key, local) in merged) {
            val remote = (remoteLogs[key] as? Map<*, *>)?.let(::parseLog)
            if (remote == null || remote.prayedCount < local.prayedCount) pushLog(key, local)
        }

        val remoteStreak = (data["streakData"] as? Map<*, *>)?.let(::parseStreak)
        if (remoteStreak != null && remoteStreak.totalPrayersConfirmed > streak.value.totalPrayersConfirmed) {
            streak.value = remoteStreak
            store.saveStreak(remoteStreak)
        } else if (remoteStreak != streak.value) {
            pushStreak(streak.value)
        }

        if (!store.flag("onboarding_applied")) {
            @Suppress("UNCHECKED_CAST")
            val profile = data["onboardingProfile"] as? Map<String, Any?>
            if (profile != null) {
                updateSettings { AlarmSettings.fromOnboarding(profile) }
                store.setFlag("onboarding_applied")
            }
        }
        Widgets.updateAll(context)
    }

    // ---- alarms ---------------------------------------------------------------------

    fun updateSettings(f: (AlarmSettings) -> AlarmSettings) {
        val s = f(settings.value)
        settings.value = s
        store.saveAlarmSettings(s)
        AlarmScheduler.reschedule(context)
    }

    fun logAlarm(prayer: PrayerName, scheduled: Instant, method: String) {
        store.appendAlarmLog(AlarmLogEntry(prayer, scheduled.toEpochMilli(), System.currentTimeMillis(), method))
    }

    fun alarmLogs(): List<AlarmLogEntry> = store.alarmLogs()

    // ---- premium ----------------------------------------------------------------------

    fun isPremium(now: Instant = Instant.now()): Boolean = entitlement.value.isActive(now)

    /** Asks salahalarm.com whether this account has paid. Cached so alarms keep working offline. */
    suspend fun refreshEntitlement(force: Boolean = false): Boolean {
        val u = user.value ?: return false
        val now = Instant.now()
        if (!force && !entitlement.value.needsRefresh(now)) return isPremium(now)
        return try {
            val token = u.getIdToken(false).await().token ?: return isPremium(now)
            val json = Api.entitlement(token)
            store.saveEntitlement(json, now)
            val was = isPremium(now)
            entitlement.value = Entitlement.fromMap(json.toMap(), now)
            if (was != isPremium(now)) {
                Analytics.capture("android_entitlement_changed", mapOf("active" to isPremium(now), "plan" to entitlement.value.plan))
            }
            AlarmScheduler.reschedule(context)
            isPremium(now)
        } catch (e: Exception) {
            isPremium(now)
        }
    }

    suspend fun portalLink(): String? {
        val token = user.value?.getIdToken(false)?.await()?.token ?: return null
        return runCatching { Api.portal(token) }.getOrNull()
    }

    // ---- SalahLock -----------------------------------------------------------------------

    fun updateLock(f: (LockSettings) -> LockSettings) {
        val l = f(lock.value)
        lock.value = l
        store.saveLockSettings(l)
    }

    // ---- account -----------------------------------------------------------------------------

    private suspend fun onSignedIn(u: FirebaseUser) {
        Analytics.identify(u.uid, u.email)
        syncFromCloud()
        refreshEntitlement(force = true)
        syncBookmarks()
        store.setFlag("synced_${u.uid}")
    }

    suspend fun signInWithGoogle(activity: Activity) {
        val option = GetSignInWithGoogleOption.Builder(BuildConfig.GOOGLE_WEB_CLIENT_ID).build()
        val request = GetCredentialRequest.Builder().addCredentialOption(option).build()
        val result = CredentialManager.create(activity).getCredential(activity, request)
        val credential = result.credential
        if (credential !is CustomCredential || credential.type != GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL) {
            throw IllegalStateException("Google sign-in returned an unexpected credential")
        }
        val google = GoogleIdTokenCredential.createFrom(credential.data)
        auth.signInWithCredential(GoogleAuthProvider.getCredential(google.idToken, null)).await()
        Analytics.capture("android_signed_in", mapOf("method" to "google"))
    }

    suspend fun signInWithEmail(email: String, password: String) {
        auth.signInWithEmailAndPassword(email.trim(), password).await()
        Analytics.capture("android_signed_in", mapOf("method" to "email"))
    }

    /** The one-time code from the welcome page's "Open SalahAlarm, signed in" link. */
    suspend fun signInWithCode(code: String) {
        val token = Api.redeemLogin(code)
        auth.signInWithCustomToken(token).await()
        Analytics.capture("android_signed_in", mapOf("method" to "web_link"))
    }

    suspend fun sendPasswordReset(email: String) {
        auth.sendPasswordResetEmail(email.trim()).await()
    }

    fun signOut() {
        auth.signOut()
        store.clearAccountData()
        logs.value = emptyMap()
        streak.value = StreakData()
        entitlement.value = Entitlement.NONE
        bookmarks.value = emptyList()
        lastRead.value = null
        AlarmScheduler.reschedule(context)
        Widgets.updateAll(context)
    }

    /** Deletes the account's data and the sign-in, like the iOS Delete Account screen. */
    suspend fun deleteAccount() {
        val u = user.value ?: return
        runCatching {
            val snap = db.collection("bookmarks").whereEqualTo("userId", u.uid).get().await()
            snap.documents.forEach { it.reference.delete().await() }
        }
        runCatching { db.collection("users").document(u.uid).delete().await() }
        u.delete().await()
        signOut()
    }

    // ---- Quran ---------------------------------------------------------------------------------

    fun updateQuranPrefs(f: (QuranPrefs) -> QuranPrefs) {
        val q = f(quranPrefs.value)
        quranPrefs.value = q
        store.saveQuranPrefs(q)
    }

    fun saveLastRead(l: LastRead) {
        lastRead.value = l
        store.saveLastRead(l)
    }

    fun isBookmarked(surah: Int, ayah: Int) = bookmarks.value.any { it.surah == surah && it.ayah == ayah }

    /** One bookmark per surah, as on iOS. */
    fun toggleBookmark(surah: Int, ayah: Int) {
        val existing = bookmarks.value.firstOrNull { it.surah == surah && it.ayah == ayah }
        val removed = bookmarks.value.filter { it.surah == surah }
        val list = if (existing != null) {
            bookmarks.value - existing
        } else {
            bookmarks.value.filter { it.surah != surah } + Bookmark(UUID.randomUUID().toString().uppercase(), surah, ayah, System.currentTimeMillis())
        }
        bookmarks.value = list.sortedByDescending { it.timestamp }
        store.saveBookmarks(bookmarks.value)
        val uid = user.value?.uid ?: return
        Graph.scope.launch {
            runCatching {
                removed.forEach { db.collection("bookmarks").document(it.id).delete().await() }
                if (existing == null) {
                    val b = list.last()
                    db.collection("bookmarks").document(b.id).set(
                        mapOf(
                            "id" to b.id, "userId" to uid, "surahNumber" to b.surah, "ayahNumber" to b.ayah,
                            "timestamp" to Timestamp(Date(b.timestamp)), "note" to null,
                        ),
                    ).await()
                }
            }
        }
    }

    private suspend fun syncBookmarks() {
        val uid = user.value?.uid ?: return
        val remote = runCatching {
            db.collection("bookmarks").whereEqualTo("userId", uid).get().await().documents.mapNotNull { d ->
                val surah = (d.get("surahNumber") as? Number)?.toInt() ?: return@mapNotNull null
                val ayah = (d.get("ayahNumber") as? Number)?.toInt() ?: return@mapNotNull null
                val ts = (d.get("timestamp") as? Timestamp)?.toDate()?.time ?: 0L
                Bookmark(d.id, surah, ayah, ts)
            }
        }.getOrNull() ?: return
        val merged = (remote + bookmarks.value).groupBy { it.surah }.map { (_, list) -> list.maxBy { it.timestamp } }
        bookmarks.value = merged.sortedByDescending { it.timestamp }
        store.saveBookmarks(bookmarks.value)
    }

    // ---- updates ----------------------------------------------------------------------------------

    suspend fun checkForUpdate() {
        val now = System.currentTimeMillis()
        if (now - store.long("update_checked") < 6 * 3600_000L && update.value == null) return
        runCatching {
            val j = Api.latest()
            store.setLong("update_checked", now)
            val code = j.optInt("versionCode", 0)
            update.value = if (Versions.isNewer(code, BuildConfig.VERSION_CODE)) {
                UpdateInfo(j.optString("versionName").ifEmpty { null }, code)
            } else {
                null
            }
        }
    }

    fun setLanguage(code: String) {
        I18n.set(code)
        store.setLanguage(code)
        Widgets.updateAll(context)
    }

    companion object {
        fun logMap(l: DailyPrayerLog): Map<String, Any> = mapOf(
            "fajr" to l.fajr, "dhuhr" to l.dhuhr, "asr" to l.asr, "maghrib" to l.maghrib, "isha" to l.isha,
            "confirmedAt" to l.confirmedAt.map { Timestamp(Date.from(it)) },
        )

        fun streakMap(s: StreakData): Map<String, Any> = mapOf(
            "currentStreak" to s.currentStreak, "longestStreak" to s.longestStreak, "lastStreakDate" to s.lastStreakDate,
            "totalPrayerDays" to s.totalPrayerDays, "totalPrayersConfirmed" to s.totalPrayersConfirmed,
        )

        fun parseLog(m: Map<*, *>): DailyPrayerLog = DailyPrayerLog(
            fajr = m["fajr"] == true,
            dhuhr = m["dhuhr"] == true,
            asr = m["asr"] == true,
            maghrib = m["maghrib"] == true,
            isha = m["isha"] == true,
            confirmedAt = (m["confirmedAt"] as? List<*>).orEmpty().mapNotNull {
                when (it) {
                    is Timestamp -> it.toDate().toInstant()
                    is Date -> it.toInstant()
                    is String -> runCatching { Instant.parse(it) }.getOrNull()
                    is Number -> Instant.ofEpochSecond(it.toLong() + 978_307_200L) // Swift reference date
                    else -> null
                }
            },
        )

        fun parseStreak(m: Map<*, *>): StreakData = StreakData(
            currentStreak = (m["currentStreak"] as? Number)?.toInt() ?: 0,
            longestStreak = (m["longestStreak"] as? Number)?.toInt() ?: 0,
            lastStreakDate = m["lastStreakDate"] as? String ?: "",
            totalPrayerDays = (m["totalPrayerDays"] as? Number)?.toInt() ?: 0,
            totalPrayersConfirmed = (m["totalPrayersConfirmed"] as? Number)?.toInt() ?: 0,
        )
    }
}
