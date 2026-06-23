package com.screentime.screen_time_controller

import android.content.Context
import android.content.SharedPreferences
import java.util.concurrent.atomic.AtomicReference

/**
 * Persists the last date the midnight auto-move ran so we never process
 * the same day twice, even across reboots or process death.
 */
object MidnightAutoMoveStore {
    private const val PREFS_NAME = "midnight_auto_move"
    private const val KEY_LAST_RUN_DATE = "last_run_date"

    private val appContext = AtomicReference<Context?>(null)

    fun init(context: Context) {
        appContext.set(context.applicationContext)
    }

    fun getLastRunDate(): String? {
        val ctx = appContext.get() ?: return null
        val prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getString(KEY_LAST_RUN_DATE, null)
    }

    fun markRunFor(dateIso: String) {
        val ctx = appContext.get() ?: return
        ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_LAST_RUN_DATE, dateIso)
            .apply()
    }

    fun hasRunFor(dateIso: String): Boolean {
        return getLastRunDate() == dateIso
    }
}
