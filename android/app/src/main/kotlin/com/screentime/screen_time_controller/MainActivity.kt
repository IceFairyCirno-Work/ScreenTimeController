package com.screentime.screen_time_controller

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "com.screentime.screen_time_controller/usage_data"
    private val permissionsChannelName =
        "com.screentime.screen_time_controller/permissions"

    private var pendingNotificationResult: MethodChannel.Result? = null

    // Recreated after onDestroy so a resumed activity never reuses a shut-down pool.
    private var backgroundExecutor: ExecutorService? = null

    private fun executor(): ExecutorService {
        val existing = backgroundExecutor
        if (existing != null && !existing.isShutdown) return existing
        return Executors.newSingleThreadExecutor { r ->
            Thread(r, "usage-bg").apply { isDaemon = true }
        }.also { backgroundExecutor = it }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        BlockedPackagesStore.init(this)
        BlockedAppStatsStore.init(this)
        DistractingPackagesStore.init(this)
        BlockingMethodChannel.register(flutterEngine.dartExecutor.binaryMessenger, this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasUsagePermission" -> {
                        executor().execute {
                            try {
                                replySuccessOnMain(
                                    result,
                                    UsageStatsHelper.hasUsagePermission(this),
                                )
                            } catch (e: Exception) {
                                replyErrorOnMain(result, "PERMISSION_ERROR", e.message)
                            }
                        }
                    }
                    "openUsageSettings" -> {
                        UsageStatsHelper.openUsagePermissionSettings(this)
                        result.success(null)
                    }
                    "getUsageData" -> {
                        executor().execute {
                            try {
                                val data = UsageStatsHelper.getUsageData(this)
                                replySuccessOnMain(result, data)
                            } catch (e: Exception) {
                                replyErrorOnMain(result, "USAGE_ERROR", e.message)
                            }
                        }
                    }
                    "getAppIcon" -> {
                        val packageName = call.argument<String>("packageName")
                        if (packageName.isNullOrBlank()) {
                            result.error("INVALID_ARGUMENT", "packageName is required", null)
                        } else {
                            executor().execute {
                                try {
                                    replySuccessOnMain(
                                        result,
                                        UsageStatsHelper.getAppIcon(this, packageName),
                                    )
                                } catch (e: Exception) {
                                    replyErrorOnMain(result, "ICON_ERROR", e.message)
                                }
                            }
                        }
                    }
                    "getInstalledApps" -> {
                        executor().execute {
                            try {
                                replySuccessOnMain(
                                    result,
                                    UsageStatsHelper.getInstalledApps(this),
                                )
                            } catch (e: Exception) {
                                replyErrorOnMain(result, "INSTALLED_APPS_ERROR", e.message)
                            }
                        }
                    }
                    "getDayTotalMs" -> {
                        val year = call.argument<Int>("year")
                        val month = call.argument<Int>("month")
                        val day = call.argument<Int>("day")
                        if (year == null || month == null || day == null) {
                            result.error(
                                "INVALID_ARGUMENT",
                                "year, month, and day are required",
                                null,
                            )
                        } else {
                            executor().execute {
                                try {
                                    replySuccessOnMain(
                                        result,
                                        UsageStatsHelper.getDayTotalMs(
                                            this,
                                            year,
                                            month,
                                            day,
                                        ),
                                    )
                                } catch (e: Exception) {
                                    replyErrorOnMain(result, "DAY_TOTAL_ERROR", e.message)
                                }
                            }
                        }
                    }
                    "getBlockedAppTodayStats" -> {
                        val packageName = call.argument<String>("packageName")
                        if (packageName.isNullOrBlank()) {
                            result.error("INVALID_ARGUMENT", "packageName is required", null)
                        } else {
                            executor().execute {
                                try {
                                    replySuccessOnMain(
                                        result,
                                        UsageStatsHelper.getBlockedAppTodayStats(this, packageName),
                                    )
                                } catch (e: Exception) {
                                    replyErrorOnMain(result, "BLOCKED_APP_STATS_ERROR", e.message)
                                }
                            }
                        }
                    }
                    "getOpensSince" -> {
                        val packageName = call.argument<String>("packageName")
                        val sinceMillis = call.argument<Number>("sinceMillis")?.toLong()
                        if (packageName.isNullOrBlank() || sinceMillis == null) {
                            result.error(
                                "INVALID_ARGUMENT",
                                "packageName and sinceMillis are required",
                                null,
                            )
                        } else {
                            executor().execute {
                                try {
                                    replySuccessOnMain(
                                        result,
                                        UsageStatsHelper.getOpensSince(
                                            this,
                                            packageName,
                                            sinceMillis,
                                        ),
                                    )
                                } catch (e: Exception) {
                                    replyErrorOnMain(result, "OPENS_SINCE_ERROR", e.message)
                                }
                            }
                        }
                    }
                    "recordAppUnblock" -> {
                        val packageName = call.argument<String>("packageName")
                        if (packageName.isNullOrBlank()) {
                            result.error("INVALID_ARGUMENT", "packageName is required", null)
                        } else {
                            executor().execute {
                                try {
                                    BlockedAppStatsStore.recordUnblock(this, packageName)
                                    replySuccessOnMain(result, null)
                                } catch (e: Exception) {
                                    replyErrorOnMain(result, "RECORD_UNBLOCK_ERROR", e.message)
                                }
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, permissionsChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasOverlayPermission" -> {
                        result.success(PermissionsHelper.hasOverlayPermission(this))
                    }
                    "openOverlaySettings" -> {
                        PermissionsHelper.openOverlaySettings(this)
                        result.success(null)
                    }
                    "hasAccessibilityPermission" -> {
                        result.success(PermissionsHelper.hasAccessibilityPermission(this))
                    }
                    "openAccessibilitySettings" -> {
                        PermissionsHelper.openAccessibilitySettings(this)
                        result.success(null)
                    }
                    "hasNotificationPermission" -> {
                        result.success(PermissionsHelper.hasNotificationPermission(this))
                    }
                    "requestNotificationPermission" -> {
                        requestNotificationPermission(result)
                    }
                    "openNotificationSettings" -> {
                        PermissionsHelper.openNotificationSettings(this)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onResume() {
        super.onResume()
        // After Samsung / aggressive OEMs tear down the window, clear the launch
        // theme background so a resumed Flutter surface is visible immediately.
        if (flutterEngine != null) {
            window.decorView.post { window.setBackgroundDrawable(null) }
        }
    }

    override fun onDestroy() {
        clearPendingNotificationResult(granted = false)
        backgroundExecutor?.shutdownNow()
        backgroundExecutor = null
        super.onDestroy()
    }

    private fun clearPendingNotificationResult(granted: Boolean) {
        val pending = pendingNotificationResult ?: return
        pendingNotificationResult = null
        replySuccessOnMain(pending, granted)
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(PermissionsHelper.hasNotificationPermission(this))
            return
        }

        if (PermissionsHelper.hasNotificationPermission(this)) {
            result.success(true)
            return
        }

        pendingNotificationResult?.let { stale ->
            replySuccessOnMain(stale, false)
        }
        pendingNotificationResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST_CODE,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode != NOTIFICATION_PERMISSION_REQUEST_CODE) return

        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        clearPendingNotificationResult(granted)
    }

    private fun canReplyToChannel(): Boolean = !isFinishing && !isDestroyed

    private fun replySuccessOnMain(result: MethodChannel.Result, value: Any?) {
        runOnUiThread {
            if (!canReplyToChannel()) return@runOnUiThread
            try {
                result.success(value)
            } catch (_: Exception) {
                // Channel already closed or result already submitted.
            }
        }
    }

    private fun replyErrorOnMain(result: MethodChannel.Result, code: String, message: String?) {
        runOnUiThread {
            if (!canReplyToChannel()) return@runOnUiThread
            try {
                result.error(code, message, null)
            } catch (e: Exception) {
                Log.w(TAG, "Failed to reply on channel: ${e.message}")
            }
        }
    }

    companion object {
        private const val TAG = "SiloMainActivity"
        private const val NOTIFICATION_PERMISSION_REQUEST_CODE = 1001
    }
}
