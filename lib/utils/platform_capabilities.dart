import 'dart:io';

import 'package:flutter/foundation.dart';

/// Platform feature flags used to branch Android-only native integrations.
class PlatformCapabilities {
  PlatformCapabilities._();

  static bool get isAndroid => !kIsWeb && Platform.isAndroid;

  static bool get isIOS => !kIsWeb && Platform.isIOS;

  /// Native usage stats, app blocking, overlay, and accessibility services.
  static bool get supportsNativeBlocking => isAndroid;

  /// OS-level screen time and installed-app lists.
  static bool get supportsUsageStats => isAndroid;

  /// Installed-app list picker (Android package manager; iOS FamilyActivityPicker).
  static bool get supportsInstalledAppPicker => isAndroid;

  /// Real OS usage stats (not onboarding estimate).
  static bool get supportsRealUsageStats => isAndroid;

  /// Native website blocking in browser.
  static bool get supportsWebsiteBlocking => isAndroid;

  /// Distracting-app overlay pill (SYSTEM_ALERT_WINDOW).
  static bool get supportsDistractingOverlay => isAndroid;

  /// Native rule/timer enforcement (Accessibility / ManagedSettings).
  static bool get supportsNativeEnforcement => isAndroid;

  /// Screen Time API scaffold present on iOS (Family Controls channels).
  static bool get supportsIosScreenTimeApi => isIOS;
}
