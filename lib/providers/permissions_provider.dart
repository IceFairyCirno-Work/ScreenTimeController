import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_permission.dart';
import '../services/permissions_service.dart';

class PermissionsProvider extends ChangeNotifier {
  static const _notificationsEnabledKey = 'notifications_enabled';

  final PermissionsService _service = PermissionsService();

  final Map<AppPermissionType, bool> _granted = {
    for (final type in AppPermissionType.values) type: false,
  };

  bool _notificationsEnabled = true;
  bool _initialized = false;

  bool get initialized => _initialized;
  bool get notificationsEnabled => _notificationsEnabled;

  bool get allRequiredGranted =>
      platformRequiredPermissions.every((type) => _granted[type] == true);

  bool isGranted(AppPermissionType type) => _granted[type] ?? false;

  /// Effective on-state for the notifications toggle in settings.
  bool get notificationsOn =>
      isGranted(AppPermissionType.notifications) && _notificationsEnabled;

  void ensureInitializedForStartup() {
    if (_initialized) return;
    _initialized = true;
    notifyListeners();
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 8),
      );
      _notificationsEnabled = prefs.getBool(_notificationsEnabledKey) ?? true;
      await refresh().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          debugPrint('Permission refresh timed out during startup');
        },
      );
    } catch (e, stack) {
      debugPrint('Failed to load permissions: $e\n$stack');
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    final results = await Future.wait(
      AppPermissionType.values.map((type) async => (type, await _service.isGranted(type))),
    );
    for (final (type, granted) in results) {
      _granted[type] = granted;
    }
    notifyListeners();
  }

  Future<void> request(AppPermissionType type) async {
    await _service.request(type);
  }

  /// Opens settings for the first required permission that is not yet granted.
  Future<void> requestNextRequired() async {
    for (final type in platformRequiredPermissions) {
      if (!isGranted(type)) {
        await request(type);
        return;
      }
    }
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    if (enabled) {
      if (!isGranted(AppPermissionType.notifications)) {
        await request(AppPermissionType.notifications);
        await refresh();
      }
      _notificationsEnabled = isGranted(AppPermissionType.notifications);
    } else {
      _notificationsEnabled = false;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabledKey, _notificationsEnabled);
    notifyListeners();
  }

  Future<void> onToggle(AppPermissionType type, bool value) async {
    if (type.isRequired) {
      if (!value && isGranted(type)) return;
      if (value && !isGranted(type)) {
        await request(type);
      }
      return;
    }

    if (type == AppPermissionType.notifications) {
      await setNotificationsEnabled(value);
      return;
    }

    if (type == AppPermissionType.screenTimeApi) {
      if (value && !isGranted(type)) {
        await request(type);
        await refresh();
      }
      return;
    }
  }
}
