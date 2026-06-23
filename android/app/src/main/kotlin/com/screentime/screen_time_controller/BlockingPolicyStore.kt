package com.screentime.screen_time_controller

import android.content.Context
import java.util.concurrent.atomic.AtomicReference

/**
 * Folder exemptions and emergency-pass state synced from Flutter so native
 * timer enforcement matches [computeBlockedPackages].
 */
object BlockingPolicyStore {
    private const val PREFS_NAME = "app_blocking"
    private const val KEY_ALWAYS_ALLOWED = "policy_always_allowed"
    private const val KEY_NEVER_ALLOWED = "policy_never_allowed"
    private const val KEY_EMERGENCY_PASS = "policy_emergency_pass_active"

    private val appContext = AtomicReference<Context?>(null)
    private val alwaysAllowedPackages = AtomicReference<Set<String>>(emptySet())
    private val neverAllowedPackages = AtomicReference<Set<String>>(emptySet())

    @Volatile
    private var emergencyPassActive: Boolean = false

    fun init(context: Context) {
        appContext.set(context.applicationContext)
        loadFromPrefs()
    }

    private fun loadFromPrefs() {
        val ctx = appContext.get() ?: return
        val prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        alwaysAllowedPackages.set(
            prefs.getStringSet(KEY_ALWAYS_ALLOWED, emptySet()) ?: emptySet(),
        )
        neverAllowedPackages.set(
            prefs.getStringSet(KEY_NEVER_ALLOWED, emptySet()) ?: emptySet(),
        )
        emergencyPassActive = prefs.getBoolean(KEY_EMERGENCY_PASS, false)
    }

    fun setPolicy(
        alwaysAllowed: Set<String>,
        neverAllowed: Set<String>,
        emergencyPassActive: Boolean,
    ): Boolean {
        val alwaysCopy = alwaysAllowed.toSet()
        val neverCopy = neverAllowed.toSet()
        val previousAlways = alwaysAllowedPackages.get()
        val previousNever = neverAllowedPackages.get()
        val previousEmergency = this.emergencyPassActive
        if (previousAlways == alwaysCopy &&
            previousNever == neverCopy &&
            previousEmergency == emergencyPassActive
        ) {
            return false
        }

        alwaysAllowedPackages.set(alwaysCopy)
        neverAllowedPackages.set(neverCopy)
        this.emergencyPassActive = emergencyPassActive

        val ctx = appContext.get() ?: return true
        ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putStringSet(KEY_ALWAYS_ALLOWED, alwaysCopy)
            .putStringSet(KEY_NEVER_ALLOWED, neverCopy)
            .putBoolean(KEY_EMERGENCY_PASS, emergencyPassActive)
            .apply()
        return true
    }

    fun isEmergencyPassActive(): Boolean = emergencyPassActive

    fun isNeverAllowedPackage(packageName: String): Boolean =
        neverAllowedPackages.get().contains(packageName)

    fun isEffectivelyAlwaysAllowed(packageName: String): Boolean =
        alwaysAllowedPackages.get().contains(packageName) &&
            !isNeverAllowedPackage(packageName)
}
