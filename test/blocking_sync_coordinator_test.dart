import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screen_time_controller/models/app_rule.dart';
import 'package:screen_time_controller/models/focus_timer_blocking_state.dart';
import 'package:screen_time_controller/providers/rules_provider.dart';
import 'package:screen_time_controller/services/blocking_sync_coordinator.dart';
import 'package:screen_time_controller/utils/website_helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const instagram = 'com.instagram.android';
  const tiktok = 'com.zhiliaoapp.musically';
  const phone = 'com.android.dialer';

  final at = DateTime(2026, 6, 22, 12);
  final app = AppRuleItem(packageName: instagram, appName: 'Instagram');
  final tiktokApp = AppRuleItem(packageName: tiktok, appName: 'TikTok');
  final websiteApp = AppRuleItem(
    packageName: WebsiteHelpers.packageForDomain('twitter.com'),
    appName: 'Twitter',
  );

  late RulesProvider rules;

  SessionRule allDaySession({
    required String id,
    required List<AppRuleItem> apps,
    Map<String, DateTime> unblockedUntilByPackage = const {},
    Map<String, DateTime> unblockedStartedAtByPackage = const {},
  }) {
    return SessionRule(
      id: id,
      name: 'Test session',
      createdAt: DateTime(2026, 1, 1),
      startTime: const TimeOfDay(hour: 0, minute: 0),
      endTime: const TimeOfDay(hour: 23, minute: 59),
      repeatDays: RepeatDay.all,
      apps: apps,
      unblockedUntilByPackage: unblockedUntilByPackage,
      unblockedStartedAtByPackage: unblockedStartedAtByPackage,
    );
  }

  FocusTimerBlockingState runningTimer(List<AppRuleItem> apps) =>
      FocusTimerBlockingState(isRunning: true, blockedApps: apps);

  const stoppedTimer = FocusTimerBlockingState(isRunning: false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    rules = RulesProvider();
    await rules.loadRules();
  });

  group('computeBlockedPackages timer edge cases', () {
    test('blocks timer-only apps with no active rules', () {
      final blocked = computeBlockedPackages(
        rules,
        runningTimer([app]),
        at: at,
      );

      expect(blocked, {instagram});
    });

    test('does not block timer apps when timer is stopped', () {
      final blocked = computeBlockedPackages(
        rules,
        FocusTimerBlockingState(isRunning: false, blockedApps: [app]),
        at: at,
      );

      expect(blocked, isEmpty);
    });

    test('blocks timer app and separately rule-blocked app', () async {
      await rules.addRule(
        allDaySession(id: 'session-tiktok', apps: [tiktokApp]),
      );

      final blocked = computeBlockedPackages(
        rules,
        runningTimer([app]),
        at: at,
      );

      expect(blocked, {instagram, tiktok});
    });

    test('timer overrides active rule temporary unblock', () async {
      final unblockUntil = at.add(const Duration(minutes: 15));
      await rules.addRule(
        allDaySession(
          id: 'session-unblocked',
          apps: [app],
          unblockedUntilByPackage: {instagram: unblockUntil},
          unblockedStartedAtByPackage: {instagram: at},
        ),
      );

      expect(rules.isAppBlocked(instagram, at), isFalse);

      final blocked = computeBlockedPackages(
        rules,
        runningTimer([app]),
        at: at,
      );

      expect(blocked, contains(instagram));
    });

    test('restores rule unblock behavior after timer stops', () async {
      final unblockUntil = at.add(const Duration(minutes: 15));
      await rules.addRule(
        allDaySession(
          id: 'session-unblocked',
          apps: [app],
          unblockedUntilByPackage: {instagram: unblockUntil},
          unblockedStartedAtByPackage: {instagram: at},
        ),
      );

      final blocked = computeBlockedPackages(
        rules,
        stoppedTimer,
        at: at,
      );

      expect(blocked, isNot(contains(instagram)));
    });

    test('skips always-allowed timer apps unless never-allowed wins', () {
      final blocked = computeBlockedPackages(
        rules,
        runningTimer([app]),
        at: at,
        alwaysAllowedPackages: {instagram},
      );

      expect(blocked, isEmpty);
    });

    test('never-allowed stays blocked even when also always-allowed', () {
      final blocked = computeBlockedPackages(
        rules,
        runningTimer([AppRuleItem(packageName: phone, appName: 'Phone')]),
        at: at,
        alwaysAllowedPackages: {phone},
        neverAllowedPackages: {phone},
      );

      expect(blocked, {phone});
    });

    test('emergency pass clears all blocking including timer apps', () {
      final blocked = computeBlockedPackages(
        rules,
        runningTimer([app]),
        at: at,
        emergencyPassActive: true,
      );

      expect(blocked, isEmpty);
    });

    test('ignores website entries in timer package blocking', () {
      final blocked = computeBlockedPackages(
        rules,
        runningTimer([websiteApp]),
        at: at,
      );

      expect(blocked, isEmpty);
    });
  });

  group('computeTemporaryUnblockUntilByPackage timer edge cases', () {
    test('omits timer-blocked packages while timer is running', () async {
      final unblockUntil = at.add(const Duration(minutes: 15));
      await rules.addRule(
        allDaySession(
          id: 'session-unblocked',
          apps: [app],
          unblockedUntilByPackage: {instagram: unblockUntil},
          unblockedStartedAtByPackage: {instagram: at},
        ),
      );

      final unblocks = computeTemporaryUnblockUntilByPackage(
        rules,
        runningTimer([app]),
        at: at,
      );

      expect(unblocks, isEmpty);
    });

    test('keeps rule unblock entries when timer is stopped', () async {
      final unblockUntil = at.add(const Duration(minutes: 15));
      await rules.addRule(
        allDaySession(
          id: 'session-unblocked',
          apps: [app],
          unblockedUntilByPackage: {instagram: unblockUntil},
          unblockedStartedAtByPackage: {instagram: at},
        ),
      );

      final unblocks = computeTemporaryUnblockUntilByPackage(
        rules,
        stoppedTimer,
        at: at,
      );

      expect(unblocks[instagram], unblockUntil.millisecondsSinceEpoch);
    });

    test('returns empty map during emergency pass', () async {
      final unblockUntil = at.add(const Duration(minutes: 15));
      await rules.addRule(
        allDaySession(
          id: 'session-unblocked',
          apps: [app],
          unblockedUntilByPackage: {instagram: unblockUntil},
          unblockedStartedAtByPackage: {instagram: at},
        ),
      );

      final unblocks = computeTemporaryUnblockUntilByPackage(
        rules,
        runningTimer([app]),
        at: at,
        emergencyPassActive: true,
      );

      expect(unblocks, isEmpty);
    });
  });

  group('computeBlockedDomains timer edge cases', () {
    test('blocks timer websites while timer is running', () {
      final domains = computeBlockedDomains(
        rules,
        runningTimer([websiteApp]),
        at: at,
      );

      expect(domains, {'twitter.com'});
    });

    test('omits timer website domain unblocks while timer is running', () async {
      final unblockUntil = at.add(const Duration(minutes: 15));
      await rules.addRule(
        allDaySession(
          id: 'session-website',
          apps: [websiteApp],
          unblockedUntilByPackage: {
            websiteApp.packageName: unblockUntil,
          },
          unblockedStartedAtByPackage: {
            websiteApp.packageName: at,
          },
        ),
      );

      final domainUnblocks = computeTemporaryUnblockUntilByDomain(
        rules,
        runningTimer([websiteApp]),
        at: at,
      );

      expect(domainUnblocks, isEmpty);
    });
  });
}
