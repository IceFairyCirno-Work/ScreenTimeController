package com.screentime.screen_time_controller

import android.content.Context
import android.content.Intent
import android.net.Uri

/**
 * Replaces a blocked page with a neutral URL so the browser omnibox does not
 * keep the blocked domain after the user dismisses the block overlay.
 */
object BrowserSafeNavigation {
    private const val SAFE_URL = "https://www.google.com"

    fun navigateToSafePage(context: Context, browserPackage: String) {
        try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(SAFE_URL)).apply {
                setPackage(browserPackage)
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP,
                )
            }
            context.startActivity(intent)
        } catch (_: Exception) {
            try {
                val fallback = Intent(Intent.ACTION_VIEW, Uri.parse(SAFE_URL)).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(fallback)
            } catch (_: Exception) {
                // Best-effort — overlay still shown if navigation fails.
            }
        }
    }
}
