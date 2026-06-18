package com.screentime.screen_time_controller

import android.content.Context
import java.util.concurrent.atomic.AtomicReference

/**
 * Thread-safe store for distracting app packages. Persisted so the
 * AccessibilityService can show the awareness pill without Flutter running.
 */
object DistractingPackagesStore {
    private const val PREFS_NAME = "app_blocking"
    private const val KEY_DISTRACTING_PACKAGES = "distracting_packages"

    private val appContext = AtomicReference<Context?>(null)
    private val distractingPackages = AtomicReference<Set<String>>(emptySet())

    @Volatile
    var onPackagesUpdated: (() -> Unit)? = null

    fun init(context: Context) {
        appContext.set(context.applicationContext)
        loadFromPrefs()
    }

    private fun loadFromPrefs() {
        val ctx = appContext.get() ?: return
        val prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val stored =
            prefs.getStringSet(KEY_DISTRACTING_PACKAGES, emptySet()) ?: emptySet()
        distractingPackages.set(stored)
    }

    fun setDistractingPackages(packages: Set<String>): Boolean {
        val copy = packages.toSet()
        val previous = distractingPackages.get()
        if (previous == copy) return false

        distractingPackages.set(copy)
        val ctx = appContext.get() ?: return true
        ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putStringSet(KEY_DISTRACTING_PACKAGES, copy)
            .apply()

        return true
    }

    fun notifyStateUpdated() {
        onPackagesUpdated?.invoke()
    }

    fun isDistracting(packageName: String): Boolean {
        return distractingPackages.get().contains(packageName)
    }

    fun hasDistractingPackages(): Boolean {
        return distractingPackages.get().isNotEmpty()
    }
}
