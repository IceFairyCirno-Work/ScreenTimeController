import 'package:flutter/foundation.dart';

import '../models/device_pickup_times.dart';
import '../models/screen_time_data.dart';
import '../utils/platform_capabilities.dart';
import 'platform/app_selection_service.dart';
import 'platform/usage_stats_platform.dart';

/// Reads screen-time data via a platform [UsageStatsPlatform].
///
/// Android usage calculation lives in native Kotlin. iOS calls scaffold
/// MethodChannels that return safe defaults until Family Controls is enabled.
class ScreenTimeService {
  ScreenTimeService({
    UsageStatsPlatform? platform,
    AppSelectionPlatform? appSelection,
  })  : _platform = platform ?? createUsageStatsPlatform(),
        _appSelection = appSelection ?? createAppSelectionPlatform();

  final UsageStatsPlatform _platform;
  final AppSelectionPlatform _appSelection;

  /// Minimum foreground duration for an app to appear in lists (matches native).
  static const minUsageMs = 60000;

  Future<bool> hasUsagePermission() => _platform.hasUsagePermission();

  Future<void> openUsagePermissionSettings() =>
      _platform.openUsagePermissionSettings();

  Future<ScreenTimeData> fetchUsageData() async {
    if (!PlatformCapabilities.supportsRealUsageStats &&
        !PlatformCapabilities.supportsIosScreenTimeApi) {
      return ScreenTimeData.empty;
    }

    if (!await hasUsagePermission()) {
      return ScreenTimeData.empty.copyWith(hasPermission: false);
    }

    try {
      final result = await _platform.fetchUsagePayload();
      if (result == null) {
        return ScreenTimeData.empty.copyWith(hasPermission: true);
      }
      return _parseUsagePayload(result);
    } catch (e) {
      debugPrint('Screen time fetch error: $e');
      return ScreenTimeData.empty;
    }
  }

  Future<ScreenTimeData> _parseUsagePayload(Map<Object?, Object?> payload) async {
    final todayTotalMs = (payload['todayTotalMs'] as num?)?.toInt() ?? 0;
    final weekTotalMs = (payload['weekTotalMs'] as num?)?.toInt() ?? 0;
    final nightUsageMinutes =
        (payload['nightUsageMinutes'] as num?)?.toInt() ?? 0;
    final weekNightUsageMinutes =
        (payload['weekNightUsageMinutes'] as num?)?.toInt() ?? 0;
    final appsRaw = payload['apps'] as List<Object?>? ?? [];
    final weekAppsRaw = payload['weekApps'] as List<Object?>? ?? [];

    final appEntries = <({String package, String name, int usageMs})>[];
    for (final item in appsRaw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item.cast<String, dynamic>());
      final usageMs = (map['usageMs'] as num?)?.toInt() ?? 0;
      if (usageMs < minUsageMs) continue;

      final package = map['package'] as String? ?? '';
      final name = map['name'] as String? ?? package;
      if (package.isEmpty) continue;

      appEntries.add((package: package, name: name, usageMs: usageMs));
    }

    final weekAppEntries = _parseAppEntries(weekAppsRaw);

    final topApps = await Future.wait(
      appEntries.map((entry) async {
        final iconBytes = await getAppIcon(entry.package);
        return AppUsageItem(
          appName: entry.name,
          packageName: entry.package,
          usage: Duration(milliseconds: entry.usageMs),
          iconBytes: iconBytes,
        );
      }),
    );

    final weekTopApps = weekAppEntries
        .map(
          (entry) => AppUsageItem(
            appName: entry.name,
            packageName: entry.package,
            usage: Duration(milliseconds: entry.usageMs),
          ),
        )
        .toList();

    return ScreenTimeData(
      todayTotal: Duration(milliseconds: todayTotalMs),
      weekTotal: Duration(milliseconds: weekTotalMs),
      topApps: topApps,
      weekTopApps: weekTopApps,
      hasPermission: true,
      nightUsageMinutes: nightUsageMinutes,
      weekNightUsageMinutes: weekNightUsageMinutes,
    );
  }

  List<({String package, String name, int usageMs})> _parseAppEntries(
    List<Object?> raw,
  ) {
    final entries = <({String package, String name, int usageMs})>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item.cast<String, dynamic>());
      final usageMs = (map['usageMs'] as num?)?.toInt() ?? 0;
      if (usageMs < minUsageMs) continue;

      final package = map['package'] as String? ?? '';
      final name = map['name'] as String? ?? package;
      if (package.isEmpty) continue;

      entries.add((package: package, name: name, usageMs: usageMs));
    }
    return entries;
  }

  Future<Uint8List?> getAppIcon(String packageName) =>
      _platform.getAppIcon(packageName);

  /// Returns all user-installable apps with today's foreground usage and icons.
  Future<List<AppUsageItem>> getInstalledApps() =>
      _appSelection.getInstalledApps();

  /// Total foreground screen time for a calendar day (local timezone).
  ///
  /// Returns `null` when usage permission is missing or the native call fails.
  Future<int?> fetchDayTotalMs(DateTime day) => _platform.fetchDayTotalMs(day);

  Future<int?> fetchDayNightUsageMinutes(DateTime day) =>
      _platform.fetchDayNightUsageMinutes(day);

  Future<List<AppUsageItem>> fetchDayApps(DateTime day) =>
      _platform.fetchDayApps(day);

  Future<DevicePickupTimes> fetchDayPickupTimes(DateTime day) async {
    try {
      final result = await _platform.fetchDayPickupTimes(day);
      if (result == null) return DevicePickupTimes.empty;

      final firstMs = (result['firstPickupMs'] as num?)?.toInt();
      final lastMs = (result['lastPickupMs'] as num?)?.toInt();

      return DevicePickupTimes(
        firstPickup: firstMs != null
            ? DateTime.fromMillisecondsSinceEpoch(firstMs)
            : null,
        lastPickup: lastMs != null
            ? DateTime.fromMillisecondsSinceEpoch(lastMs)
            : null,
      );
    } catch (e) {
      debugPrint('Day pickup fetch error: $e');
      return DevicePickupTimes.empty;
    }
  }

  Future<BlockedAppTodayStats> fetchBlockedAppTodayStats(
    String packageName,
  ) async {
    if (packageName.isEmpty) {
      return BlockedAppTodayStats.empty;
    }

    try {
      final result =
          await _platform.fetchBlockedAppTodayStats(packageName);
      if (result == null) return BlockedAppTodayStats.empty;

      final opens = (result['opens'] as num?)?.toInt() ?? 0;
      final usageMs = (result['usageMs'] as num?)?.toInt() ?? 0;
      final unblocks = (result['unblocks'] as num?)?.toInt() ?? 0;
      return BlockedAppTodayStats(
        opens: opens,
        screenTime: Duration(milliseconds: usageMs),
        unblocks: unblocks,
      );
    } catch (e) {
      debugPrint('Blocked app stats fetch error: $e');
      return BlockedAppTodayStats.empty;
    }
  }

  Future<int> fetchOpensSince(
    String packageName,
    DateTime since,
  ) =>
      _platform.fetchOpensSince(packageName, since);

  Future<void> recordAppUnblock(String packageName) =>
      _platform.recordAppUnblock(packageName);
}
