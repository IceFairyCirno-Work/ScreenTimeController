package com.screentime.screen_time_controller

import android.content.Context
import java.util.concurrent.atomic.AtomicReference

/**
 * User preference for the distracting-app awareness overlay pill.
 * Synced from Flutter; defaults to enabled.
 */
object DistractingOverlaySettingsStore {
    private const val PREFS_NAME = "app_blocking"
    private const val KEY_OVERLAY_ENABLED = "distracting_overlay_enabled"

    private val appContext = AtomicReference<Context?>(null)
    private val overlayEnabled = AtomicReference(true)

    fun init(context: Context) {
        appContext.set(context.applicationContext)
        loadFromPrefs()
    }

    private fun loadFromPrefs() {
        val ctx = appContext.get() ?: return
        val prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        overlayEnabled.set(prefs.getBoolean(KEY_OVERLAY_ENABLED, true))
    }

    fun setEnabled(enabled: Boolean): Boolean {
        if (overlayEnabled.get() == enabled) return false

        overlayEnabled.set(enabled)
        val ctx = appContext.get() ?: return true
        ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_OVERLAY_ENABLED, enabled)
            .apply()
        return true
    }

    fun isEnabled(): Boolean = overlayEnabled.get()
}
