import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:usage_stats/usage_stats.dart';

import '../../models/screen_time_data.dart';
import '../../utils/platform_capabilities.dart';

/// Platform abstraction for usage stats and related native calls.
abstract class UsageStatsPlatform {
  Future<bool> hasUsagePermission();
  Future<void> openUsagePermissionSettings();
  Future<Map<Object?, Object?>?> fetchUsagePayload();
  Future<Uint8List?> getAppIcon(String packageName);
  Future<List<Object?>?> fetchInstalledAppsPayload();
  Future<int?> fetchDayTotalMs(DateTime day);
  Future<int?> fetchDayNightUsageMinutes(DateTime day);
  Future<List<AppUsageItem>> fetchDayApps(DateTime day);
  Future<Map<Object?, Object?>?> fetchDayPickupTimes(DateTime day);
  Future<Map<Object?, Object?>?> fetchBlockedAppTodayStats(String packageName);
  Future<int> fetchOpensSince(String packageName, DateTime since);
  Future<void> recordAppUnblock(String packageName);
}

class AndroidUsageStatsPlatform implements UsageStatsPlatform {
  static const _channel =
      MethodChannel('com.screentime.screen_time_controller/usage_data');

  @override
  Future<bool> hasUsagePermission() async {
    try {
      final result = await _channel
          .invokeMethod<bool>('hasUsagePermission')
          .timeout(const Duration(seconds: 5));
      if (result != null) return result;
    } on TimeoutException {
      debugPrint('Native usage permission check timed out');
      return false;
    } on MissingPluginException {
      // Fall through to usage_stats plugin.
    } on PlatformException {
      return false;
    }
    try {
      return await UsageStats.checkUsagePermission()
              .timeout(const Duration(seconds: 5)) ??
          false;
    } on TimeoutException {
      debugPrint('Usage stats permission check timed out');
      return false;
    } catch (e) {
      debugPrint('Permission check failed: $e');
      return false;
    }
  }

  @override
  Future<void> openUsagePermissionSettings() async {
    try {
      await _channel.invokeMethod<void>('openUsageSettings');
    } on MissingPluginException {
      await UsageStats.grantUsagePermission();
    }
  }

  @override
  Future<Map<Object?, Object?>?> fetchUsagePayload() async {
    try {
      return await _channel.invokeMethod<Map<Object?, Object?>>('getUsageData');
    } on MissingPluginException {
      debugPrint('Native usage channel unavailable');
      return null;
    } on PlatformException catch (e) {
      debugPrint('Native usage fetch failed: $e');
      return null;
    }
  }

  @override
  Future<Uint8List?> getAppIcon(String packageName) async {
    try {
      final nativeBytes = await _channel.invokeMethod<Uint8List>(
        'getAppIcon',
        {'packageName': packageName},
      );
      if (nativeBytes != null && nativeBytes.isNotEmpty) {
        return nativeBytes;
      }
    } on MissingPluginException {
      // Fall through to usage_stats plugin.
    } on PlatformException catch (e) {
      debugPrint('Native app icon fetch failed for $packageName: $e');
    }
    try {
      return await UsageStats.getAppIcon(packageName);
    } catch (e) {
      debugPrint('App icon fetch failed for $packageName: $e');
      return null;
    }
  }

  @override
  Future<List<Object?>?> fetchInstalledAppsPayload() async {
    try {
      return await _channel.invokeMethod<List<Object?>>('getInstalledApps');
    } on MissingPluginException {
      debugPrint('Native getInstalledApps unavailable');
      return null;
    } on PlatformException catch (e) {
      debugPrint('Installed apps fetch failed: $e');
      return null;
    }
  }

  @override
  Future<int?> fetchDayTotalMs(DateTime day) async {
    try {
      return await _channel.invokeMethod<int>(
        'getDayTotalMs',
        _dayArgs(day),
      );
    } on MissingPluginException {
      debugPrint('Native getDayTotalMs unavailable');
      return null;
    } on PlatformException catch (e) {
      debugPrint('Day total fetch failed: $e');
      return null;
    }
  }

  @override
  Future<int?> fetchDayNightUsageMinutes(DateTime day) async {
    try {
      return await _channel.invokeMethod<int>(
        'getDayNightUsageMinutes',
        _dayArgs(day),
      );
    } on MissingPluginException {
      debugPrint('Native getDayNightUsageMinutes unavailable');
      return null;
    } on PlatformException catch (e) {
      debugPrint('Day night usage fetch failed: $e');
      return null;
    }
  }

  @override
  Future<List<AppUsageItem>> fetchDayApps(DateTime day) async {
    try {
      final result = await _channel.invokeMethod<List<Object?>>(
        'getDayApps',
        _dayArgs(day),
      );
      return parseDayAppsPayload(result);
    } on MissingPluginException {
      debugPrint('Native getDayApps unavailable');
      return const [];
    } on PlatformException catch (e) {
      debugPrint('Day apps fetch failed: $e');
      return const [];
    }
  }

  Map<String, int> _dayArgs(DateTime day) => {
        'year': day.year,
        'month': day.month,
        'day': day.day,
      };

  @override
  Future<Map<Object?, Object?>?> fetchDayPickupTimes(DateTime day) async {
    try {
      return await _channel.invokeMethod<Map<Object?, Object?>>(
        'getDayPickupTimes',
        _dayArgs(day),
      );
    } on MissingPluginException {
      debugPrint('Native getDayPickupTimes unavailable');
      return null;
    } on PlatformException catch (e) {
      debugPrint('Day pickup fetch failed: $e');
      return null;
    }
  }

  @override
  Future<Map<Object?, Object?>?> fetchBlockedAppTodayStats(
    String packageName,
  ) async {
    try {
      return await _channel.invokeMethod<Map<Object?, Object?>>(
        'getBlockedAppTodayStats',
        {'packageName': packageName},
      );
    } on MissingPluginException {
      debugPrint('Native getBlockedAppTodayStats unavailable');
      return null;
    } on PlatformException catch (e) {
      debugPrint('Blocked app stats fetch failed: $e');
      return null;
    }
  }

  @override
  Future<int> fetchOpensSince(String packageName, DateTime since) async {
    try {
      final result = await _channel.invokeMethod<int>(
        'getOpensSince',
        {
          'packageName': packageName,
          'sinceMillis': since.millisecondsSinceEpoch,
        },
      );
      return result ?? 0;
    } on MissingPluginException {
      debugPrint('Native getOpensSince unavailable');
      return 0;
    } on PlatformException catch (e) {
      debugPrint('Opens since fetch failed: $e');
      return 0;
    }
  }

  @override
  Future<void> recordAppUnblock(String packageName) async {
    try {
      await _channel.invokeMethod<void>(
        'recordAppUnblock',
        {'packageName': packageName},
      );
    } on MissingPluginException {
      debugPrint('Native recordAppUnblock unavailable');
    } on PlatformException catch (e) {
      debugPrint('Record app unblock failed: $e');
    }
  }
}

class IosUsageStatsPlatform implements UsageStatsPlatform {
  static const _channel =
      MethodChannel('com.screentime.screen_time_controller/usage_data');

  @override
  Future<bool> hasUsagePermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasUsagePermission') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      debugPrint('iOS usage permission check failed: $e');
      return false;
    }
  }

  @override
  Future<void> openUsagePermissionSettings() async {
    try {
      await _channel.invokeMethod<void>('openUsageSettings');
    } on MissingPluginException catch (e) {
      debugPrint('iOS usage settings unavailable: $e');
    } on PlatformException catch (e) {
      debugPrint('iOS usage settings failed: $e');
    }
  }

  @override
  Future<Map<Object?, Object?>?> fetchUsagePayload() async {
    try {
      return await _channel.invokeMethod<Map<Object?, Object?>>('getUsageData');
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('iOS usage fetch failed: $e');
      return null;
    }
  }

  @override
  Future<Uint8List?> getAppIcon(String packageName) async => null;

  @override
  Future<List<Object?>?> fetchInstalledAppsPayload() async {
    try {
      return await _channel.invokeMethod<List<Object?>>('getInstalledApps');
    } on MissingPluginException {
      return const [];
    } on PlatformException catch (e) {
      debugPrint('iOS installed apps fetch failed: $e');
      return const [];
    }
  }

  @override
  Future<int?> fetchDayTotalMs(DateTime day) async {
    try {
      return await _channel.invokeMethod<int>(
        'getDayTotalMs',
        {
          'year': day.year,
          'month': day.month,
          'day': day.day,
        },
      );
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('iOS day total fetch failed: $e');
      return null;
    }
  }

  @override
  Future<int?> fetchDayNightUsageMinutes(DateTime day) async => null;

  @override
  Future<List<AppUsageItem>> fetchDayApps(DateTime day) async => const [];

  @override
  Future<Map<Object?, Object?>?> fetchDayPickupTimes(DateTime day) async {
    try {
      return await _channel.invokeMethod<Map<Object?, Object?>>(
        'getDayPickupTimes',
        {
          'year': day.year,
          'month': day.month,
          'day': day.day,
        },
      );
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('iOS day pickup fetch failed: $e');
      return null;
    }
  }

  @override
  Future<Map<Object?, Object?>?> fetchBlockedAppTodayStats(
    String packageName,
  ) async {
    try {
      return await _channel.invokeMethod<Map<Object?, Object?>>(
        'getBlockedAppTodayStats',
        {'packageName': packageName},
      );
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('iOS blocked app stats fetch failed: $e');
      return null;
    }
  }

  @override
  Future<int> fetchOpensSince(String packageName, DateTime since) async => 0;

  @override
  Future<void> recordAppUnblock(String packageName) async {
    try {
      await _channel.invokeMethod<void>(
        'recordAppUnblock',
        {'packageName': packageName},
      );
    } on MissingPluginException {
      // no-op
    } on PlatformException catch (e) {
      debugPrint('iOS record app unblock failed: $e');
    }
  }
}

UsageStatsPlatform createUsageStatsPlatform() {
  if (PlatformCapabilities.isAndroid) {
    return AndroidUsageStatsPlatform();
  }
  if (PlatformCapabilities.isIOS) {
    return IosUsageStatsPlatform();
  }
  return _NoopUsageStatsPlatform();
}

class _NoopUsageStatsPlatform implements UsageStatsPlatform {
  @override
  Future<bool> hasUsagePermission() async => false;

  @override
  Future<void> openUsagePermissionSettings() async {}

  @override
  Future<Map<Object?, Object?>?> fetchUsagePayload() async => null;

  @override
  Future<Uint8List?> getAppIcon(String packageName) async => null;

  @override
  Future<List<Object?>?> fetchInstalledAppsPayload() async => const [];

  @override
  Future<int?> fetchDayTotalMs(DateTime day) async => null;

  @override
  Future<int?> fetchDayNightUsageMinutes(DateTime day) async => null;

  @override
  Future<List<AppUsageItem>> fetchDayApps(DateTime day) async => const [];

  @override
  Future<Map<Object?, Object?>?> fetchDayPickupTimes(DateTime day) async => null;

  @override
  Future<Map<Object?, Object?>?> fetchBlockedAppTodayStats(
    String packageName,
  ) async =>
      null;

  @override
  Future<int> fetchOpensSince(String packageName, DateTime since) async => 0;

  @override
  Future<void> recordAppUnblock(String packageName) async {}
}

/// Parses installed-apps channel payload into [AppUsageItem] list.
List<AppUsageItem> parseInstalledAppsPayload(List<Object?>? result) {
  if (result == null) return const [];

  final items = <AppUsageItem>[];
  for (final item in result) {
    if (item is! Map) continue;
    final map = Map<String, dynamic>.from(item.cast<String, dynamic>());
    final package = map['package'] as String? ?? '';
    final name = map['name'] as String? ?? package;
    if (package.isEmpty) continue;
    final usageMs = (map['usageMs'] as num?)?.toInt() ?? 0;
    final iconB64 = map['iconBase64'] as String?;
    Uint8List? iconBytes;
    if (iconB64 != null && iconB64.isNotEmpty) {
      iconBytes = base64Decode(iconB64);
    }
    items.add(AppUsageItem(
      appName: name,
      packageName: package,
      usage: Duration(milliseconds: usageMs),
      iconBytes: iconBytes,
    ));
  }
  return items;
}

/// Parses per-day app usage payload (no icons).
List<AppUsageItem> parseDayAppsPayload(List<Object?>? result) {
  if (result == null) return const [];

  final items = <AppUsageItem>[];
  for (final item in result) {
    if (item is! Map) continue;
    final map = Map<String, dynamic>.from(item.cast<String, dynamic>());
    final package = map['package'] as String? ?? '';
    final name = map['name'] as String? ?? package;
    if (package.isEmpty) continue;
    final usageMs = (map['usageMs'] as num?)?.toInt() ?? 0;
    if (usageMs < 60000) continue;
    items.add(AppUsageItem(
      appName: name,
      packageName: package,
      usage: Duration(milliseconds: usageMs),
    ));
  }
  return items;
}
