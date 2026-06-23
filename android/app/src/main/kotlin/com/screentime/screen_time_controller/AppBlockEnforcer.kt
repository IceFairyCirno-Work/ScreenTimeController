package com.screentime.screen_time_controller

import android.content.Context
import android.os.Handler
import android.os.Looper

/**
 * Shows the block overlay when a blocked app reaches the foreground.
 * Foreground polling re-shows the overlay if the user retries quickly.
 */
object AppBlockEnforcer {
    private val mainHandler = Handler(Looper.getMainLooper())

    fun enforce(context: Context, packageName: String) {
        if (packageName == context.packageName) return
        if (BlockingPolicyStore.isEmergencyPassActive()) return
        if (!BlockedPackagesStore.isBlocked(packageName) &&
            !ActiveTimerEnforcer.shouldEnforce(packageName) &&
            !SessionScheduleEnforcer.shouldEnforce(packageName) &&
            !TemporaryUnblocksStore.shouldEnforceAfterUnblockExpiry(packageName) &&
            !TimeLimitEnforcer.shouldEnforce(context, packageName)
        ) {
            return
        }

        val launchOverlay = Runnable {
            BlockOverlayCoordinator.requestShow(context, packageName)
        }
        if (Looper.myLooper() == Looper.getMainLooper()) {
            launchOverlay.run()
        } else {
            mainHandler.post(launchOverlay)
        }
    }
}
