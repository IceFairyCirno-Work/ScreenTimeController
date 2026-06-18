package com.screentime.screen_time_controller

import android.content.Context
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.TextView
import java.util.Locale

/**
 * Floating awareness pill shown briefly when the user opens a distracting app.
 * Visible for [VISIBLE_DURATION_MS], then auto-hides. The timer shows today's
 * total foreground screen time, counting up live while the pill is shown.
 */
object DistractingOverlayManager {
    private const val TICK_MS = 1000L
    private const val VISIBLE_DURATION_MS = 10_000L
    private const val HORIZONTAL_PADDING_DP = 12
    private const val TOP_PADDING_DP = 8

    private val mainHandler = Handler(Looper.getMainLooper())

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var timerTextView: TextView? = null

    private var currentPackage: String? = null
    private var sessionStartMs: Long = 0L
    private var baselineMs: Long = 0L

    private val tickRunnable = object : Runnable {
        override fun run() {
            updateTimerDisplay()
            mainHandler.postDelayed(this, TICK_MS)
        }
    }

    private val hideRunnable = Runnable { hideInternal() }

    fun show(context: Context, packageName: String) {
        if (!PermissionsHelper.hasOverlayPermission(context)) {
            hide()
            return
        }

        mainHandler.post {
            val appContext = context.applicationContext

            hideInternal()

            currentPackage = packageName
            sessionStartMs = System.currentTimeMillis()
            baselineMs = UsageStatsHelper.getTodayUsageMs(appContext, packageName)

            val wm = appContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            windowManager = wm

            val view = LayoutInflater.from(appContext)
                .inflate(R.layout.overlay_distracting_pill, null)
            overlayView = view
            timerTextView = view.findViewById(R.id.txtTimer)

            val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }

            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                type,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT,
            ).apply {
                gravity = Gravity.TOP or Gravity.START
                x = dpToPx(appContext, HORIZONTAL_PADDING_DP)
                y = getStatusBarHeight(appContext) + dpToPx(appContext, TOP_PADDING_DP)
            }

            try {
                wm.addView(view, params)
                updateTimerDisplay()
                mainHandler.removeCallbacks(tickRunnable)
                mainHandler.removeCallbacks(hideRunnable)
                mainHandler.post(tickRunnable)
                mainHandler.postDelayed(hideRunnable, VISIBLE_DURATION_MS)
            } catch (_: Exception) {
                hideInternal()
            }
        }
    }

    fun hide() {
        mainHandler.post { hideInternal() }
    }

    private fun hideInternal() {
        mainHandler.removeCallbacks(tickRunnable)
        mainHandler.removeCallbacks(hideRunnable)
        overlayView?.let { view ->
            try {
                windowManager?.removeView(view)
            } catch (_: Exception) {
                // View may already have been removed.
            }
        }
        overlayView = null
        timerTextView = null
        windowManager = null
        currentPackage = null
        sessionStartMs = 0L
        baselineMs = 0L
    }

    private fun updateTimerDisplay() {
        if (sessionStartMs <= 0L) return
        val elapsed = System.currentTimeMillis() - sessionStartMs
        val totalMs = baselineMs + elapsed
        timerTextView?.text = formatDuration(totalMs)
    }

    private fun formatDuration(ms: Long): String {
        val totalSeconds = (ms / 1000L).coerceAtLeast(0L)
        val hours = totalSeconds / 3600
        val minutes = (totalSeconds % 3600) / 60
        val seconds = totalSeconds % 60
        return if (hours > 0) {
            String.format(Locale.US, "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            String.format(Locale.US, "%d:%02d", minutes, seconds)
        }
    }

    private fun dpToPx(context: Context, dp: Int): Int {
        return (dp * context.resources.displayMetrics.density).toInt()
    }

    private fun getStatusBarHeight(context: Context): Int {
        val resourceId = context.resources.getIdentifier(
            "status_bar_height",
            "dimen",
            "android",
        )
        return if (resourceId > 0) {
            context.resources.getDimensionPixelSize(resourceId)
        } else {
            dpToPx(context, 24)
        }
    }
}
