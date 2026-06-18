package com.screentime.screen_time_controller

import android.content.Context
import java.util.concurrent.atomic.AtomicReference

object BlockedDomainsStore {
    private const val PREFS_NAME = "app_blocking"
    private const val KEY_BLOCKED_DOMAINS = "blocked_domains"

    private val appContext = AtomicReference<Context?>(null)
    private val blockedDomains = AtomicReference<Set<String>>(emptySet())

    fun init(context: Context) {
        appContext.set(context.applicationContext)
        loadFromPrefs()
    }

    private fun loadFromPrefs() {
        val ctx = appContext.get() ?: return
        val prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val stored = prefs.getStringSet(KEY_BLOCKED_DOMAINS, emptySet()) ?: emptySet()
        blockedDomains.set(stored)
    }

    fun setBlockedDomains(domains: Set<String>): Boolean {
        val copy = domains.map { it.lowercase() }.toSet()
        val previous = blockedDomains.get()
        if (previous == copy) return false

        blockedDomains.set(copy)
        val ctx = appContext.get() ?: return true
        ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putStringSet(KEY_BLOCKED_DOMAINS, copy)
            .apply()
        return true
    }

    fun isBlocked(hostname: String): Boolean {
        val host = normalizeHost(hostname)
        val blocked = blockedDomains.get()
        return blocked.any { domain ->
            host == domain || host.endsWith(".$domain")
        }
    }

    fun hasBlockedDomains(): Boolean = blockedDomains.get().isNotEmpty()

    private fun normalizeHost(hostname: String): String {
        var host = hostname.trim().lowercase()
        if (host.startsWith("www.")) {
            host = host.removePrefix("www.")
        }
        return host
    }
}
