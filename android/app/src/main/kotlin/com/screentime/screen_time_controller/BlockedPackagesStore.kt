package com.screentime.screen_time_controller

import android.content.Context
import java.util.concurrent.atomic.AtomicReference

/**
 * Thread-safe store for the blocked package list. Persisted so the
 * AccessibilityService can read it without Flutter running.
 */
object BlockedPackagesStore {
    private const val PREFS_NAME = "app_blocking"
    private const val KEY_BLOCKED_PACKAGES = "blocked_packages"

    private val appContext = AtomicReference<Context?>(null)
    private val blockedPackages = AtomicReference<Set<String>>(emptySet())

    @Volatile
    var onPackagesUpdated: (() -> Unit)? = null

    fun init(context: Context) {
        appContext.set(context.applicationContext)
        loadFromPrefs()
    }

    private fun loadFromPrefs() {
        val ctx = appContext.get() ?: return
        val prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val stored = prefs.getStringSet(KEY_BLOCKED_PACKAGES, emptySet()) ?: emptySet()
        blockedPackages.set(stored)
    }

    fun setBlockedPackages(packages: Set<String>): Boolean {
        val copy = packages.toSet()
        val previous = blockedPackages.get()
        if (previous == copy) return false

        blockedPackages.set(copy)
        val ctx = appContext.get() ?: return true
        ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putStringSet(KEY_BLOCKED_PACKAGES, copy)
            .apply()

        return true
    }

    fun notifyStateUpdated() {
        onPackagesUpdated?.invoke()
    }

    fun clear() {
        if (setBlockedPackages(emptySet())) {
            notifyStateUpdated()
        }
    }

    fun isBlocked(packageName: String): Boolean {
        return blockedPackages.get().contains(packageName)
    }

    fun hasBlockedPackages(): Boolean {
        return blockedPackages.get().isNotEmpty()
    }
}
