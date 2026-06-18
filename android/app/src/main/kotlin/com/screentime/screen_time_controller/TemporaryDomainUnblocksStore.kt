package com.screentime.screen_time_controller

import android.content.Context
import java.util.concurrent.atomic.AtomicReference

object TemporaryDomainUnblocksStore {
    private const val PREFS_NAME = "app_blocking"
    private const val KEY_PREFIX = "domain_unblock_until_"

    private val appContext = AtomicReference<Context?>(null)
    private val unblockUntilByDomain = AtomicReference<Map<String, Long>>(emptyMap())

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
        unblockUntilByDomain.set(loaded)
    }

    fun setTemporaryUnblocks(unblocks: Map<String, Long>): Boolean {
        val copy = unblocks.mapKeys { it.key.lowercase() }
        val previous = unblockUntilByDomain.get()
        if (previous == copy) return false

        unblockUntilByDomain.set(copy)
        val ctx = appContext.get() ?: return true
        val prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val editor = prefs.edit()
        for ((key, _) in prefs.all) {
            if (key.startsWith(KEY_PREFIX)) {
                editor.remove(key)
            }
        }
        for ((domain, untilMs) in copy) {
            editor.putLong(KEY_PREFIX + domain, untilMs)
        }
        editor.apply()
        return true
    }

    fun hasTrackedDomains(): Boolean = unblockUntilByDomain.get().isNotEmpty()

    fun isUnblockExpired(
        domain: String,
        nowMs: Long = System.currentTimeMillis(),
    ): Boolean {
        val until = unblockUntilByDomain.get()[domain.lowercase()] ?: return false
        return nowMs >= until
    }

    fun shouldEnforceAfterUnblockExpiry(
        domain: String,
        nowMs: Long = System.currentTimeMillis(),
    ): Boolean = isUnblockExpired(domain, nowMs)
}
