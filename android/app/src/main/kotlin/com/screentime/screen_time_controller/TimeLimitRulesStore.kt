package com.screentime.screen_time_controller

import android.content.Context
import java.util.concurrent.atomic.AtomicReference

/**
 * Time limit rules synced from Flutter. Evaluated natively so limits still
 * enforce while the user stays in a tracked app and Flutter is backgrounded.
 */
object TimeLimitRulesStore {
    data class Entry(
        val packageName: String,
        val allowedMs: Long,
        val baselineMs: Long,
        val blockUntilMs: Long,
        val blockUntilMidnight: Boolean,
        val limitExceededAtMs: Long,
        val ruleActive: Boolean,
    )

    private const val PREFS_NAME = "app_blocking"
    private const val KEY_EXCEEDED_PREFIX = "time_limit_exceeded_"

    private val appContext = AtomicReference<Context?>(null)
    private val entries = AtomicReference<List<Entry>>(emptyList())
    private val nativeExceededAtMs = AtomicReference<Map<String, Long>>(emptyMap())

    fun init(context: Context) {
        appContext.set(context.applicationContext)
        loadNativeExceededFromPrefs()
    }

    private fun loadNativeExceededFromPrefs() {
        val ctx = appContext.get() ?: return
        val prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val loaded = mutableMapOf<String, Long>()
        for ((key, value) in prefs.all) {
            if (!key.startsWith(KEY_EXCEEDED_PREFIX)) continue
            val ms = when (value) {
                is Long -> value
                is Int -> value.toLong()
                is Number -> value.toLong()
                else -> continue
            }
            loaded[key.removePrefix(KEY_EXCEEDED_PREFIX)] = ms
        }
        nativeExceededAtMs.set(loaded)
    }

    fun setEntries(newEntries: List<Entry>): Boolean {
        val copy = newEntries.toList()
        if (entries.get() == copy) return false
        entries.set(copy)

        val activePackages = copy.filter { it.ruleActive }.map { it.packageName }.toSet()
        val exceeded = nativeExceededAtMs.get().toMutableMap()
        exceeded.keys.retainAll(activePackages)
        nativeExceededAtMs.set(exceeded)
        persistNativeExceeded(exceeded)
        return true
    }

    fun hasActiveRules(): Boolean = entries.get().any { it.ruleActive }

    fun entriesFor(packageName: String): List<Entry> =
        entries.get().filter { it.packageName == packageName && it.ruleActive }

    fun resolvedExceededAt(packageName: String, flutterExceededAtMs: Long): Long {
        if (flutterExceededAtMs > 0L) return flutterExceededAtMs
        return nativeExceededAtMs.get()[packageName] ?: 0L
    }

    fun recordExceeded(packageName: String, atMs: Long) {
        val updated = nativeExceededAtMs.get().toMutableMap()
        if (updated[packageName] == atMs) return
        updated[packageName] = atMs
        nativeExceededAtMs.set(updated)
        persistNativeExceeded(updated)
    }

    private fun persistNativeExceeded(map: Map<String, Long>) {
        val ctx = appContext.get() ?: return
        val prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val editor = prefs.edit()
        for ((key, _) in prefs.all) {
            if (key.startsWith(KEY_EXCEEDED_PREFIX)) {
                editor.remove(key)
            }
        }
        for ((pkg, ms) in map) {
            editor.putLong(KEY_EXCEEDED_PREFIX + pkg, ms)
        }
        editor.apply()
    }
}
