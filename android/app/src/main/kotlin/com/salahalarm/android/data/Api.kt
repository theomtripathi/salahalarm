package com.salahalarm.android.data

import com.salahalarm.android.BuildConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

class ApiException(val status: Int, message: String) : IOException(message)

/** salahalarm.com Worker endpoints and the quran.com API. */
object Api {
    private const val QURAN = "https://api.quran.com/api/v4"

    suspend fun request(
        url: String,
        method: String = "GET",
        token: String? = null,
        body: JSONObject? = null,
    ): JSONObject = withContext(Dispatchers.IO) {
        val conn = URL(url).openConnection() as HttpURLConnection
        try {
            conn.requestMethod = method
            conn.connectTimeout = 15_000
            conn.readTimeout = 20_000
            conn.setRequestProperty("accept", "application/json")
            conn.setRequestProperty("user-agent", "SalahAlarm-Android/${BuildConfig.VERSION_NAME}")
            if (token != null) conn.setRequestProperty("authorization", "Bearer $token")
            if (body != null) {
                conn.doOutput = true
                conn.setRequestProperty("content-type", "application/json")
                conn.outputStream.use { it.write(body.toString().toByteArray()) }
            }
            val status = conn.responseCode
            val text = (if (status in 200..299) conn.inputStream else conn.errorStream)
                ?.bufferedReader()?.use { it.readText() }.orEmpty()
            val json = runCatching { JSONObject(text) }.getOrElse { JSONObject() }
            if (status !in 200..299) throw ApiException(status, json.optString("error").ifEmpty { "Request failed ($status)" })
            json
        } finally {
            conn.disconnect()
        }
    }

    private fun site(path: String) = BuildConfig.API_ORIGIN + path

    suspend fun config(): JSONObject = request(site("/api/config"))
    suspend fun entitlement(token: String): JSONObject = request(site("/api/entitlement"), token = token).getJSONObject("entitlement")
    suspend fun portal(token: String): String = request(site("/api/portal"), "POST", token, JSONObject()).getString("link")
    suspend fun redeemLogin(code: String): String =
        request(site("/api/app-login/redeem"), "POST", body = JSONObject().put("code", code)).getString("token")
    suspend fun latest(): JSONObject = request(site("/api/android/latest"))

    /** A 30-minute APK link; the server only gives one to accounts with a plan or trial. */
    suspend fun downloadLink(token: String): String =
        site(request(site("/api/android/download"), "POST", token, JSONObject()).getString("url"))
    fun paywallUrl(source: String): String = site("/android/?resume=paywall&src=$source")
    val installGuideUrl: String get() = site("/android/install/")
    const val SUPPORT_URL = "https://ramadan-pro.lovable.app/support"
    const val PRIVACY_URL = "https://ramadan-pro.lovable.app/privacy"
    const val TERMS_URL = "https://ramadan-pro.lovable.app/terms"

    // ---- Quran (same API and translation as iOS) -------------------------------

    data class Surah(
        val number: Int,
        val name: String,
        val arabicName: String,
        val translatedName: String,
        val ayahCount: Int,
        val revelationPlace: String,
    )

    data class Ayah(val number: Int, val key: String, val arabic: String, val translation: String)

    data class AyahPage(val ayahs: List<Ayah>, val page: Int, val totalPages: Int)

    /** Sahih International by default; the app language's own translation when quran.com has one. */
    fun translationFor(lang: String): Int = when (lang) {
        "ur" -> 97
        "id" -> 33
        "tr" -> 77
        else -> 20
    }

    suspend fun surahs(lang: String): List<Surah> {
        val json = request("$QURAN/chapters?language=${enc(lang)}")
        val arr: JSONArray = json.getJSONArray("chapters")
        return (0 until arr.length()).map {
            val c = arr.getJSONObject(it)
            Surah(
                number = c.getInt("id"),
                name = c.optString("name_simple"),
                arabicName = c.optString("name_arabic"),
                translatedName = c.optJSONObject("translated_name")?.optString("name").orEmpty(),
                ayahCount = c.optInt("verses_count"),
                revelationPlace = c.optString("revelation_place"),
            )
        }
    }

    suspend fun ayahs(surah: Int, page: Int, lang: String, perPage: Int = 20): AyahPage {
        val translation = translationFor(lang)
        val json = request(
            "$QURAN/verses/by_chapter/$surah?translations=$translation&translation_fields=text,language_name" +
                "&fields=text_uthmani&page=$page&per_page=$perPage",
        )
        val verses = json.getJSONArray("verses")
        val pagination = json.optJSONObject("pagination")
        val ayahs = (0 until verses.length()).map {
            val v = verses.getJSONObject(it)
            val tr = v.optJSONArray("translations")?.optJSONObject(0)?.optString("text").orEmpty()
            Ayah(
                number = v.getInt("verse_number"),
                key = v.optString("verse_key"),
                arabic = v.optString("text_uthmani"),
                translation = cleanTranslation(tr),
            )
        }
        return AyahPage(ayahs, pagination?.optInt("current_page", page) ?: page, pagination?.optInt("total_pages", 1) ?: 1)
    }

    /** quran.com wraps footnotes in <sup> tags; iOS strips the markup the same way. */
    fun cleanTranslation(text: String): String = text
        .replace(Regex("<sup[^>]*>.*?</sup>"), "")
        .replace(Regex("<[^>]+>"), "")
        .replace("&quot;", "\"").replace("&amp;", "&").replace("&#39;", "'")
        .replace(Regex("\\s+"), " ")
        .trim()

    private fun enc(s: String) = URLEncoder.encode(s, "UTF-8")
}
