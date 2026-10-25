package com.salahalarm.android.data

import android.os.Build
import com.salahalarm.android.BuildConfig
import com.salahalarm.android.Graph
import com.salahalarm.android.I18n
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.util.UUID

/** PostHog capture API, same project and naming as the web funnel. */
object Analytics {
    private fun anonId(): String {
        val store = Graph.store
        return store.string("anon_id") ?: UUID.randomUUID().toString().also { store.setString("anon_id", it) }
    }

    fun distinctId(): String = Graph.repo.user.value?.uid ?: anonId()

    fun capture(event: String, props: Map<String, Any?> = emptyMap()) {
        if (BuildConfig.POSTHOG_KEY.isEmpty()) return
        val properties = JSONObject()
            .put("platform", "android")
            .put("app_version", BuildConfig.VERSION_NAME)
            .put("os_version", Build.VERSION.RELEASE)
            .put("device_brand", Build.MANUFACTURER)
            .put("lang", I18n.lang)
            .put("funnel", "android_app")
        props.forEach { (k, v) -> properties.put(k, v ?: JSONObject.NULL) }
        val body = JSONObject()
            .put("api_key", BuildConfig.POSTHOG_KEY)
            .put("event", event)
            .put("distinct_id", distinctId())
            .put("properties", properties)
        Graph.scope.launch {
            runCatching { Api.request("${BuildConfig.POSTHOG_HOST}/capture/", "POST", body = body) }
        }
    }

    /** Links the anonymous install to the account once someone signs in. */
    fun identify(uid: String, email: String?) {
        capture("\$identify", mapOf("\$anon_distinct_id" to anonId(), "\$set" to JSONObject().put("email", email ?: JSONObject.NULL)))
    }

    fun appOpened() {
        val store = Graph.store
        if (!store.flag("first_open_sent")) {
            store.setFlag("first_open_sent")
            capture("android_app_first_open", mapOf("version_code" to BuildConfig.VERSION_CODE))
        }
        capture("android_app_opened")
    }
}
