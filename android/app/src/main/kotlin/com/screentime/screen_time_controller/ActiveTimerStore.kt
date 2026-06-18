package com.screentime.screen_time_controller

import android.content.Context
import java.util.concurrent.atomic.AtomicReference

/**
 * Persists the active focus timer so it survives Samsung force-stop from recents.
 * Uses [commit] for synchronous disk writes on critical updates.
 */
object ActiveTimerStore {
    private const val PREFS_NAME = "app_blocking"
    private const val KEY_IS_RUNNING = "timer_is_running"
    private const val KEY_IS_INFINITE = "timer_is_infinite"
    private const val KEY_END_TIME_MS = "timer_end_time_ms"
    private const val KEY_STARTED_AT_MS = "timer_started_at_ms"
    private const val KEY_BLOCKED_APPS_JSON = "timer_blocked_apps_json"

    private val appContext = AtomicReference<Context?>(null)

    fun init(context: Context) {
        appContext.set(context.applicationContext)
    }

    fun syncActiveTimer(
        isRunning: Boolean,
        isInfiniteMode: Boolean,
        endTimeMs: Long?,
        startedAtMs: Long?,
        blockedAppsJson: String,
    ) {
        val ctx = appContext.get() ?: return
        val editor = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit()
        editor.putBoolean(KEY_IS_RUNNING, isRunning)
        editor.putBoolean(KEY_IS_INFINITE, isInfiniteMode)
        if (endTimeMs != null) {
            editor.putLong(KEY_END_TIME_MS, endTimeMs)
        } else {
            editor.remove(KEY_END_TIME_MS)
        }
        if (startedAtMs != null) {
            editor.putLong(KEY_STARTED_AT_MS, startedAtMs)
        } else {
            editor.remove(KEY_STARTED_AT_MS)
        }
        editor.putString(KEY_BLOCKED_APPS_JSON, blockedAppsJson)
        editor.commit()
    }

    fun clearActiveTimer() {
        val ctx = appContext.get() ?: return
        ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .remove(KEY_IS_RUNNING)
            .remove(KEY_IS_INFINITE)
            .remove(KEY_END_TIME_MS)
            .remove(KEY_STARTED_AT_MS)
            .remove(KEY_BLOCKED_APPS_JSON)
            .commit()
    }

    fun getActiveTimer(): Map<String, Any?>? {
        val ctx = appContext.get() ?: return null
        val prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_IS_RUNNING, false)) return null

        val endTimeMs = if (prefs.contains(KEY_END_TIME_MS)) {
            prefs.getLong(KEY_END_TIME_MS, 0L)
        } else {
            null
        }
        val startedAtMs = if (prefs.contains(KEY_STARTED_AT_MS)) {
            prefs.getLong(KEY_STARTED_AT_MS, 0L)
        } else {
            null
        }

        return mapOf(
            "isRunning" to true,
            "isInfiniteMode" to prefs.getBoolean(KEY_IS_INFINITE, false),
            "endTimeMs" to endTimeMs,
            "startedAtMs" to startedAtMs,
            "blockedAppsJson" to (prefs.getString(KEY_BLOCKED_APPS_JSON, "[]") ?: "[]"),
        )
    }
}
