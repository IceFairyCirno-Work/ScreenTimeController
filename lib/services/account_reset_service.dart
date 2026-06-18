import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_data.dart';
import '../providers/emergency_pass_provider.dart';
import '../providers/folder_apps_provider.dart';
import '../providers/gem_achievement_provider.dart';
import '../providers/permissions_provider.dart';
import '../providers/rules_provider.dart';
import '../providers/timer_provider.dart';
import 'app_blocking_service.dart';
import 'app_icon_cache.dart';
import 'installed_apps_cache.dart';
import 'rule_notification_service.dart';

/// Wipes all local app data and returns the user to onboarding.
class AccountResetService {
  AccountResetService._();

  static final AccountResetService instance = AccountResetService._();

  final AppBlockingService _blockingService = AppBlockingService();

  Future<void> deleteAccount(BuildContext context) async {
    final timer = context.read<TimerProvider>();
    if (timer.isRunning) {
      await timer.stopTimer();
    }

    await RuleNotificationService.instance.cancelAll();
    await _blockingService.clearBlockedPackages();
    await _blockingService.clearActiveTimer();

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    AppIconCache.instance.clear();
    InstalledAppsCache.instance.clear();

    if (!context.mounted) return;

    context.read<RulesProvider>().resetAfterAccountDeletion();
    context.read<FolderAppsProvider>().resetAfterAccountDeletion();
    context.read<TimerProvider>().resetAfterAccountDeletion();
    context.read<EmergencyPassProvider>().resetAfterAccountDeletion();
    context.read<GemAchievementProvider>().resetAfterAccountDeletion();
    unawaited(context.read<FolderAppsProvider>().trySeedDefaultFolders());

    final permissions = context.read<PermissionsProvider>();
    await permissions.load();
    RuleNotificationService.instance
        .setEnabled(permissions.notificationsOn);

    if (!context.mounted) return;
    context.read<UserData>().resetAccount();
  }
}
