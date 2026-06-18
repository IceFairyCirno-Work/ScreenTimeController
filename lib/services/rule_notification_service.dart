import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/app_rule.dart';
import '../utils/platform_capabilities.dart';
import '../utils/rule_notification_schedule.dart';

/// Local notifications for schedule rules and unblock events.
class RuleNotificationService {
  RuleNotificationService._();

  static final RuleNotificationService instance = RuleNotificationService._();

  static const _channelId = 'rule_notifications';
  static const _channelName = 'Rules & unblocks';
  static const _channelDescription =
      'Reminders when rules start and when unblock breaks end.';

  static const _startsSoonOffset = Duration(minutes: 5);

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _enabled = true;
  final Set<String> _scheduledRuleIds = {};

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.local);
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);

    if (PlatformCapabilities.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.high,
        ),
      );
    }

    _initialized = true;
  }

  void setEnabled(bool enabled) {
    _enabled = enabled;
    if (!enabled && _initialized) {
      cancelAll();
    }
  }

  Future<void> cancelAll() async {
    if (!_initialized) return;
    await _plugin.cancelAll();
    _scheduledRuleIds.clear();
  }

  Future<void> cancelRuleSchedules() async {
    final ids = _scheduledRuleIds.toList();
    for (final id in ids) {
      await _cancelRuleTriplet(id, includeEnded: true);
    }
    _scheduledRuleIds.clear();
  }

  /// Schedules "starts soon", "now active", and "rule ended" for schedule rules.
  Future<void> syncRuleSchedules(Iterable<SessionRule> rules) async {
    if (!_initialized || !_enabled) return;

    final now = DateTime.now();
    final activeRuleIds = <String>{};

    for (final rule in rules) {
      final schedule = RuleNotificationSchedule.from(rule, now);
      if (schedule == null) {
        await _cancelRuleTriplet(rule.id, includeEnded: true);
        continue;
      }

      activeRuleIds.add(schedule.ruleId);
      final warnAt = schedule.nextStart.subtract(_startsSoonOffset);

      if (warnAt.isAfter(now)) {
        await _schedule(
          id: _startsSoonId(schedule.ruleId),
          title: '${schedule.ruleName} starts soon',
          body: 'Your rule is starting in 5 mins⌛',
          when: warnAt,
        );
      } else {
        await _cancel(_startsSoonId(schedule.ruleId));
      }

      if (schedule.nextStart.isAfter(now)) {
        await _schedule(
          id: _activeId(schedule.ruleId),
          title: '${schedule.ruleName} is now active',
          body: 'Blocking for ${schedule.blockingDurationLabel}',
          when: schedule.nextStart,
        );
      } else {
        await _cancel(_activeId(schedule.ruleId));
      }

      if (schedule.nextEnd != null) {
        final nextEnd = schedule.nextEnd!;
        if (nextEnd.isAfter(now)) {
          await _schedule(
            id: _endedId(schedule.ruleId),
            title: 'Your ${schedule.ruleName} rule has ended ⌛',
            body: "What's next? 💎👀",
            when: nextEnd,
          );
        } else {
          await _cancel(_endedId(schedule.ruleId));
        }
      } else {
        await _cancel(_endedId(schedule.ruleId));
      }
    }

    final stale = _scheduledRuleIds.difference(activeRuleIds).toList();
    for (final id in stale) {
      await _cancelRuleTriplet(id, includeEnded: true);
    }
    _scheduledRuleIds
      ..clear()
      ..addAll(activeRuleIds);
  }

  /// Notification #4 — open-limit unblock consumed.
  Future<void> showOpenLimitUnblocked(int unblocksRemaining) async {
    if (!_initialized || !_enabled) return;
    await _showNow(
      id: _openLimitUnblockId(),
      title: 'App unblocked',
      body: '$unblocksRemaining more before we cut you off.',
    );
  }

  /// Notification #3 — schedule when a temporary unblock ends.
  Future<void> scheduleUnblockEnded({
    required String dedupeKey,
    required DateTime until,
  }) async {
    if (!_initialized || !_enabled) return;
    final now = DateTime.now();
    if (!until.isAfter(now)) return;

    await _schedule(
      id: _unblockEndedId(dedupeKey),
      title: 'Unblock ended ✅',
      body: "Let's get back to more important things ✨",
      when: until,
    );
  }

  Future<void> cancelUnblockEnded(String dedupeKey) async {
    await _cancel(_unblockEndedId(dedupeKey));
  }

  Future<void> _cancelRuleTriplet(
    String ruleId, {
    required bool includeEnded,
  }) async {
    await _cancel(_startsSoonId(ruleId));
    await _cancel(_activeId(ruleId));
    if (includeEnded) {
      await _cancel(_endedId(ruleId));
    }
  }

  int _startsSoonId(String ruleId) => _stableId('soon:$ruleId');
  int _activeId(String ruleId) => _stableId('active:$ruleId');
  int _endedId(String ruleId) => _stableId('ended:$ruleId');
  int _unblockEndedId(String key) => _stableId('unblock:$key');
  int _openLimitUnblockId() =>
      DateTime.now().millisecondsSinceEpoch.remainder(100000) + 200000;

  int _stableId(String key) => key.hashCode & 0x7fffffff;

  Future<void> _showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    final details = _notificationDetails();
    await _plugin.show(id, title, body, details);
  }

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    final details = _notificationDetails();
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(when, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e, stack) {
      debugPrint('Failed to schedule notification $id: $e\n$stack');
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          tz.TZDateTime.from(when, tz.local),
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (e2) {
        debugPrint('Inexact schedule also failed for $id: $e2');
      }
    }
  }

  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  Future<void> _cancel(int id) async {
    await _plugin.cancel(id);
  }
}
