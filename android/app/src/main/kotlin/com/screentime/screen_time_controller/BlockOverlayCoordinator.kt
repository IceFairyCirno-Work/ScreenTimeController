package com.screentime.screen_time_controller

import android.content.Context
import android.os.Handler
import android.os.Looper

/**
 * Single entry point for showing the block overlay.
 *
 * Guarantees one quote/background per block session, debounces duplicate
 * requests from accessibility events / polls / website navigation, and
 * cancels stacked delayed launches.
 */
object BlockOverlayCoordinator {
    private const val RE_SHOW_DEBOUNCE_MS = 2_000L
    private const val NAVIGATE_THEN_SHOW_DELAY_MS = 400L

    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var sessionPackage: String? = null

    private var sessionQuote: BlockQuote? = null
    private var sessionBackgroundColor: Int? = null

    @Volatile
    private var activityResumed: Boolean = false

    @Volatile
    private var lastLaunchMs: Long = 0L

    private var pendingLaunch: Runnable? = null

    fun prepareSession(packageName: String): Pair<BlockQuote, Int> {
        synchronized(this) {
            if (sessionPackage != packageName) {
                sessionPackage = packageName
                sessionQuote = BlockOverlayContent.randomQuote()
                sessionBackgroundColor = BlockOverlayContent.randomBackgroundColor()
            } else if (sessionQuote == null || sessionBackgroundColor == null) {
                sessionQuote = BlockOverlayContent.randomQuote()
                sessionBackgroundColor = BlockOverlayContent.randomBackgroundColor()
            }
            return sessionQuote!! to sessionBackgroundColor!!
        }
    }

    fun currentContent(): Pair<BlockQuote, Int>? {
        synchronized(this) {
            val quote = sessionQuote ?: return null
            val color = sessionBackgroundColor ?: return null
            return quote to color
        }
    }

    fun requestShow(
        context: Context,
        packageName: String,
        afterNavigate: Boolean = false,
    ) {
        val appContext = context.applicationContext
        val launch = Runnable {
            synchronized(this) {
                pendingLaunch = null
                if (activityResumed && sessionPackage == packageName) {
                    return@Runnable
                }
            }
            BlockOverlayActivity.launch(appContext, packageName)
        }

        synchronized(this) {
            if (activityResumed && sessionPackage == packageName) {
                return
            }

            val now = System.currentTimeMillis()
            if (sessionPackage == packageName &&
                now - lastLaunchMs < RE_SHOW_DEBOUNCE_MS
            ) {
                if (pendingLaunch != null || activityResumed) {
                    return
                }
            }

            prepareSession(packageName)
            lastLaunchMs = now
            pendingLaunch?.let { mainHandler.removeCallbacks(it) }
            pendingLaunch = launch
        }

        val delay = if (afterNavigate) NAVIGATE_THEN_SHOW_DELAY_MS else 0L
        if (delay > 0) {
            mainHandler.postDelayed(launch, delay)
        } else {
            mainHandler.post(launch)
        }
    }

    fun onActivityResumed(packageName: String?) {
        synchronized(this) {
            activityResumed = true
            if (!packageName.isNullOrBlank()) {
                sessionPackage = packageName
            }
            pendingLaunch?.let { mainHandler.removeCallbacks(it) }
            pendingLaunch = null
        }
    }

    fun onActivityPaused() {
        activityResumed = false
    }

    fun onUserDismissed() {
        synchronized(this) {
            activityResumed = false
            sessionPackage = null
            sessionQuote = null
            sessionBackgroundColor = null
            lastLaunchMs = 0L
            pendingLaunch?.let { mainHandler.removeCallbacks(it) }
            pendingLaunch = null
        }
    }

    fun isOverlayResumed(): Boolean = activityResumed

    fun shouldDeferWebsiteEnforce(browserPackage: String, context: Context): Boolean {
        if (BlockedPackagesStore.isBlocked(browserPackage)) return true
        if (ActiveTimerEnforcer.shouldEnforce(browserPackage)) return true
        if (SessionScheduleEnforcer.shouldEnforce(browserPackage)) return true
        if (TemporaryUnblocksStore.shouldEnforceAfterUnblockExpiry(browserPackage)) {
            return true
        }
        if (TimeLimitEnforcer.shouldEnforce(context, browserPackage)) return true
        if (activityResumed && sessionPackage == browserPackage) return true
        return false
    }
}
