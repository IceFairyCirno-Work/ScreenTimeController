import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../utils/platform_capabilities.dart';

/// Platform abstraction for native blocking enforcement.
abstract class EnforcementPlatform {
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
  });

  Future<void> clearBlockedPackages();

  Future<void> syncActiveTimer({
    required bool isRunning,
    required bool isInfiniteMode,
    int? endTimeMs,
    int? startedAtMs,
    required String blockedAppsJson,
  });

  Future<Map<String, dynamic>?> getActiveTimer();

  Future<void> clearActiveTimer();

  /// Apps queued by the midnight auto-move job for Flutter to persist.
  Future<List<Map<String, String>>> consumePendingAutoMovedApps();
}

class AndroidEnforcementPlatform implements EnforcementPlatform {
  static const _channel =
      MethodChannel('com.screentime.screen_time_controller/app_blocking');

  @override
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
  }) async {
    try {
      await _channel.invokeMethod<void>(
        'syncBlockedPackages',
        {
          'packages': packages.toList(),
          'temporaryUnblocks': temporaryUnblockUntilByPackage,
          'domains': domains.toList(),
          'temporaryDomainUnblocks': temporaryUnblockUntilByDomain,
          'timeLimitRules': timeLimitRules,
          'sessionScheduleRules': sessionScheduleRules,
          'adultWebsitesBlocked': adultWebsitesBlocked,
          'distractingPackages': distractingPackages.toList(),
          'distractingOverlayEnabled': distractingOverlayEnabled,
          'alwaysAllowedPackages': alwaysAllowedPackages.toList(),
          'neverAllowedPackages': neverAllowedPackages.toList(),
          'emergencyPassActive': emergencyPassActive,
        },
      );
    } on MissingPluginException catch (e) {
      debugPrint('Native blocking channel unavailable: $e');
    } on PlatformException catch (e) {
      debugPrint('Failed to sync blocked packages: $e');
    }
  }

  @override
  Future<void> clearBlockedPackages() async {
    try {
      await _channel.invokeMethod<void>('clearBlockedPackages');
    } on PlatformException catch (e) {
      debugPrint('Failed to clear blocked packages: $e');
    }
  }

  @override
  Future<void> syncActiveTimer({
    required bool isRunning,
    required bool isInfiniteMode,
    int? endTimeMs,
    int? startedAtMs,
    required String blockedAppsJson,
  }) async {
    try {
      await _channel.invokeMethod<void>(
        'syncActiveTimer',
        {
          'isRunning': isRunning,
          'isInfiniteMode': isInfiniteMode,
          'endTimeMs': endTimeMs,
          'startedAtMs': startedAtMs,
          'blockedAppsJson': blockedAppsJson,
        },
      );
    } on PlatformException catch (e) {
      debugPrint('Failed to sync active timer: $e');
    }
  }

  @override
  Future<Map<String, dynamic>?> getActiveTimer() async {
    try {
      final result = await _channel.invokeMethod<Object?>('getActiveTimer');
      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
    } on PlatformException catch (e) {
      debugPrint('Failed to read active timer: $e');
    }
    return null;
  }

  @override
  Future<void> clearActiveTimer() async {
    try {
      await _channel.invokeMethod<void>('clearActiveTimer');
    } on PlatformException catch (e) {
      debugPrint('Failed to clear active timer: $e');
    }
  }

  @override
  Future<List<Map<String, String>>> consumePendingAutoMovedApps() async {
    try {
      final result =
          await _channel.invokeMethod<List<Object?>>('consumePendingAutoMovedApps');
      if (result == null) return const [];

      return result
          .whereType<Map>()
          .map(
            (entry) => {
              'packageName': entry['packageName']?.toString() ?? '',
              'appName': entry['appName']?.toString() ?? '',
            },
          )
          .where((entry) => entry['packageName']!.isNotEmpty)
          .map((entry) => Map<String, String>.from(entry))
          .toList();
    } on MissingPluginException catch (e) {
      debugPrint('Native blocking channel unavailable: $e');
    } on PlatformException catch (e) {
      debugPrint('Failed to consume pending auto-moved apps: $e');
    }
    return const [];
  }
}

class IosEnforcementPlatform implements EnforcementPlatform {
  static const _channel =
      MethodChannel('com.screentime.screen_time_controller/app_blocking');

  @override
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
  }) async {
    try {
      await _channel.invokeMethod<void>(
        'syncBlockedPackages',
        {
          'packages': packages.toList(),
          'temporaryUnblocks': temporaryUnblockUntilByPackage,
          'domains': domains.toList(),
          'temporaryDomainUnblocks': temporaryUnblockUntilByDomain,
          'timeLimitRules': timeLimitRules,
          'sessionScheduleRules': sessionScheduleRules,
          'adultWebsitesBlocked': adultWebsitesBlocked,
          'distractingPackages': distractingPackages.toList(),
          'distractingOverlayEnabled': distractingOverlayEnabled,
          'alwaysAllowedPackages': alwaysAllowedPackages.toList(),
          'neverAllowedPackages': neverAllowedPackages.toList(),
          'emergencyPassActive': emergencyPassActive,
        },
      );
    } on MissingPluginException {
      // Scaffold not registered yet.
    } on PlatformException catch (e) {
      debugPrint('iOS sync blocked packages failed: $e');
    }
  }

  @override
  Future<void> clearBlockedPackages() async {
    try {
      await _channel.invokeMethod<void>('clearBlockedPackages');
    } on MissingPluginException {
      // no-op
    } on PlatformException catch (e) {
      debugPrint('iOS clear blocked packages failed: $e');
    }
  }

  @override
  Future<void> syncActiveTimer({
    required bool isRunning,
    required bool isInfiniteMode,
    int? endTimeMs,
    int? startedAtMs,
    required String blockedAppsJson,
  }) async {
    try {
      await _channel.invokeMethod<void>(
        'syncActiveTimer',
        {
          'isRunning': isRunning,
          'isInfiniteMode': isInfiniteMode,
          'endTimeMs': endTimeMs,
          'startedAtMs': startedAtMs,
          'blockedAppsJson': blockedAppsJson,
        },
      );
    } on MissingPluginException {
      // no-op
    } on PlatformException catch (e) {
      debugPrint('iOS sync active timer failed: $e');
    }
  }

  @override
  Future<Map<String, dynamic>?> getActiveTimer() async {
    try {
      final result = await _channel.invokeMethod<Object?>('getActiveTimer');
      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('iOS get active timer failed: $e');
    }
    return null;
  }

  @override
  Future<void> clearActiveTimer() async {
    try {
      await _channel.invokeMethod<void>('clearActiveTimer');
    } on MissingPluginException {
      // no-op
    } on PlatformException catch (e) {
      debugPrint('iOS clear active timer failed: $e');
    }
  }

  @override
  Future<List<Map<String, String>>> consumePendingAutoMovedApps() async =>
      const [];
}

class NoopEnforcementPlatform implements EnforcementPlatform {
  @override
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
  }) async {}

  @override
  Future<void> clearBlockedPackages() async {}

  @override
  Future<void> syncActiveTimer({
    required bool isRunning,
    required bool isInfiniteMode,
    int? endTimeMs,
    int? startedAtMs,
    required String blockedAppsJson,
  }) async {}

  @override
  Future<Map<String, dynamic>?> getActiveTimer() async => null;

  @override
  Future<void> clearActiveTimer() async {}

  @override
  Future<List<Map<String, String>>> consumePendingAutoMovedApps() async =>
      const [];
}

EnforcementPlatform createEnforcementPlatform() {
  if (PlatformCapabilities.isAndroid) {
    return AndroidEnforcementPlatform();
  }
  if (PlatformCapabilities.isIOS) {
    return IosEnforcementPlatform();
  }
  return NoopEnforcementPlatform();
}
