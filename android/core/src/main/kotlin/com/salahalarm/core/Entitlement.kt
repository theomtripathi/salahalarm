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
    val checkedAt: Instant? = null,
) {
    fun isActive(now: Instant): Boolean = accessUntil?.let { it > now } ?: false

    /** The no-card free trial from the website's last exit offer. */
    val isTrial: Boolean get() = status == "trial"

    /** Whole days of trial left, rounded up; 0 once it has ended. */
    fun trialDaysLeft(now: Instant): Long =
        if (!isTrial || accessUntil == null || accessUntil <= now) 0 else (java.time.Duration.between(now, accessUntil).toHours() + 23) / 24

    /** The trial ran out and nothing replaced it: time to send them to the website. */
    fun trialEnded(now: Instant): Boolean = isTrial && !isActive(now)

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
                checkedAt = checkedAt,
            )
        }
    }
}

/** Compares "1.2.3"-style version names and integer codes for the in-app updater. */
object Versions {
    fun isNewer(remoteCode: Int?, localCode: Int): Boolean = remoteCode != null && remoteCode > localCode
}
