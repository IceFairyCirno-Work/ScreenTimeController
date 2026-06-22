package com.screentime.screen_time_controller

/**
 * Enforces focus-timer blocks on the native side so timer apps stay blocked
 * even when rule-based temporary unblocks are active or Flutter is backgrounded.
 */
object ActiveTimerEnforcer {
    fun shouldEnforce(
        packageName: String,
        nowMs: Long = System.currentTimeMillis(),
    ): Boolean = ActiveTimerStore.isTimerBlockedPackage(packageName, nowMs)

    fun hasActiveTimer(nowMs: Long = System.currentTimeMillis()): Boolean =
        ActiveTimerStore.isTimerActive(nowMs)
}
