package com.screentime.screen_time_controller

import android.content.Context
import java.util.concurrent.atomic.AtomicReference

object AdultContentBlockStore {
    private const val PREFS_NAME = "app_blocking"
    private const val KEY_ADULT_WEBSITES_BLOCKED = "adult_websites_blocked"

    private val appContext = AtomicReference<Context?>(null)
    private val enabled = AtomicReference(true)

    fun init(context: Context) {
        appContext.set(context.applicationContext)
        loadFromPrefs()
    }

    private fun loadFromPrefs() {
        val ctx = appContext.get() ?: return
        val prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        enabled.set(prefs.getBoolean(KEY_ADULT_WEBSITES_BLOCKED, true))
    }

    fun setEnabled(blockAdultWebsites: Boolean): Boolean {
        if (enabled.get() == blockAdultWebsites) return false

        enabled.set(blockAdultWebsites)
        val ctx = appContext.get() ?: return true
        ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_ADULT_WEBSITES_BLOCKED, blockAdultWebsites)
            .apply()
        return true
    }

    fun isEnabled(): Boolean = enabled.get()
}
