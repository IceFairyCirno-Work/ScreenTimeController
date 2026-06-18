import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../models/app_rule.dart';
import '../../models/screen_time_data.dart';
import '../../utils/platform_capabilities.dart';
import 'usage_stats_platform.dart';

/// Platform abstraction for installed-app listing and future picker flows.
abstract class AppSelectionPlatform {
  Future<List<AppUsageItem>> getInstalledApps();
}

class AndroidAppSelectionPlatform implements AppSelectionPlatform {
  AndroidAppSelectionPlatform({UsageStatsPlatform? usageStats})
      : _usageStats = usageStats ?? createUsageStatsPlatform();

  final UsageStatsPlatform _usageStats;

  @override
  Future<List<AppUsageItem>> getInstalledApps() async {
    if (!await _usageStats.hasUsagePermission()) return const [];

    final result = await _usageStats.fetchInstalledAppsPayload();
    return parseInstalledAppsPayload(result);
  }
}

class IosAppSelectionPlatform implements AppSelectionPlatform {
  IosAppSelectionPlatform({UsageStatsPlatform? usageStats})
      : _usageStats = usageStats ?? createUsageStatsPlatform();

  final UsageStatsPlatform _usageStats;

  @override
  Future<List<AppUsageItem>> getInstalledApps() async {
    final result = await _usageStats.fetchInstalledAppsPayload();
    return parseInstalledAppsPayload(result);
  }
}

class NoopAppSelectionPlatform implements AppSelectionPlatform {
  @override
  Future<List<AppUsageItem>> getInstalledApps() async => const [];
}

AppSelectionPlatform createAppSelectionPlatform() {
  if (PlatformCapabilities.isAndroid) {
    return AndroidAppSelectionPlatform();
  }
  if (PlatformCapabilities.isIOS) {
    return IosAppSelectionPlatform();
  }
  return NoopAppSelectionPlatform();
}

/// Future hook for FamilyActivityPicker — returns selected [AppRuleItem]s.
abstract class AppPickerPlatform {
  Future<List<AppRuleItem>> pickApps();
}

class IosAppPickerPlatform implements AppPickerPlatform {
  static const _channel =
      MethodChannel('com.screentime.screen_time_controller/usage_data');

  @override
  Future<List<AppRuleItem>> pickApps() async {
    try {
      final result = await _channel.invokeMethod<List<Object?>>('pickApps');
      if (result == null) return const [];

      final items = <AppRuleItem>[];
      for (final item in result) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item.cast<String, dynamic>());
        final token = map['iosApplicationToken'] as String?;
        final name = map['appName'] as String? ?? '';
        if (token == null || token.isEmpty) continue;
        items.add(AppRuleItem(
          packageName: token,
          appName: name.isEmpty ? 'App' : name,
          iosApplicationToken: token,
        ));
      }
      return items;
    } on MissingPluginException {
      return const [];
    } on PlatformException catch (e) {
      debugPrint('iOS pickApps failed: $e');
      return const [];
    }
  }
}

AppPickerPlatform? createAppPickerPlatform() {
  if (PlatformCapabilities.isIOS) {
    return IosAppPickerPlatform();
  }
  return null;
}
