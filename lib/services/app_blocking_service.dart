import 'platform/enforcement_platform.dart';

/// Syncs blocked packages and active timer state to native enforcement.
///
/// Android uses AccessibilityService; iOS calls scaffold app_blocking channels.
class AppBlockingService {
  AppBlockingService({EnforcementPlatform? platform})
      : _platform = platform ?? createEnforcementPlatform();

  final EnforcementPlatform _platform;

  Future<void> syncBlockedPackages(
    Set<String> packages, {
    Map<String, int> temporaryUnblockUntilByPackage = const {},
    Set<String> domains = const {},
    Map<String, int> temporaryUnblockUntilByDomain = const {},
    List<Map<String, dynamic>> timeLimitRules = const [],
    List<Map<String, dynamic>> sessionScheduleRules = const [],
    bool adultWebsitesBlocked = true,
    Set<String> distractingPackages = const {},
    bool distractingOverlayEnabled = true,
    Set<String> alwaysAllowedPackages = const {},
    Set<String> neverAllowedPackages = const {},
    bool emergencyPassActive = false,
  }) =>
      _platform.syncBlockedPackages(
        packages,
        temporaryUnblockUntilByPackage: temporaryUnblockUntilByPackage,
        domains: domains,
        temporaryUnblockUntilByDomain: temporaryUnblockUntilByDomain,
        timeLimitRules: timeLimitRules,
        sessionScheduleRules: sessionScheduleRules,
        adultWebsitesBlocked: adultWebsitesBlocked,
        distractingPackages: distractingPackages,
        distractingOverlayEnabled: distractingOverlayEnabled,
        alwaysAllowedPackages: alwaysAllowedPackages,
        neverAllowedPackages: neverAllowedPackages,
        emergencyPassActive: emergencyPassActive,
      );

  Future<void> clearBlockedPackages() => _platform.clearBlockedPackages();

  Future<void> syncActiveTimer({
    required bool isRunning,
    required bool isInfiniteMode,
    int? endTimeMs,
    int? startedAtMs,
    required String blockedAppsJson,
  }) =>
      _platform.syncActiveTimer(
        isRunning: isRunning,
        isInfiniteMode: isInfiniteMode,
        endTimeMs: endTimeMs,
        startedAtMs: startedAtMs,
        blockedAppsJson: blockedAppsJson,
      );

  Future<Map<String, dynamic>?> getActiveTimer() => _platform.getActiveTimer();

  Future<void> clearActiveTimer() => _platform.clearActiveTimer();
}
