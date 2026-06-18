package com.screentime.screen_time_controller

import android.view.accessibility.AccessibilityNodeInfo

object BrowserUrlExtractor {
    private val browserPackages = setOf(
        "com.android.chrome",
        "com.chrome.beta",
        "com.chrome.dev",
        "com.google.android.apps.chrome",
        "org.mozilla.firefox",
        "org.mozilla.firefox_beta",
        "com.brave.browser",
        "com.microsoft.emmx",
        "com.opera.browser",
        "com.sec.android.app.sbrowser",
        "com.vivaldi.browser",
    )

    fun isBrowser(packageName: String): Boolean = browserPackages.contains(packageName)

    /**
     * Returns a hostname only when the user has navigated to a page — not while
     * they are typing or picking an address-bar autocomplete suggestion.
     */
    fun extractCommittedHostname(root: AccessibilityNodeInfo?): String? {
        if (root == null) return null
        if (isUserEditingUrl(root)) return null
        if (isTabOverview(root)) return null

        // Only trust committed omnibox content. Avoid scanning whole UI text,
        // which catches tab thumbnails / suggestions and causes false blocks.
        return extractUnfocusedOmniboxHostname(root)
    }

    /**
     * True when the URL / search bar is focused — includes autocomplete previews
     * such as typing "speedtest.n" while the browser suggests "speedtest.net".
     */
    fun isUserEditingUrl(root: AccessibilityNodeInfo?): Boolean {
        if (root == null) return false
        val queue = ArrayDeque<AccessibilityNodeInfo>()
        queue.add(root)
        while (queue.isNotEmpty()) {
            val node = queue.removeFirst()
            if (node.isFocused && isLikelyUrlInput(node)) return true
            for (i in 0 until node.childCount) {
                node.getChild(i)?.let { queue.add(it) }
            }
        }
        return false
    }

    private fun isLikelyUrlInput(node: AccessibilityNodeInfo): Boolean {
        if (node.isEditable) return true
        val className = node.className?.toString().orEmpty()
        return className.contains("EditText", ignoreCase = true) ||
            className.contains("AutoCompleteTextView", ignoreCase = true) ||
            className.contains("UrlBar", ignoreCase = true)
    }

    private fun extractUnfocusedOmniboxHostname(root: AccessibilityNodeInfo): String? {
        val queue = ArrayDeque<AccessibilityNodeInfo>()
        queue.add(root)
        while (queue.isNotEmpty()) {
            val node = queue.removeFirst()
            if (!node.isFocused && isLikelyUrlInput(node)) {
                val text = node.text?.toString()?.trim()
                if (!text.isNullOrEmpty() && looksLikeUrl(text)) {
                    parseHostname(text)?.let { return it }
                }
            }
            for (i in 0 until node.childCount) {
                node.getChild(i)?.let { queue.add(it) }
            }
        }
        return null
    }

    /**
     * Heuristic guard for browser tab overview screens. We avoid blocking here
     * because overview cards often contain blocked-domain text while the user
     * is not actively visiting that page.
     */
    private fun isTabOverview(root: AccessibilityNodeInfo): Boolean {
        var urlCount = 0
        var hasTabCue = false
        val queue = ArrayDeque<AccessibilityNodeInfo>()
        queue.add(root)
        while (queue.isNotEmpty()) {
            val node = queue.removeFirst()

            val text = node.text?.toString()?.trim().orEmpty()
            val desc = node.contentDescription?.toString()?.trim().orEmpty()
            val combined = "$text $desc".lowercase()
            if (combined.contains("tab")) {
                hasTabCue = true
            }
            if (!node.isEditable) {
                if (text.isNotEmpty() && looksLikeUrl(text)) urlCount++
                if (desc.isNotEmpty() && looksLikeUrl(desc)) urlCount++
            }

            for (i in 0 until node.childCount) {
                node.getChild(i)?.let { queue.add(it) }
            }
        }
        return hasTabCue && urlCount >= 2
    }

    private fun looksLikeUrl(text: String): Boolean {
        val value = text.trim()
        if (value.contains(' ') && !value.startsWith("http")) return false
        return value.contains('.') &&
            (value.startsWith("http://") ||
                value.startsWith("https://") ||
                value.matches(Regex("^[a-z0-9.-]+\\.[a-z]{2,}(/.*)?$", RegexOption.IGNORE_CASE)))
    }

    private fun parseHostname(text: String): String? {
        var value = text.trim().lowercase()
        if (value.startsWith("http://")) value = value.removePrefix("http://")
        if (value.startsWith("https://")) value = value.removePrefix("https://")
        if (value.startsWith("www.")) value = value.removePrefix("www.")
        val slash = value.indexOf('/')
        if (slash >= 0) value = value.substring(0, slash)
        val query = value.indexOf('?')
        if (query >= 0) value = value.substring(0, query)
        return value.takeIf { it.contains('.') }
    }
}
