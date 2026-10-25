package com.salahalarm.android

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import org.json.JSONObject
import java.util.Locale

/**
 * Keys are the English strings, like the iOS app and the web funnel, so the
 * same translations are reused (assets/i18n.json is built by
 * android/scripts/build-i18n.mjs from the iOS catalogs).
 */
object I18n {
    data class Language(val code: String, val name: String, val rtl: Boolean)

    val languages = listOf(
        Language("en", "English", false),
        Language("ar", "العربية", true),
        Language("tr", "Türkçe", false),
        Language("id", "Bahasa Indonesia", false),
        Language("ur", "اردو", true),
    )

    var lang by mutableStateOf("en")
        private set
    private var tables: Map<String, Map<String, String>> = emptyMap()

    fun init(context: Context, saved: String?) {
        tables = runCatching {
            val root = JSONObject(context.assets.open("i18n.json").bufferedReader().use { it.readText() })
            root.keys().asSequence().associateWith { code ->
                val table = root.getJSONObject(code)
                table.keys().asSequence().associateWith { table.getString(it) }
            }
        }.getOrDefault(emptyMap())
        lang = saved ?: systemLanguage()
    }

    fun set(code: String) {
        lang = code
    }

    val isRtl: Boolean get() = languages.firstOrNull { it.code == lang }?.rtl ?: false
    val locale: Locale get() = Locale.forLanguageTag(lang)

    private fun systemLanguage(): String {
        val sys = Locale.getDefault().language.let { if (it == "in") "id" else it }
        return if (languages.any { it.code == sys }) sys else "en"
    }

    fun t(key: String): String = if (lang == "en") key else tables[lang]?.get(key) ?: key

    /** iOS-style format strings: each %@ or %d takes the next argument. */
    fun tf(key: String, vararg args: Any): String {
        var i = 0
        return Regex("%(?:\\d\\$)?[@dDsS]|%lld|%ld").replace(t(key)) { args.getOrNull(i++)?.toString() ?: "" }
    }
}

fun t(key: String) = I18n.t(key)
fun tf(key: String, vararg args: Any) = I18n.tf(key, *args)
