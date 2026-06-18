package com.screentime.screen_time_controller

import android.content.Context
import android.os.Handler
import android.os.Looper

/**
 * Shows the block overlay when a blocked app reaches the foreground.
 * Foreground polling re-shows the overlay if the user retries quickly.
 */
object AppBlockEnforcer {
    private const val ENFORCE_DEBOUNCE_MS = 200L

    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var lastEnforcedPackage: String? = null

    @Volatile
    private var lastEnforcedTimeMs: Long = 0

    fun enforce(context: Context, packageName: String) {
        if (packageName == context.packageName) return
        if (!BlockedPackagesStore.isBlocked(packageName) &&
            !TemporaryUnblocksStore.shouldEnforceAfterUnblockExpiry(packageName) &&
            !TimeLimitEnforcer.shouldEnforce(context, packageName)
        ) {
            return
        }

        val now = System.currentTimeMillis()
        synchronized(this) {
            if (packageName == lastEnforcedPackage &&
                now - lastEnforcedTimeMs < ENFORCE_DEBOUNCE_MS
            ) {
                return
            }
            lastEnforcedPackage = packageName
            lastEnforcedTimeMs = now
        }

        // Show the overlay on top of the blocked app. Do not send HOME first —
        // that prevents the overlay from appearing on many devices.
        val launchOverlay = Runnable { BlockOverlayActivity.show(context, packageName) }
        if (Looper.myLooper() == Looper.getMainLooper()) {
            launchOverlay.run()
        } else {
            mainHandler.post(launchOverlay)
        }
    }
}
