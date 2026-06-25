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
 * Uses a pending queue ([MidnightAutoMovePendingStore]) so Flutter persists
 * folder changes safely via SharedPreferences instead of native overwrites.
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
        val existingDistracting = readExistingDistractingPackages(context)
        val addedApps = mutableListOf<Pair<String, String>>()

        for (app in heavyApps) {
            val pkg = app["package"] as? String ?: continue
            val name = app["name"] as? String ?: pkg
            if (!existingDistracting.contains(pkg)) {
                addedApps.add(pkg to name)
            }
        }

        if (addedApps.isEmpty()) {
            Log.d(TAG, "No new apps to add — all heavy apps already in distracting folder")
            return
        }

        MidnightAutoMovePendingStore.addApps(context, addedApps)
        Log.i(TAG, "Queued ${addedApps.size} apps for Flutter to add to distracting folder")
    }

    private fun readExistingDistractingPackages(context: Context): Set<String> {
        val folderPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val existingFolderJson = folderPrefs.getString("flutter.folder_apps", null) ?: return emptySet()

        val packages = mutableSetOf<String>()
        try {
            val decoded = org.json.JSONObject(existingFolderJson)
            val distractingArray = decoded.optJSONArray("distracting") ?: return emptySet()
            for (i in 0 until distractingArray.length()) {
                val pkg = distractingArray.getJSONObject(i).optString("packageName")
                if (pkg.isNotEmpty()) packages.add(pkg)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to read existing distracting packages: ${e.message}")
        }
        return packages
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
