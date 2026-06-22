package com.screentime.screen_time_controller

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.atomic.AtomicReference

/**
 * Schedule (session) rules synced from Flutter. Evaluated natively so a rule
 * that becomes active while the user stays in a tracked app still enforces
 * without Flutter running in the foreground.
 */
object SessionScheduleRulesStore {
    data class Entry(
        val packageName: String,
        val startHour: Int,
        val startMinute: Int,
        val endHour: Int,
        val endMinute: Int,
        val repeatDays: Set<Int>,
        val disabledUntilMs: Long,
    ) {
        fun isDisabled(nowMs: Long): Boolean =
            disabledUntilMs > 0L && disabledUntilMs > nowMs
    }

    private const val PREFS_NAME = "app_blocking"
    private const val KEY_ENTRIES_JSON = "session_schedule_rules_json"

    private val appContext = AtomicReference<Context?>(null)
    private val entries = AtomicReference<List<Entry>>(emptyList())

    @Volatile
    var onRulesUpdated: (() -> Unit)? = null

    fun init(context: Context) {
        appContext.set(context.applicationContext)
        loadFromPrefs()
    }

    private fun loadFromPrefs() {
        val ctx = appContext.get() ?: return
        val raw = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_ENTRIES_JSON, null) ?: return
        runCatching {
            parseEntriesJson(raw)
        }.onSuccess { parsed ->
            entries.set(parsed)
        }
    }

    fun setEntries(newEntries: List<Entry>): Boolean {
        val copy = newEntries.toList()
        if (entries.get() == copy) return false

        entries.set(copy)
        persistEntries(copy)
        onRulesUpdated?.invoke()
        return true
    }

    fun hasEnabledRules(nowMs: Long = System.currentTimeMillis()): Boolean =
        entries.get().any { !it.isDisabled(nowMs) }

    fun entriesFor(packageName: String): List<Entry> =
        entries.get().filter { it.packageName == packageName }

    private fun persistEntries(list: List<Entry>) {
        val ctx = appContext.get() ?: return
        val json = JSONArray()
        for (entry in list) {
            json.put(
                JSONObject().apply {
                    put("packageName", entry.packageName)
                    put("startHour", entry.startHour)
                    put("startMinute", entry.startMinute)
                    put("endHour", entry.endHour)
                    put("endMinute", entry.endMinute)
                    put("repeatDays", JSONArray(entry.repeatDays.toList()))
                    put("disabledUntilMs", entry.disabledUntilMs)
                },
            )
        }
        ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_ENTRIES_JSON, json.toString())
            .apply()
    }

    private fun parseEntriesJson(raw: String): List<Entry> {
        val array = JSONArray(raw)
        val result = mutableListOf<Entry>()
        for (i in 0 until array.length()) {
            val obj = array.getJSONObject(i)
            val repeatArray = obj.getJSONArray("repeatDays")
            val repeatDays = mutableSetOf<Int>()
            for (j in 0 until repeatArray.length()) {
                repeatDays.add(repeatArray.getInt(j))
            }
            result.add(
                Entry(
                    packageName = obj.getString("packageName"),
                    startHour = obj.getInt("startHour"),
                    startMinute = obj.getInt("startMinute"),
                    endHour = obj.getInt("endHour"),
                    endMinute = obj.getInt("endMinute"),
                    repeatDays = repeatDays,
                    disabledUntilMs = obj.optLong("disabledUntilMs", 0L),
                ),
            )
        }
        return result
    }
}
