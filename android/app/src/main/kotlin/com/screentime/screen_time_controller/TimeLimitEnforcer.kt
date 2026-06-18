package com.screentime.screen_time_controller

import android.content.Context
import java.util.Calendar
import kotlin.math.max

/**
 * Evaluates time-limit rules on the native side using live usage stats so the
 * block overlay can appear while the user remains in the foreground app.
 */
object TimeLimitEnforcer {
    fun shouldEnforce(context: Context, packageName: String): Boolean {
        val now = System.currentTimeMillis()
        if (hasActiveUnblock(packageName, now)) return false

        val ruleEntries = TimeLimitRulesStore.entriesFor(packageName)
        if (ruleEntries.isEmpty()) return false

        val usageMs = UsageStatsHelper.getTodayUsageMs(context, packageName)

        for (entry in ruleEntries) {
            val effectiveMs = max(0L, usageMs - entry.baselineMs)
            if (effectiveMs < entry.allowedMs) continue

            var exceededAt = TimeLimitRulesStore.resolvedExceededAt(
                packageName,
                entry.limitExceededAtMs,
            )
            if (exceededAt <= 0L) {
                exceededAt = now
                TimeLimitRulesStore.recordExceeded(packageName, exceededAt)
            }

            val expiryMs = if (entry.blockUntilMidnight) {
                startOfNextLocalDayMs(exceededAt)
            } else {
                exceededAt + entry.blockUntilMs
            }
            if (now < expiryMs) return true
        }
        return false
    }

    private fun hasActiveUnblock(packageName: String, nowMs: Long): Boolean {
        val until = TemporaryUnblocksStore.unblockUntil(packageName) ?: return false
        return until > nowMs
    }

    private fun startOfNextLocalDayMs(fromMs: Long): Long {
        return Calendar.getInstance().apply {
            timeInMillis = fromMs
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            add(Calendar.DAY_OF_YEAR, 1)
        }.timeInMillis
    }
}
