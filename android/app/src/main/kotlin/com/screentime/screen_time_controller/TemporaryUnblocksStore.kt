package com.screentime.screen_time_controller

import android.content.Context
import java.util.concurrent.atomic.AtomicReference

/**
 * Per-package temporary unblock end times synced from Flutter.
 * Lets the AccessibilityService re-block apps when a window expires while
 * the user is still in the foreground, even if Flutter is backgrounded.
 */
object TemporaryUnblocksStore {
    private const val PREFS_NAME = "app_blocking"
    private const val KEY_PREFIX = "unblock_until_"

    private val appContext = AtomicReference<Context?>(null)
    private val unblockUntilByPackage = AtomicReference<Map<String, Long>>(emptyMap())

    fun init(context: Context) {
        appContext.set(context.applicationContext)
        loadFromPrefs()
    }

    private fun loadFromPrefs() {
        val ctx = appContext.get() ?: return
        val prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val loaded = mutableMapOf<String, Long>()
        for ((key, value) in prefs.all) {
            if (key.startsWith(KEY_PREFIX)) {
                val untilMs = when (value) {
                    is Long -> value
                    is Int -> value.toLong()
                    is Number -> value.toLong()
                    else -> continue
                }
                loaded[key.removePrefix(KEY_PREFIX)] = untilMs
            }
        }
        unblockUntilByPackage.set(loaded)
    }

    /**
     * @return true when the stored map changed.
     */
    fun setTemporaryUnblocks(unblocks: Map<String, Long>): Boolean {
        val copy = unblocks.toMap()
        val previous = unblockUntilByPackage.get()
        if (previous == copy) return false

        unblockUntilByPackage.set(copy)
        val ctx = appContext.get() ?: return true
        val prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val editor = prefs.edit()
        for ((key, _) in prefs.all) {
            if (key.startsWith(KEY_PREFIX)) {
                editor.remove(key)
            }
        }
        for ((pkg, untilMs) in copy) {
            editor.putLong(KEY_PREFIX + pkg, untilMs)
        }
        editor.apply()
        return true
    }

    fun clear() {
        setTemporaryUnblocks(emptyMap())
    }

    fun hasTrackedPackages(): Boolean {
        return unblockUntilByPackage.get().isNotEmpty()
    }

    fun hasActiveUnblocks(nowMs: Long = System.currentTimeMillis()): Boolean {
        return unblockUntilByPackage.get().values.any { it > nowMs }
    }

    /**
     * True when [packageName] had a temporary unblock window that has ended.
     */
    fun isUnblockExpired(
        packageName: String,
        nowMs: Long = System.currentTimeMillis(),
    ): Boolean {
        val until = unblockUntilByPackage.get()[packageName] ?: return false
        return nowMs >= until
    }

    fun shouldEnforceAfterUnblockExpiry(
        packageName: String,
        nowMs: Long = System.currentTimeMillis(),
    ): Boolean = isUnblockExpired(packageName, nowMs)

    fun unblockUntil(packageName: String): Long? =
        unblockUntilByPackage.get()[packageName]
}
