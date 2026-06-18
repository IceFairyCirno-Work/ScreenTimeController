import 'package:flutter/material.dart';

import '../utils/platform_capabilities.dart';

/// App permissions surfaced in onboarding and settings.
enum AppPermissionType {
  screenTime,
  overlay,
  accessibility,
  notifications,
  screenTimeApi,
}

extension AppPermissionTypeX on AppPermissionType {
  String get title {
    switch (this) {
      case AppPermissionType.screenTime:
        return 'Screen time';
      case AppPermissionType.overlay:
        return 'Display over other apps';
      case AppPermissionType.accessibility:
        return 'Accessibility';
      case AppPermissionType.notifications:
        return 'Notifications';
      case AppPermissionType.screenTimeApi:
        return 'Screen Time';
    }
  }

  String get description {
    if (PlatformCapabilities.isIOS) {
      switch (this) {
        case AppPermissionType.screenTime:
        case AppPermissionType.overlay:
        case AppPermissionType.accessibility:
          return '';
        case AppPermissionType.notifications:
          return 'Get reminders when rules start and when unblock breaks end.';
        case AppPermissionType.screenTimeApi:
          return 'Required to block apps and read usage on iOS.';
      }
    }

    switch (this) {
      case AppPermissionType.screenTime:
        return 'Lets Silo show you your daily screen time and progress.';
      case AppPermissionType.overlay:
        return 'So Silo can gently help you pause before opening distracting apps.';
      case AppPermissionType.accessibility:
        return 'This is required to detect websites you want to block.';
      case AppPermissionType.notifications:
        return 'Get reminders and unblock alerts';
      case AppPermissionType.screenTimeApi:
        return 'Required to block apps and read usage on iOS.';
    }
  }

  IconData get icon {
    switch (this) {
      case AppPermissionType.screenTime:
        return Icons.hourglass_bottom_outlined;
      case AppPermissionType.overlay:
        return Icons.picture_in_picture_alt_outlined;
      case AppPermissionType.accessibility:
        return Icons.accessibility_new_outlined;
      case AppPermissionType.notifications:
        return Icons.notifications_outlined;
      case AppPermissionType.screenTimeApi:
        return Icons.hourglass_top_outlined;
    }
  }

  bool get isRequired {
    switch (this) {
      case AppPermissionType.screenTime:
      case AppPermissionType.overlay:
      case AppPermissionType.accessibility:
        return true;
      case AppPermissionType.notifications:
      case AppPermissionType.screenTimeApi:
        return false;
    }
  }
}

const requiredPermissions = [
  AppPermissionType.screenTime,
  AppPermissionType.overlay,
  AppPermissionType.accessibility,
];

const otherPermissions = [
  AppPermissionType.notifications,
];

/// Required permissions for the current platform.
List<AppPermissionType> get platformRequiredPermissions {
  if (PlatformCapabilities.isIOS) return const [];
  return requiredPermissions;
}

/// Optional permissions for the current platform.
List<AppPermissionType> get platformOtherPermissions {
  if (PlatformCapabilities.isIOS) {
    return const [
      AppPermissionType.notifications,
      AppPermissionType.screenTimeApi,
    ];
  }
  return otherPermissions;
}

/// All permissions shown in onboarding and settings for the current platform.
List<AppPermissionType> get platformAllPermissions => [
      ...platformRequiredPermissions,
      ...platformOtherPermissions,
    ];
