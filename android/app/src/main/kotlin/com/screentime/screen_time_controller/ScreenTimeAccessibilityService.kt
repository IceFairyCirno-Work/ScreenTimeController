package com.screentime.screen_time_controller

import android.accessibilityservice.AccessibilityService
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent

/**
 * Detects when the user opens a blocked app and enforces the block overlay.
 * A foreground poll catches rapid retries that slip past window events, and
 * re-blocks apps when a temporary unblock window expires in the foreground.
 */
class ScreenTimeAccessibilityService : AccessibilityService() {
    private val handler = Handler(Looper.getMainLooper())
    private var lastAwarenessForegroundPackage: String? = null
    private val foregroundMonitor = object : Runnable {
        override fun run() {
            checkForegroundAndEnforce()
            val delay =
                if (BlockedPackagesStore.hasBlockedPackages() ||
                    BlockedDomainsStore.hasBlockedDomains() ||
                    AdultContentBlockStore.isEnabled() ||
                    TemporaryUnblocksStore.hasTrackedPackages() ||
                    TemporaryDomainUnblocksStore.hasTrackedDomains() ||
                    TimeLimitRulesStore.hasActiveRules() ||
                    SessionScheduleRulesStore.hasEnabledRules() ||
                    DistractingPackagesStore.hasDistractingPackages()
                ) {
                    FOREGROUND_POLL_MS
                } else {
                    IDLE_POLL_MS
                }
            handler.postDelayed(this, delay)
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        BlockedPackagesStore.init(applicationContext)
        BlockedDomainsStore.init(applicationContext)
        AdultContentBlockStore.init(applicationContext)
        BlockedAppStatsStore.init(applicationContext)
        TemporaryUnblocksStore.init(applicationContext)
        TemporaryDomainUnblocksStore.init(applicationContext)
        TimeLimitRulesStore.init(applicationContext)
        SessionScheduleRulesStore.init(applicationContext)
        DistractingPackagesStore.init(applicationContext)
        DistractingOverlaySettingsStore.init(applicationContext)
        BlockedPackagesStore.onPackagesUpdated = {
            handler.post { checkForegroundAndEnforce() }
        }
        DistractingPackagesStore.onPackagesUpdated = {
            handler.post { checkForegroundAndEnforce() }
        }
        SessionScheduleRulesStore.onRulesUpdated = {
            handler.post { checkForegroundAndEnforce() }
        }
        handler.post(foregroundMonitor)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        val pkg = event.packageName?.toString() ?: return
        if (pkg == packageName) return

        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED,
            AccessibilityEvent.TYPE_WINDOWS_CHANGED,
            -> {
                if (shouldEnforce(pkg)) {
                    AppBlockEnforcer.enforce(this, pkg)
                    DistractingOverlayManager.hide()
                    lastAwarenessForegroundPackage = pkg
                } else {
                    updateDistractingOverlay(pkg)
                }
                // Only check domains on navigation — not on every keystroke.
                checkBrowserDomain(pkg)
            }
        }
    }

    override fun onInterrupt() {}

    override fun onDestroy() {
        BlockedPackagesStore.onPackagesUpdated = null
        DistractingPackagesStore.onPackagesUpdated = null
        SessionScheduleRulesStore.onRulesUpdated = null
        DistractingOverlayManager.hide()
        handler.removeCallbacks(foregroundMonitor)
        super.onDestroy()
    }

    private fun checkForegroundAndEnforce() {
        val root = rootInActiveWindow ?: return
        val foregroundPackage = root.packageName?.toString() ?: return
        if (foregroundPackage == packageName) return
        if (shouldEnforce(foregroundPackage)) {
            AppBlockEnforcer.enforce(this, foregroundPackage)
            DistractingOverlayManager.hide()
            lastAwarenessForegroundPackage = foregroundPackage
        } else {
            updateDistractingOverlay(foregroundPackage)
        }
        checkBrowserDomain(foregroundPackage, root)
    }

    private fun updateDistractingOverlay(foregroundPackage: String) {
        if (!DistractingOverlaySettingsStore.isEnabled()) {
            DistractingOverlayManager.hide()
            lastAwarenessForegroundPackage = foregroundPackage
            return
        }
        if (!PermissionsHelper.hasOverlayPermission(this)) {
            DistractingOverlayManager.hide()
            lastAwarenessForegroundPackage = foregroundPackage
            return
        }
        if (!DistractingPackagesStore.isDistracting(foregroundPackage)) {
            DistractingOverlayManager.hide()
            lastAwarenessForegroundPackage = foregroundPackage
            return
        }
        if (lastAwarenessForegroundPackage != foregroundPackage) {
            DistractingOverlayManager.show(this, foregroundPackage)
        }
        lastAwarenessForegroundPackage = foregroundPackage
    }

    private fun checkBrowserDomain(
        browserPackage: String,
        root: android.view.accessibility.AccessibilityNodeInfo? = rootInActiveWindow,
    ) {
        if (shouldEnforce(browserPackage)) return
        if (!BrowserUrlExtractor.isBrowser(browserPackage)) return
        if (!BlockedDomainsStore.hasBlockedDomains() &&
            !TemporaryDomainUnblocksStore.hasTrackedDomains() &&
            !AdultContentBlockStore.isEnabled()
        ) {
            return
        }
        val hostname = BrowserUrlExtractor.extractCommittedHostname(root) ?: return
        if (WebsiteBlockEnforcer.shouldBlock(hostname)) {
            WebsiteBlockEnforcer.enforce(this, hostname, browserPackage)
        }
    }

    private fun shouldEnforce(packageName: String): Boolean {
        if (BlockedPackagesStore.isBlocked(packageName)) return true
        if (SessionScheduleEnforcer.shouldEnforce(packageName)) return true
        if (TemporaryUnblocksStore.shouldEnforceAfterUnblockExpiry(packageName)) return true
        return TimeLimitEnforcer.shouldEnforce(this, packageName)
    }

    companion object {
        private const val FOREGROUND_POLL_MS = 250L
        private const val IDLE_POLL_MS = 1000L
    }
}
