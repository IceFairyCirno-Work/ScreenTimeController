package com.screentime.screen_time_controller

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import android.util.Base64
import java.util.Calendar
import kotlin.math.max
import kotlin.math.min

/**
 * Single source of truth for Android screen-time data.
 *
 * Today per-app usage is derived exclusively from foreground/background event
 * transitions (the same accounting Android's Digital Wellbeing uses). The
 * aggregate [UsageStats.totalTimeInForeground] is NOT merged into per-app
 * totals, because it can inflate usage via Picture-in-Picture, split-screen,
 * and stale stats buckets — causing the app to over-report vs. the device.
 */
object UsageStatsHelper {
    const val MIN_USAGE_MS = 60_000L

    private val packageDenylist = setOf(
        "com.android.systemui",
        "com.android.launcher",
        "com.android.launcher3",
        "com.google.android.apps.nexuslauncher",
        "com.sec.android.app.launcher",
        "com.miui.home",
        "com.huawei.android.launcher",
        "com.oppo.launcher",
        "com.android.settings",
        "com.google.android.inputmethod.latin",
        "com.samsung.android.honeyboard",
    )

    fun hasUsagePermission(context: Context): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            context.packageName,
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    fun openUsagePermissionSettings(context: Context) {
        if (hasUsagePermission(context)) return
        try {
            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                data = Uri.parse("package:${context.packageName}")
            }
            context.startActivity(intent)
        } catch (_: Exception) {
            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(intent)
        }
    }

    fun getUsageData(context: Context): Map<String, Any?> {
        if (!hasUsagePermission(context)) {
            return emptyUsagePayload()
        }

        val endTime = System.currentTimeMillis()
        val startOfToday = startOfLocalDayMillis()
        val startOfWeek = startOfLocalWeekMillis()

        val todayFromEvents = UsageEventProcessor(
            context = context,
            startTime = startOfToday,
            endTime = endTime,
            clipToNightHours = false,
        ).computePerPackage()

        val apps = buildAppEntries(context, todayFromEvents)
        val todayTotalMs = computeEventDayTotal(context, todayFromEvents)

        val weekFromEvents = UsageEventProcessor(
            context = context,
            startTime = startOfWeek,
            endTime = endTime,
            clipToNightHours = false,
        ).computePerPackage()
        val weekTotalMs = computeEventDayTotal(context, weekFromEvents)

        val nightTotals = UsageEventProcessor(
            context = context,
            startTime = startOfToday,
            endTime = endTime,
            clipToNightHours = true,
        ).computePerPackage()
        val nightUsageMinutes = (nightTotals.values.sum() / 60_000L)
            .toInt()
            .coerceIn(0, 480)

        return mapOf(
            "todayTotalMs" to todayTotalMs,
            "weekTotalMs" to weekTotalMs,
            "nightUsageMinutes" to nightUsageMinutes,
            "apps" to apps,
        )
    }

    fun getAppIcon(context: Context, packageName: String): ByteArray? {
        return try {
            val drawable = context.packageManager.getApplicationIcon(packageName)
            drawableToPngBytes(drawable)
        } catch (_: PackageManager.NameNotFoundException) {
            null
        }
    }

    /**
     * Returns apps the user can actually open from their home screen.
     *
     * Two filters are AND-combined to be strict:
     * 1. The package exposes a launcher activity (it would show in the app
     *    drawer), AND
     * 2. It is not a pure system app (updated system apps like Chrome / Gboard
     *    are kept). This excludes OEM utility packages (e.g. "Galaxy Resource
     *    Updater") that ship with a launcher intent but aren't user apps.
     *
     * Each entry carries today's foreground usage so the picker can show
     * "time spent today" labels.
     */
    /**
     * Today's per-app metrics for the blocked-app detail screen: foreground opens,
     * foreground usage, and user-initiated unblock count.
     */
    fun getBlockedAppTodayStats(context: Context, packageName: String): Map<String, Any?> {
        val unblocks = BlockedAppStatsStore.getUnblockCount(context, packageName)
        if (!hasUsagePermission(context)) {
            return mapOf(
                "opens" to 0,
                "usageMs" to 0L,
                "unblocks" to unblocks,
            )
        }

        val usageMs = getTodayUsageMs(context, packageName)
        val startOfToday = startOfLocalDayMillis()
        val endTime = System.currentTimeMillis()
        val opens = countForegroundOpens(context, packageName, startOfToday, endTime)

        return mapOf(
            "opens" to opens,
            "usageMs" to usageMs,
            "unblocks" to unblocks,
        )
    }

    /**
     * Filtered total foreground screen time for one local calendar day.
     * Returns null when usage permission is not granted.
     */
    fun getDayTotalMs(
        context: Context,
        year: Int,
        month: Int,
        dayOfMonth: Int,
    ): Long? {
        if (!hasUsagePermission(context)) return null

        val cal = Calendar.getInstance().apply {
            set(Calendar.YEAR, year)
            set(Calendar.MONTH, month - 1)
            set(Calendar.DAY_OF_MONTH, dayOfMonth)
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val startTime = cal.timeInMillis
        cal.add(Calendar.DAY_OF_MONTH, 1)
        val endTime = min(cal.timeInMillis, System.currentTimeMillis())
        if (startTime >= endTime) return 0L

        val totals = UsageEventProcessor(
            context = context,
            startTime = startTime,
            endTime = endTime,
            clipToNightHours = false,
        ).computePerPackage()

        return computeEventDayTotal(context, totals)
    }

    fun getTodayUsageMs(context: Context, packageName: String): Long {
        if (!hasUsagePermission(context)) return 0L
        val startOfToday = startOfLocalDayMillis()
        val endTime = System.currentTimeMillis()
        return UsageEventProcessor(
            context = context,
            startTime = startOfToday,
            endTime = endTime,
            clipToNightHours = false,
        ).computePerPackage().getOrDefault(packageName, 0L)
    }

    fun getOpensSince(
        context: Context,
        packageName: String,
        sinceMillis: Long,
    ): Int {
        if (!hasUsagePermission(context)) return 0
        val endTime = System.currentTimeMillis()
        val startTime = max(sinceMillis, startOfLocalDayMillis())
        if (startTime >= endTime) return 0
        return countForegroundOpens(context, packageName, startTime, endTime)
    }

    fun getInstalledApps(context: Context): List<Map<String, Any>> {
        val pm = context.packageManager
        val ownPackage = context.packageName

        val todayUsage = UsageEventProcessor(
            context = context,
            startTime = startOfLocalDayMillis(),
            endTime = System.currentTimeMillis(),
            clipToNightHours = false,
        ).computePerPackage()

        val packages = pm.getInstalledApplications(0)
            .filter { info ->
                val pkg = info.packageName
                pkg != ownPackage &&
                    !packageDenylist.contains(pkg) &&
                    shouldIncludePackage(pm, pkg) &&
                    pm.getLaunchIntentForPackage(pkg) != null
            }

        return packages
            .map { info ->
                val pkg = info.packageName
                val iconB64 = try {
                    val drawable = pm.getApplicationIcon(info)
                    Base64.encodeToString(drawableToPngBytes(drawable), Base64.NO_WRAP)
                } catch (_: Exception) {
                    null
                }
                buildMap {
                    put("package", pkg)
                    put("name", pm.getApplicationLabel(info).toString())
                    put("usageMs", todayUsage.getOrDefault(pkg, 0L))
                    if (iconB64 != null) put("iconBase64", iconB64)
                }
            }
            .sortedBy { (it["name"] as String).lowercase() }
    }

    private fun emptyUsagePayload(): Map<String, Any?> = mapOf(
        "todayTotalMs" to 0L,
        "weekTotalMs" to 0L,
        "nightUsageMinutes" to 0,
        "apps" to emptyList<Map<String, Any>>(),
    )

    private fun startOfLocalDayMillis(): Long {
        return Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
    }

    private fun startOfLocalWeekMillis(): Long {
        return Calendar.getInstance().apply {
            firstDayOfWeek = Calendar.MONDAY
            set(Calendar.DAY_OF_WEEK, Calendar.MONDAY)
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
    }

    private fun countForegroundOpens(
        context: Context,
        packageName: String,
        startTime: Long,
        endTime: Long,
    ): Int {
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events = usm.queryEvents(startTime, endTime) ?: return 0

        var count = 0
        var inForeground = false
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.packageName != packageName) continue

            when (event.eventType) {
                UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                    count++
                    inForeground = true
                }
                UsageEvents.Event.ACTIVITY_RESUMED -> {
                    if (!inForeground) {
                        count++
                        inForeground = true
                    }
                }
                UsageEvents.Event.MOVE_TO_BACKGROUND,
                UsageEvents.Event.ACTIVITY_PAUSED,
                -> {
                    inForeground = false
                }
            }
        }
        return count
    }

    private fun queryAggregateForeground(
        context: Context,
        startTime: Long,
        endTime: Long,
    ): Map<String, Long> {
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val aggregated = usm.queryAndAggregateUsageStats(startTime, endTime) ?: return emptyMap()
        return aggregated.mapValues { (_, stats) -> stats.totalTimeInForeground }
    }

    private fun computeFilteredAggregateTotal(
        context: Context,
        startTime: Long,
        endTime: Long,
    ): Long {
        val pm = context.packageManager
        val ownPackage = context.packageName
        return queryAggregateForeground(context, startTime, endTime)
            .entries
            .filter { (pkg, ms) ->
                ms >= MIN_USAGE_MS &&
                    pkg != ownPackage &&
                    !packageDenylist.contains(pkg) &&
                    shouldIncludePackage(pm, pkg)
            }
            .sumOf { it.value }
    }

    /**
     * Event-based daily total — sums all tracked foreground time for user apps.
     * Unlike [buildAppEntries], does not require each app to exceed [MIN_USAGE_MS].
     */
    private fun computeEventDayTotal(
        context: Context,
        totals: Map<String, Long>,
    ): Long {
        val pm = context.packageManager
        val ownPackage = context.packageName
        return totals.entries
            .filter { (pkg, ms) ->
                ms > 0L &&
                    pkg != ownPackage &&
                    !packageDenylist.contains(pkg) &&
                    shouldIncludePackage(pm, pkg)
            }
            .sumOf { it.value }
    }

    private fun buildAppEntries(
        context: Context,
        totals: Map<String, Long>,
    ): List<Map<String, Any>> {
        val pm = context.packageManager
        val ownPackage = context.packageName

        return totals.entries
            .filter { (pkg, ms) ->
                ms >= MIN_USAGE_MS &&
                    pkg != ownPackage &&
                    !packageDenylist.contains(pkg) &&
                    shouldIncludePackage(pm, pkg)
            }
            .sortedByDescending { it.value }
            .map { (pkg, ms) ->
                mapOf(
                    "package" to pkg,
                    "name" to resolveAppName(pm, pkg),
                    "usageMs" to ms,
                )
            }
    }

    private fun shouldIncludePackage(pm: PackageManager, packageName: String): Boolean {
        return try {
            val info = pm.getApplicationInfo(packageName, 0)
            val isSystem = info.flags and ApplicationInfo.FLAG_SYSTEM != 0
            val isUpdatedSystem = info.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP != 0
            when {
                !isSystem -> true
                isUpdatedSystem -> true
                else -> isWhitelistedPreinstalledSystemApp(packageName)
            }
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }
    }

    /** Pre-installed system apps users actually open (Play / Chrome / YouTube). */
    private fun isWhitelistedPreinstalledSystemApp(packageName: String): Boolean {
        return packageName.contains("chrome") ||
            packageName.contains("youtube") ||
            packageName.contains("vending")
    }

    private fun resolveAppName(pm: PackageManager, packageName: String): String {
        return try {
            val info = pm.getApplicationInfo(packageName, 0)
            pm.getApplicationLabel(info).toString()
        } catch (_: PackageManager.NameNotFoundException) {
            packageName.substringAfterLast('.')
        }
    }

    private fun drawableToPngBytes(drawable: Drawable): ByteArray {
        val bitmap = if (drawable is BitmapDrawable && drawable.bitmap != null) {
            drawable.bitmap
        } else {
            val width = drawable.intrinsicWidth.takeIf { it > 0 } ?: 1
            val height = drawable.intrinsicHeight.takeIf { it > 0 } ?: 1
            val bmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            bmp
        }
        val stream = java.io.ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
        return stream.toByteArray()
    }

    /**
     * Walks usage events and accumulates foreground durations per package.
     * Sessions are tracked per activity so a background [ACTIVITY_RESUMED]
     * from Gallery or a photo-picker flow does not steal the foreground slot
     * from the app the user is actually using.
     */
    private class UsageEventProcessor(
        private val context: Context,
        private val startTime: Long,
        private val endTime: Long,
        private val clipToNightHours: Boolean,
    ) {
        private val activitySessions = mutableMapOf<String, Long>()
        private val totals = mutableMapOf<String, Long>()

        fun computePerPackage(): Map<String, Long> {
            val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val events = usm.queryEvents(startTime, endTime) ?: return emptyMap()

            val event = UsageEvents.Event()
            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                handleEvent(event)
            }

            closeOpenSessions()
            return totals
        }

        private fun handleEvent(event: UsageEvents.Event) {
            val packageName = event.packageName ?: return
            if (packageDenylist.contains(packageName)) return
            if (!shouldIncludePackage(context.packageManager, packageName)) return

            val timestamp = event.timeStamp.coerceIn(startTime, endTime)
            val sessionKey = sessionKey(packageName, event)

            when (event.eventType) {
                UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                    activitySessions[sessionKey] = timestamp
                }
                UsageEvents.Event.ACTIVITY_RESUMED -> {
                    // Some OEMs emit RESUMED without MOVE_TO_FOREGROUND.
                    activitySessions.putIfAbsent(sessionKey, timestamp)
                }
                UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                    closeAllSessionsForPackage(packageName, timestamp)
                }
                UsageEvents.Event.ACTIVITY_PAUSED -> {
                    if (event.className.isNullOrEmpty()) {
                        closeAllSessionsForPackage(packageName, timestamp)
                    } else {
                        closeSession(sessionKey, packageName, timestamp)
                    }
                }
                UsageEvents.Event.ACTIVITY_STOPPED -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        closeSession(sessionKey, packageName, timestamp)
                    }
                }
            }
        }

        private fun sessionKey(packageName: String, event: UsageEvents.Event): String {
            val className = event.className
            if (className.isNullOrEmpty()) {
                return "$packageName::"
            }
            return "$packageName::$className"
        }

        private fun packageFromSessionKey(key: String): String {
            return key.substringBefore("::")
        }

        private fun closeSession(sessionKey: String, packageName: String, timestamp: Long) {
            val sessionStart = activitySessions.remove(sessionKey) ?: return
            addDuration(packageName, sessionStart, timestamp)
        }

        private fun closeAllSessionsForPackage(packageName: String, timestamp: Long) {
            val prefix = "$packageName::"
            val keys = activitySessions.keys.filter { it == prefix || it.startsWith(prefix) }
            for (key in keys) {
                closeSession(key, packageName, timestamp)
            }
        }

        private fun closeOpenSessions() {
            for ((key, sessionStart) in activitySessions.toList()) {
                addDuration(packageFromSessionKey(key), sessionStart, endTime)
            }
            activitySessions.clear()
        }

        private fun addDuration(packageName: String, sessionStart: Long, sessionEnd: Long) {
            if (sessionEnd <= sessionStart) return
            val duration = if (clipToNightHours) {
                nightDurationMs(sessionStart, sessionEnd)
            } else {
                sessionEnd - sessionStart
            }
            if (duration > 0L) {
                totals[packageName] = totals.getOrDefault(packageName, 0L) + duration
            }
        }

        /** Milliseconds between [startMs] and [endMs] that fall in 22:00–06:00 local time. */
        private fun nightDurationMs(startMs: Long, endMs: Long): Long {
            var total = 0L
            var cursor = startMs
            while (cursor < endMs) {
                val cal = Calendar.getInstance().apply { timeInMillis = cursor }
                val hour = cal.get(Calendar.HOUR_OF_DAY)
                if (hour >= 22 || hour < 6) {
                    val nextMinute = cursor + 60_000L
                    val segmentEnd = min(endMs, nextMinute)
                    total += segmentEnd - cursor
                    cursor = segmentEnd
                } else if (hour < 22) {
                    cal.set(Calendar.HOUR_OF_DAY, 22)
                    cal.set(Calendar.MINUTE, 0)
                    cal.set(Calendar.SECOND, 0)
                    cal.set(Calendar.MILLISECOND, 0)
                    cursor = max(cursor, cal.timeInMillis)
                } else {
                    cursor += 60_000L
                }
            }
            return total
        }
    }
}
