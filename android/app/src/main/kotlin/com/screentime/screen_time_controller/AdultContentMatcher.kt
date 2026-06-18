package com.screentime.screen_time_controller

object AdultContentMatcher {
    private val exactDomains = setOf(
        "pornhub.com",
        "xvideos.com",
        "xnxx.com",
        "xhamster.com",
        "redtube.com",
        "youporn.com",
        "spankbang.com",
        "eporner.com",
        "chaturbate.com",
        "onlyfans.com",
        "brazzers.com",
        "bangbros.com",
        "hentaihaven.xxx",
    )

    private val segmentKeywords = setOf(
        "porn",
        "xxx",
        "sex",
        "adult",
        "hentai",
        "nude",
        "nsfw",
        "xnxx",
        "xvideos",
        "pornhub",
        "xhamster",
        "redtube",
        "youporn",
        "chaturbate",
        "onlyfans",
        "brazzers",
        "camgirl",
        "webcam",
    )

    fun isAdultHost(hostname: String): Boolean {
        val host = normalizeHost(hostname)
        if (host.isEmpty()) return false
        if (host == "xxx" || host.endsWith(".xxx")) return true

        if (exactDomains.any { domain -> host == domain || host.endsWith(".$domain") }) {
            return true
        }

        val segments = host.split('.')
        if (segments.any { segment -> segment in segmentKeywords }) {
            return true
        }

        return segmentKeywords.any { keyword -> host.contains(keyword) }
    }

    private fun normalizeHost(hostname: String): String {
        var host = hostname.trim().lowercase()
        if (host.startsWith("www.")) {
            host = host.removePrefix("www.")
        }
        return host
    }
}
