package com.screentime.screen_time_controller

import android.content.Context
import android.os.Handler
import android.os.Looper

object WebsiteBlockEnforcer {
    private const val ENFORCE_DEBOUNCE_MS = 400L
    private const val OVERLAY_AFTER_NAVIGATE_MS = 350L

    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var lastEnforcedDomain: String? = null

    @Volatile
    private var lastEnforcedTimeMs: Long = 0

    fun enforce(context: Context, domain: String, browserPackage: String) {
        if (!shouldBlock(domain)) {
            return
        }

        val now = System.currentTimeMillis()
        synchronized(this) {
            if (domain == lastEnforcedDomain &&
                now - lastEnforcedTimeMs < ENFORCE_DEBOUNCE_MS
            ) {
                return
            }
            lastEnforcedDomain = domain
            lastEnforcedTimeMs = now
        }

        val enforceAction = Runnable {
            BrowserSafeNavigation.navigateToSafePage(context, browserPackage)
            mainHandler.postDelayed({
                BlockOverlayActivity.show(context, browserPackage)
            }, OVERLAY_AFTER_NAVIGATE_MS)
        }

        if (Looper.myLooper() == Looper.getMainLooper()) {
            enforceAction.run()
        } else {
            mainHandler.post(enforceAction)
        }
    }

    fun shouldBlock(domain: String): Boolean {
        if (BlockedDomainsStore.isBlocked(domain)) return true
        if (AdultContentBlockStore.isEnabled() && AdultContentMatcher.isAdultHost(domain)) {
            return true
        }
        return TemporaryDomainUnblocksStore.shouldEnforceAfterUnblockExpiry(domain)
    }
}
