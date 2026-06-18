package com.screentime.screen_time_controller

import android.content.Context
import java.util.Calendar
import java.util.concurrent.atomic.AtomicReference

/**
 * Persists per-app daily unblock counts. Opens and foreground usage come from
 * [UsageStatsHelper].
 */
object BlockedAppStatsStore {
    private const val PREFS_NAME = "blocked_app_daily_stats"
    private const val KEY_DAY = "stats_day"
    private const val KEY_UNBLOCKS_PREFIX = "unblocks_"

    private val appContext = AtomicReference<Context?>(null)

    fun init(context: Context) {
        appContext.set(context.applicationContext)
        rolloverIfNeeded()
    }

    fun recordUnblock(context: Context, packageName: String) {
        if (packageName.isBlank()) return
        val ctx = appContext.get() ?: context.applicationContext.also { appContext.set(it) }
        rolloverIfNeeded(ctx)
        val prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val key = unblocksKey(packageName)
        val updated = prefs.getInt(key, 0) + 1
        prefs.edit().putInt(key, updated).apply()
    }

    fun getUnblockCount(context: Context, packageName: String): Int {
        val ctx = appContext.get() ?: context.applicationContext.also { appContext.set(it) }
        rolloverIfNeeded(ctx)
        return ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getInt(unblocksKey(packageName), 0)
    }

    private fun rolloverIfNeeded(ctx: Context? = null) {
        val resolved = ctx ?: appContext.get() ?: return
        val prefs = resolved.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val today = currentDayKey()
        val storedDay = prefs.getString(KEY_DAY, null)
        if (storedDay == today) return

        prefs.edit().clear().putString(KEY_DAY, today).apply()
    }

    private fun unblocksKey(packageName: String) = KEY_UNBLOCKS_PREFIX + packageName

    private fun currentDayKey(): String {
        val cal = Calendar.getInstance()
        return buildString {
            append(cal.get(Calendar.YEAR))
            append('-')
            append(cal.get(Calendar.MONTH) + 1)
            append('-')
            append(cal.get(Calendar.DAY_OF_MONTH))
        }
    }
}
