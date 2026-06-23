package com.screentime.screen_time_controller

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.util.Log
import java.util.Calendar
import java.util.concurrent.TimeUnit

/**
 * Runs at midnight to auto-move apps with > 3 hours of usage from the
 * previous day into the Distracting folder. No user notification is shown.
 *
 * Uses a "pending auto-move" store so that even if the app is open and
 * Flutter's sync overwrites native state, the moved apps are re-applied
 * on the next sync via [BlockingMethodChannel].
 */
class MidnightAutoMoveReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != ACTION_MIDNIGHT_AUTO_MOVE) return

        val appContext = context.applicationContext
        MidnightAutoMoveStore.init(appContext)

        val today = todayLocalDate()
        if (MidnightAutoMoveStore.hasRunFor(today)) {
            Log.d(TAG, "Midnight auto-move already ran for $today — skipping")
            return
        }

        Log.d(TAG, "Midnight auto-move triggered — processing yesterday's usage")
        processAndMoveHeavyApps(appContext)
        MidnightAutoMoveStore.markRunFor(today)

        rescheduleMidnight(appContext)
    }

    private fun todayLocalDate(): String {
        val cal = Calendar.getInstance()
        return "${cal.get(Calendar.YEAR)}-${cal.get(Calendar.MONTH) + 1}-${cal.get(Calendar.DAY_OF_MONTH)}"
    }

    private fun yesterdayDate(): Triple<Int, Int, Int> {
        val cal = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, -1) }
        return Triple(cal.get(Calendar.YEAR), cal.get(Calendar.MONTH) + 1, cal.get(Calendar.DAY_OF_MONTH))
    }

    private fun processAndMoveHeavyApps(context: Context) {
        val (year, month, day) = yesterdayDate()

        val usage = try {
            UsageStatsHelper.getDayApps(context, year, month, day) ?: emptyList()
        } catch (e: Exception) {
            Log.w(TAG, "Failed to fetch yesterday's usage: ${e.message}")
            return
        }

        val thresholdMs = TimeUnit.HOURS.toMillis(3)
        val heavyApps = usage.filter { (it["usageMs"] as? Number)?.toLong() ?: 0L > thresholdMs }

        Log.i(TAG, "Found ${heavyApps.size} apps with >3h usage yesterday: ${
            heavyApps.map { it["name"] as String }.joinToString(", ")
        }")

        if (heavyApps.isEmpty()) return

        moveHeavyAppsToDistracting(context, heavyApps)
    }

    private fun moveHeavyAppsToDistracting(
        context: Context,
        heavyApps: List<Map<String, Any>>,
    ) {
        val folderPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val FOLDER_PREFS_KEY = "flutter.folder_apps"
        val blockPrefs = context.getSharedPreferences("app_blocking", Context.MODE_PRIVATE)
        val pendingPrefs = context.getSharedPreferences("midnight_auto_move", Context.MODE_PRIVATE)
        val PENDING_KEY = "pending_auto_moved"

        val existingFolderJson = folderPrefs.getString(FOLDER_PREFS_KEY, null) ?: return
        val existingDistracting = mutableSetOf<String>()
        val appNames = mutableMapOf<String, String>()
        var alwaysAllowedArray: org.json.JSONArray? = null
        var neverAllowedArray: org.json.JSONArray? = null

        try {
            val decoded = org.json.JSONObject(existingFolderJson)
            val distractingArray = decoded.optJSONArray("distracting") ?: return
            for (i in 0 until distractingArray.length()) {
                val obj = distractingArray.getJSONObject(i)
                val pkg = obj.optString("packageName")
                val name = obj.optString("appName")
                if (pkg.isNotEmpty()) {
                    existingDistracting.add(pkg)
                    appNames[pkg] = name
                }
            }
            alwaysAllowedArray = decoded.optJSONArray("alwaysAllowed")
            neverAllowedArray = decoded.optJSONArray("neverAllowed")
        } catch (e: Exception) {
            Log.w(TAG, "Failed to parse existing folder apps: ${e.message}")
            return
        }

        val addedPackages = mutableSetOf<String>()
        for (app in heavyApps) {
            val pkg = app["package"] as? String ?: continue
            val name = app["name"] as? String ?: pkg
            if (!existingDistracting.contains(pkg)) {
                existingDistracting.add(pkg)
                appNames[pkg] = name
                addedPackages.add(pkg)
            }
        }

        if (addedPackages.isEmpty()) {
            Log.d(TAG, "No new apps to add — all heavy apps already in distracting folder")
            return
        }

        val updatedArray = org.json.JSONArray()
        for (pkg in existingDistracting) {
            updatedArray.put(
                org.json.JSONObject().apply {
                    put("packageName", pkg)
                    put("appName", appNames[pkg] ?: pkg)
                    val cal = Calendar.getInstance()
                    put("addedAt", "${cal.get(Calendar.YEAR)}-${cal.get(Calendar.MONTH) + 1}-${cal.get(Calendar.DAY_OF_MONTH)}")
                }
            )
        }

        val updatedJson = org.json.JSONObject()
            .put("distracting", updatedArray)
            .put(
                "alwaysAllowed",
                alwaysAllowedArray ?: org.json.JSONArray(),
            )
            .put(
                "neverAllowed",
                neverAllowedArray ?: org.json.JSONArray(),
            )
            .toString()

        folderPrefs.edit().putString(FOLDER_PREFS_KEY, updatedJson).apply()
        Log.i(TAG, "Updated FlutterSharedPreferences with ${addedPackages.size} new distracting apps")

        val existingPending = pendingPrefs.getStringSet(PENDING_KEY, emptySet()) ?: emptySet()
        val updatedPending = existingPending + addedPackages
        pendingPrefs.edit().putStringSet(PENDING_KEY, updatedPending).apply()
        Log.i(TAG, "Stored ${addedPackages.size} packages in pending auto-move set")
    }

    companion object {
        const val TAG = "MidnightAutoMove"
        const val ACTION_MIDNIGHT_AUTO_MOVE = "com.screentime.screen_time_controller.MIDNIGHT_AUTO_MOVE"
        private const val ALARM_REQUEST_CODE = 9001

        fun scheduleMidnight(context: Context) {
            val appContext = context.applicationContext
            MidnightAutoMoveStore.init(appContext)

            val intent = Intent(appContext, MidnightAutoMoveReceiver::class.java).apply {
                action = ACTION_MIDNIGHT_AUTO_MOVE
            }

            val pendingIntent = PendingIntent.getBroadcast(
                appContext,
                ALARM_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag(),
            )

            val alarmManager = appContext.getSystemService(Context.ALARM_SERVICE) as AlarmManager

            val now = System.currentTimeMillis()
            val nextMidnight = nextMidnightMillis(now)

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        nextMidnight,
                        pendingIntent,
                    )
                } else {
                    alarmManager.setExact(
                        AlarmManager.RTC_WAKEUP,
                        nextMidnight,
                        pendingIntent,
                    )
                }
                Log.d(TAG, "Scheduled midnight alarm for ${java.text.SimpleDateFormat.getDateTimeInstance().format(java.util.Date(nextMidnight))}")
            } catch (e: SecurityException) {
                Log.w(TAG, "Cannot schedule exact alarm — SCHEDULE_EXACT_ALARM may be missing: ${e.message}")
                try {
                    alarmManager.set(
                        AlarmManager.RTC_WAKEUP,
                        nextMidnight,
                        pendingIntent,
                    )
                } catch (e2: Exception) {
                    Log.e(TAG, "Failed to schedule fallback alarm: ${e2.message}")
                }
            }
        }

        fun rescheduleMidnight(context: Context) {
            scheduleMidnight(context)
        }

        private fun nextMidnightMillis(fromMillis: Long): Long {
            val cal = Calendar.getInstance().apply {
                timeInMillis = fromMillis
                add(Calendar.DAY_OF_YEAR, 1)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            return cal.timeInMillis
        }

        private fun immutableFlag(): Int {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE
            } else {
                0
            }
        }
    }
}
