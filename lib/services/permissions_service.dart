import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/app_permission.dart';
import '../utils/platform_capabilities.dart';
import 'screen_time_service.dart';

/// Checks and opens system settings for overlay, accessibility, and
/// notification permissions. Screen time reuses [ScreenTimeService].
class PermissionsService {
  static const _channel =
      MethodChannel('com.screentime.screen_time_controller/permissions');

  static const _notificationPermissionTimeout = Duration(minutes: 2);

  final ScreenTimeService _screenTimeService = ScreenTimeService();
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool get _isAndroid => PlatformCapabilities.isAndroid;

  Future<bool> isGranted(AppPermissionType type) async {
    if (PlatformCapabilities.isIOS) {
      switch (type) {
        case AppPermissionType.screenTime:
        case AppPermissionType.overlay:
        case AppPermissionType.accessibility:
          return false;
        case AppPermissionType.notifications:
          return _iosNotificationsGranted();
        case AppPermissionType.screenTimeApi:
          return _invokeBool('hasScreenTimeAuthorization');
      }
    }

    if (!_isAndroid) return false;

    switch (type) {
      case AppPermissionType.screenTime:
        return _screenTimeService.hasUsagePermission();
      case AppPermissionType.overlay:
        return _invokeBool('hasOverlayPermission');
      case AppPermissionType.accessibility:
        return _invokeBool('hasAccessibilityPermission');
      case AppPermissionType.notifications:
        return _invokeBool('hasNotificationPermission');
      case AppPermissionType.screenTimeApi:
        return false;
    }
  }

  Future<bool> request(AppPermissionType type) async {
    if (PlatformCapabilities.isIOS) {
      switch (type) {
        case AppPermissionType.screenTime:
        case AppPermissionType.overlay:
        case AppPermissionType.accessibility:
          return false;
        case AppPermissionType.notifications:
          return _requestIosNotifications();
        case AppPermissionType.screenTimeApi:
          return _requestScreenTimeAuthorization();
      }
    }

    if (!_isAndroid) return false;

    switch (type) {
      case AppPermissionType.screenTime:
        try {
          await _screenTimeService.openUsagePermissionSettings();
        } on PlatformException catch (e) {
          debugPrint('Failed to open usage settings: $e');
        } on MissingPluginException catch (e) {
          debugPrint('Usage settings plugin missing: $e');
        }
        return true;
      case AppPermissionType.overlay:
        await _invokeVoid('openOverlaySettings');
        return true;
      case AppPermissionType.accessibility:
        await _invokeVoid('openAccessibilitySettings');
        return true;
      case AppPermissionType.notifications:
        final granted = await _requestAndroidNotificationPermission();
        if (granted) return true;
        await _invokeVoid('openNotificationSettings');
        return true;
      case AppPermissionType.screenTimeApi:
        return false;
    }
  }

  Future<bool> _requestScreenTimeAuthorization() async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'requestScreenTimeAuthorization',
      );
      if (result == null) return false;
      final status = result['status'] as String?;
      if (status == 'authorized') return true;
      if (status == 'notConfigured') {
        await _invokeVoid('openScreenTimeSettings');
      }
      return false;
    } on PlatformException catch (e) {
      debugPrint('Screen Time authorization request failed: $e');
      return false;
    } on MissingPluginException catch (e) {
      debugPrint('Screen Time authorization plugin missing: $e');
      return false;
    }
  }

  Future<bool> _requestAndroidNotificationPermission() async {
    try {
      final granted = await _channel
          .invokeMethod<bool>('requestNotificationPermission')
          .timeout(
            _notificationPermissionTimeout,
            onTimeout: () {
              debugPrint('Notification permission request timed out');
              return false;
            },
          );
      return granted ?? false;
    } on PlatformException catch (e) {
      debugPrint('Notification permission request failed: $e');
      return false;
    } on MissingPluginException catch (e) {
      debugPrint('Notification permission plugin missing: $e');
      return false;
    } on TimeoutException catch (e) {
      debugPrint('Notification permission request timed out: $e');
      return false;
    }
  }

  Future<bool> _iosNotificationsGranted() async {
    final ios = _notificationsPlugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios == null) return false;

    try {
      final options = await ios.checkPermissions();
      return options?.isEnabled ?? false;
    } catch (e) {
      debugPrint('iOS notification permission check failed: $e');
      return false;
    }
  }

  Future<bool> _requestIosNotifications() async {
    final ios = _notificationsPlugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios == null) return false;

    try {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    } catch (e) {
      debugPrint('iOS notification permission request failed: $e');
      return false;
    }
  }

  Future<void> _invokeVoid(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on PlatformException catch (e) {
      debugPrint('Permission channel failed ($method): $e');
    } on MissingPluginException catch (e) {
      debugPrint('Permission plugin missing ($method): $e');
    }
  }

  Future<bool> _invokeBool(String method) async {
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } on PlatformException catch (e) {
      debugPrint('Permission check failed ($method): $e');
      return false;
    } on MissingPluginException catch (e) {
      debugPrint('Permission plugin missing ($method): $e');
      return false;
    }
  }
}
