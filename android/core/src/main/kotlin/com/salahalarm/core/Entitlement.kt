package com.salahalarm.core

import java.time.Instant

/**
 * What /api/entitlement returns (web/src/entitlement.js publicEntitlement).
 * The app caches it and keeps premium on while [accessUntil] is ahead, so
 * alarms keep working offline.
 */
data class Entitlement(
    val active: Boolean,
    val status: String? = null,
    val plan: String? = null,
    val accessUntil: Instant? = null,
    val currentPeriodEnd: Instant? = null,
    val cancelAtPeriodEnd: Boolean = false,
    val email: String? = null,
    val manageable: Boolean = false,
    /** The no-card free trial from the web paywall, not a paid plan. */
    val trial: Boolean = false,
    val checkedAt: Instant? = null,
) {
    fun isActive(now: Instant): Boolean = accessUntil?.let { it > now } ?: false

    /** The free trial ran out and nothing was bought: time to send the user to the paywall. */
    fun trialEnded(now: Instant): Boolean = trial && !isActive(now)

    /** Whole days left in an active free trial, rounded up (1 on the last day). */
    fun trialDaysLeft(now: Instant): Int? {
        val end = accessUntil ?: return null
        if (!trial || end <= now) return null
        return ((end.epochSecond - now.epochSecond + 86_399) / 86_400).toInt()
    }

    /** Re-check with the server at most this often while premium looks active. */
    fun needsRefresh(now: Instant, maxAgeHours: Long = 12): Boolean =
        checkedAt == null || checkedAt.plusSeconds(maxAgeHours * 3600) < now || !isActive(now)

    companion object {
        val NONE = Entitlement(active = false)

        fun parseInstant(value: Any?): Instant? = (value as? String)?.let { runCatching { Instant.parse(it) }.getOrNull() }

        fun fromMap(map: Map<String, Any?>?, checkedAt: Instant?): Entitlement {
            if (map == null) return NONE.copy(checkedAt = checkedAt)
            return Entitlement(
                active = map["active"] as? Boolean ?: false,
                status = map["status"] as? String,
                plan = map["plan"] as? String,
                accessUntil = parseInstant(map["accessUntil"]),
                currentPeriodEnd = parseInstant(map["currentPeriodEnd"]),
                cancelAtPeriodEnd = map["cancelAtPeriodEnd"] as? Boolean ?: false,
                email = map["email"] as? String,
                manageable = map["manageable"] as? Boolean ?: false,
                trial = map["trial"] as? Boolean ?: (map["provider"] == "trial"),
                checkedAt = checkedAt,
            )
        }
    }
}

/** Compares "1.2.3"-style version names and integer codes for the in-app updater. */
object Versions {
    fun isNewer(remoteCode: Int?, localCode: Int): Boolean = remoteCode != null && remoteCode > localCode
}
