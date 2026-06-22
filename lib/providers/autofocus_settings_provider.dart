import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User preferences for Autofocus interventions (e.g. distracting-app overlay).
class AutofocusSettingsProvider extends ChangeNotifier {
  static const _overlayEnabledKey = 'distracting_overlay_enabled';

  bool _overlayEnabled = true;
  bool _initialized = false;

  bool get initialized => _initialized;
  bool get overlayEnabled => _overlayEnabled;

  void ensureInitializedForStartup() {
    if (_initialized) return;
    _initialized = true;
    notifyListeners();
  }

  Future<void> load() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 8),
      );
      _overlayEnabled = prefs.getBool(_overlayEnabledKey) ?? true;
    } on TimeoutException {
      debugPrint('Autofocus settings load timed out');
    } catch (e, stack) {
      debugPrint('Failed to load autofocus settings: $e\n$stack');
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> setOverlayEnabled(bool enabled) async {
    if (_overlayEnabled == enabled) return;
    _overlayEnabled = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_overlayEnabledKey, enabled);
    } catch (e, stack) {
      debugPrint('Failed to save overlay setting: $e\n$stack');
    }
  }

  void resetAfterAccountDeletion() {
    _overlayEnabled = true;
    notifyListeners();
  }
}
