package com.screentime.screen_time_controller

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

object BlockingMethodChannel {
    const val CHANNEL_NAME = "com.screentime.screen_time_controller/app_blocking"

    fun register(messenger: BinaryMessenger, context: Context) {
        BlockedPackagesStore.init(context)
        BlockedDomainsStore.init(context)
        AdultContentBlockStore.init(context)
        TemporaryUnblocksStore.init(context)
        TemporaryDomainUnblocksStore.init(context)
        TimeLimitRulesStore.init(context)
        ActiveTimerStore.init(context)
        DistractingPackagesStore.init(context)
        MethodChannel(messenger, CHANNEL_NAME).setMethodCallHandler { call, result ->
            when (call.method) {
                "syncBlockedPackages" -> {
                    val packages = call.argument<List<String>>("packages") ?: emptyList()
                    @Suppress("UNCHECKED_CAST")
                    val rawUnblocks =
                        call.argument<Map<String, Any>>("temporaryUnblocks") ?: emptyMap()
                    val temporaryUnblocks = rawUnblocks.mapValues { (_, value) ->
                        when (value) {
                            is Int -> value.toLong()
                            is Long -> value
                            is Number -> value.toLong()
                            else -> 0L
                        }
                    }
                    val domains = call.argument<List<String>>("domains") ?: emptyList()
                    @Suppress("UNCHECKED_CAST")
                    val rawDomainUnblocks =
                        call.argument<Map<String, Any>>("temporaryDomainUnblocks") ?: emptyMap()
                    val temporaryDomainUnblocks = rawDomainUnblocks.mapValues { (_, value) ->
                        when (value) {
                            is Int -> value.toLong()
                            is Long -> value
                            is Number -> value.toLong()
                            else -> 0L
                        }
                    }

                    val blockedChanged =
                        BlockedPackagesStore.setBlockedPackages(packages.toSet())
                    val unblocksChanged =
                        TemporaryUnblocksStore.setTemporaryUnblocks(temporaryUnblocks)
                    val domainsChanged =
                        BlockedDomainsStore.setBlockedDomains(domains.toSet())
                    val domainUnblocksChanged =
                        TemporaryDomainUnblocksStore.setTemporaryUnblocks(
                            temporaryDomainUnblocks,
                        )

                    @Suppress("UNCHECKED_CAST")
                    val rawTimeLimits =
                        call.argument<List<Map<String, Any>>>("timeLimitRules")
                            ?: emptyList()
                    val timeLimitEntries = rawTimeLimits.mapNotNull { map ->
                        val packageName = map["packageName"] as? String ?: return@mapNotNull null
                        TimeLimitRulesStore.Entry(
                            packageName = packageName,
                            allowedMs = (map["allowedMs"] as? Number)?.toLong() ?: return@mapNotNull null,
                            baselineMs = (map["baselineMs"] as? Number)?.toLong() ?: 0L,
                            blockUntilMs = (map["blockUntilMs"] as? Number)?.toLong() ?: 0L,
                            blockUntilMidnight = map["blockUntilMidnight"] as? Boolean ?: false,
                            limitExceededAtMs =
                                (map["limitExceededAtMs"] as? Number)?.toLong() ?: 0L,
                            ruleActive = map["ruleActive"] as? Boolean ?: false,
                        )
                    }
                    val timeLimitsChanged =
                        TimeLimitRulesStore.setEntries(timeLimitEntries)
                    val adultBlockingChanged = AdultContentBlockStore.setEnabled(
                        call.argument<Boolean>("adultWebsitesBlocked") ?: true,
                    )
                    val distractingPackages =
                        call.argument<List<String>>("distractingPackages")
                            ?: emptyList()
                    val distractingChanged =
                        DistractingPackagesStore.setDistractingPackages(
                            distractingPackages.toSet(),
                        )

                    if (blockedChanged ||
                        unblocksChanged ||
                        domainsChanged ||
                        domainUnblocksChanged ||
                        timeLimitsChanged ||
                        adultBlockingChanged
                    ) {
                        BlockedPackagesStore.notifyStateUpdated()
                    }
                    if (distractingChanged) {
                        DistractingPackagesStore.notifyStateUpdated()
                    }
                    result.success(null)
                }
                "syncDistractingPackages" -> {
                    // Legacy call — kept so older Dart builds don't crash.
                    val packages = call.argument<List<String>>("packages") ?: emptyList()
                    val distractingChanged =
                        DistractingPackagesStore.setDistractingPackages(packages.toSet())
                    if (distractingChanged) {
                        DistractingPackagesStore.notifyStateUpdated()
                    }
                    result.success(null)
                }
                "syncActiveTimer" -> {
                    val isRunning = call.argument<Boolean>("isRunning") ?: false
                    val isInfiniteMode = call.argument<Boolean>("isInfiniteMode") ?: false
                    val endTimeMs = call.argument<Number>("endTimeMs")?.toLong()
                    val startedAtMs = call.argument<Number>("startedAtMs")?.toLong()
                    val blockedAppsJson =
                        call.argument<String>("blockedAppsJson") ?: "[]"
                    ActiveTimerStore.syncActiveTimer(
                        isRunning = isRunning,
                        isInfiniteMode = isInfiniteMode,
                        endTimeMs = endTimeMs,
                        startedAtMs = startedAtMs,
                        blockedAppsJson = blockedAppsJson,
                    )
                    result.success(null)
                }
                "getActiveTimer" -> {
                    result.success(ActiveTimerStore.getActiveTimer())
                }
                "clearActiveTimer" -> {
                    ActiveTimerStore.clearActiveTimer()
                    result.success(null)
                }
                "clearBlockedPackages" -> {
                    val blockedChanged = BlockedPackagesStore.setBlockedPackages(emptySet())
                    val unblocksChanged =
                        TemporaryUnblocksStore.setTemporaryUnblocks(emptyMap())
                    val domainsChanged = BlockedDomainsStore.setBlockedDomains(emptySet())
                    val domainUnblocksChanged =
                        TemporaryDomainUnblocksStore.setTemporaryUnblocks(emptyMap())
                    if (blockedChanged ||
                        unblocksChanged ||
                        domainsChanged ||
                        domainUnblocksChanged
                    ) {
                        BlockedPackagesStore.notifyStateUpdated()
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
