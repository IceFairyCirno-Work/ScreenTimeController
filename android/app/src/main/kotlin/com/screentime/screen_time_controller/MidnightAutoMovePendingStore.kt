package com.screentime.screen_time_controller

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * Queues apps auto-moved at midnight until Flutter reads and persists them
 * into [folder_apps]. Native code must not write folder JSON directly —
 * that bypasses Flutter's SharedPreferences encoding and corrupts storage.
 */
object MidnightAutoMovePendingStore {
    private const val PREFS_NAME = "midnight_auto_move"
    private const val KEY_PENDING_APPS_JSON = "pending_auto_moved_apps"

    fun addApps(context: Context, apps: List<Pair<String, String>>) {
        if (apps.isEmpty()) return

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val merged = linkedMapOf<String, String>()

        readAppsJson(prefs.getString(KEY_PENDING_APPS_JSON, null)).forEach { (pkg, name) ->
            merged[pkg] = name
        }
        apps.forEach { (pkg, name) ->
            if (pkg.isNotEmpty()) merged[pkg] = name
        }

        prefs.edit()
            .putString(KEY_PENDING_APPS_JSON, encodeApps(merged))
            .apply()
    }

    fun pendingPackages(context: Context): Set<String> {
        return readAppsJson(
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .getString(KEY_PENDING_APPS_JSON, null),
        ).keys
    }

    fun consumePendingApps(context: Context): List<Map<String, String>> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val apps = readAppsJson(prefs.getString(KEY_PENDING_APPS_JSON, null))
        if (apps.isEmpty()) return emptyList()

        prefs.edit().remove(KEY_PENDING_APPS_JSON).apply()
        return apps.map { (pkg, name) ->
            mapOf("packageName" to pkg, "appName" to name)
        }
    }

    private fun readAppsJson(json: String?): LinkedHashMap<String, String> {
        if (json.isNullOrBlank()) return linkedMapOf()

        val result = linkedMapOf<String, String>()
        try {
            val array = JSONArray(json)
            for (i in 0 until array.length()) {
                val obj = array.getJSONObject(i)
                val pkg = obj.optString("packageName")
                val name = obj.optString("appName", pkg)
                if (pkg.isNotEmpty()) result[pkg] = name
            }
        } catch (_: Exception) {
            return linkedMapOf()
        }
        return result
    }

    private fun encodeApps(apps: Map<String, String>): String {
        val array = JSONArray()
        apps.forEach { (pkg, name) ->
            array.put(
                JSONObject()
                    .put("packageName", pkg)
                    .put("appName", name),
            )
        }
        return array.toString()
    }
}
