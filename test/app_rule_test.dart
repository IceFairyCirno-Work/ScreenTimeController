import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screen_time_controller/models/app_rule.dart';
import 'package:screen_time_controller/services/streak_service.dart';

void main() {
  const pkg = 'com.instagram.android';
  final app = AppRuleItem(packageName: pkg, appName: 'Instagram');
  final created = DateTime(2026, 1, 1);

  group('formatTimeWindowDuration', () {
    test('same-day window', () {
      expect(
        formatTimeWindowDuration(
          const TimeOfDay(hour: 9, minute: 0),
          const TimeOfDay(hour: 17, minute: 30),
        ),
        '8h30m',
      );
    });

    test('overnight window wraps past midnight', () {
      expect(
        formatTimeWindowDuration(
          const TimeOfDay(hour: 23, minute: 0),
          const TimeOfDay(hour: 7, minute: 0),
        ),
        '8h0m',
      );
    });
  });

  group('nextDayStartAfter', () {
    test('skips to next weekday when weekends only', () {
      final from = DateTime(2026, 6, 26, 12); // Friday
      final next = nextDayStartAfter(
        from: from,
        createdAt: created,
        repeatDays: RepeatDay.weekend,
      );
      expect(next.weekday, DateTime.saturday);
      expect(next.hour, 0);
      expect(next.minute, 0);
    });

    test('respects createdAt earliest day', () {
      final from = DateTime(2026, 6, 23, 8);
      final next = nextDayStartAfter(
        from: from,
        createdAt: DateTime(2026, 6, 25),
        repeatDays: RepeatDay.all,
      );
      expect(next.isAfter(DateTime(2026, 6, 24, 23, 59)), isTrue);
    });
  });

  group('SessionRule schedule', () {
    SessionRule weekdayMorning() => SessionRule(
          id: 's1',
          name: 'Morning focus',
          createdAt: created,
          startTime: const TimeOfDay(hour: 9, minute: 0),
          endTime: const TimeOfDay(hour: 12, minute: 0),
          repeatDays: RepeatDay.weekdays,
          apps: [app],
        );

    test('is active inside weekday window', () {
      final rule = weekdayMorning();
      final at = DateTime(2026, 6, 23, 10, 30); // Monday
      expect(rule.isScheduleActive(at), isTrue);
      expect(rule.isPackageBlocked(pkg, at), isTrue);
    });

    test('is inactive on weekend', () {
      final rule = weekdayMorning();
      final at = DateTime(2026, 6, 27, 10, 30); // Saturday
      expect(rule.isScheduleActive(at), isFalse);
    });

    test('is inactive outside time window', () {
      final rule = weekdayMorning();
      final at = DateTime(2026, 6, 23, 14, 0);
      expect(rule.isScheduleActive(at), isFalse);
    });

    test('overnight window active after midnight on start day', () {
      final rule = SessionRule(
        id: 'night',
        name: 'Night',
        createdAt: created,
        startTime: const TimeOfDay(hour: 22, minute: 0),
        endTime: const TimeOfDay(hour: 6, minute: 0),
        repeatDays: RepeatDay.all,
        apps: [app],
      );
      expect(rule.isWithinWindow(DateTime(2026, 6, 23, 23, 30)), isTrue);
      expect(rule.isWithinWindow(DateTime(2026, 6, 23, 3, 0)), isTrue);
      expect(rule.isWithinWindow(DateTime(2026, 6, 23, 12, 0)), isFalse);
    });

    test('temporary unblock lifts package block', () {
      final until = DateTime(2026, 6, 23, 11, 0);
      final started = DateTime(2026, 6, 23, 10, 0);
      final rule = weekdayMorning().copyWith(
        unblockedUntilByPackage: {pkg: until},
        unblockedStartedAtByPackage: {pkg: started},
      );
      final at = DateTime(2026, 6, 23, 10, 30);
      expect(rule.isPackageBlocked(pkg, at), isFalse);
      expect(rule.isCurrentlyUnblocked(at), isTrue);
    });

    test('indefinite disable suppresses schedule', () {
      final rule = weekdayMorning().copyWith(
        disabledUntil: SessionRule.indefiniteDisableUntil,
      );
      final at = DateTime(2026, 6, 23, 10, 30);
      expect(rule.isIndefinitelyDisabled(), isTrue);
      expect(rule.isScheduleActive(at), isFalse);
      expect(rule.disabledOverlayLabel(at), 'Disabled');
    });

    test('nextStartAfter finds upcoming slot', () {
      final rule = weekdayMorning();
      final from = DateTime(2026, 6, 23, 13, 0); // Monday afternoon
      final next = rule.nextStartAfter(from);
      expect(next, DateTime(2026, 6, 24, 9, 0)); // Tuesday 9:00
    });

    test('withPrunedUnblocks removes expired entries', () {
      final rule = weekdayMorning().copyWith(
        unblockedUntilByPackage: {
          pkg: DateTime(2026, 6, 23, 10, 15),
        },
        unblockedStartedAtByPackage: {
          pkg: DateTime(2026, 6, 23, 10, 0),
        },
      );
      final pruned = rule.withPrunedUnblocks(DateTime(2026, 6, 23, 10, 30));
      expect(pruned.unblockedUntilByPackage, isEmpty);
    });

    test('json round-trip preserves session fields', () {
      final original = weekdayMorning().copyWith(
        disabledUntil: DateTime(2026, 6, 30),
        unblockedUntilByPackage: {
          pkg: DateTime(2026, 6, 23, 12, 0),
        },
      );
      final restored = SessionRule.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.startTime, original.startTime);
      expect(restored.repeatDays, original.repeatDays);
      expect(restored.disabledUntil, original.disabledUntil);
      expect(
        restored.unblockedUntilByPackage[pkg],
        original.unblockedUntilByPackage[pkg],
      );
    });
  });

  group('TimeLimitRule', () {
    TimeLimitRule rule() => TimeLimitRule(
          id: 'tl1',
          name: '30m limit',
          createdAt: created,
          allowedTime: const Duration(minutes: 30),
          blockUntil: const Duration(hours: 2),
          repeatDays: RepeatDay.weekdays,
          apps: [app],
        );

    test('blocks when tracked usage exceeds allowance', () {
      final r = rule();
      final at = DateTime(2026, 6, 23, 15, 0);
      expect(
        r.isPackageBlocked(pkg, const Duration(minutes: 45), at),
        isTrue,
      );
      expect(
        r.isPackageBlocked(pkg, const Duration(minutes: 20), at),
        isFalse,
      );
    });

    test('effectiveUsageForPackage subtracts baseline', () {
      final r = rule().copyWith(
        usageBaselineMsByPackage: {pkg: 10 * 60 * 1000},
      );
      expect(
        r.effectiveUsageForPackage(pkg, const Duration(minutes: 25)),
        const Duration(minutes: 15),
      );
    });

    test('resolveBlockExpiry uses blockUntil duration', () {
      final r = rule();
      final exceeded = DateTime(2026, 6, 23, 10, 0);
      expect(
        r.resolveBlockExpiry(exceeded),
        exceeded.add(const Duration(hours: 2)),
      );
    });

    test('resolveBlockExpiry tomorrow when blockUntil >= 24h', () {
      final r = rule().copyWith(blockUntil: const Duration(hours: 24));
      final exceeded = DateTime(2026, 6, 23, 10, 0);
      expect(
        r.resolveBlockExpiry(exceeded),
        DateTime(2026, 6, 24),
      );
    });

    test('withQuotaRollover clears exceeded map on new day', () {
      final r = rule().copyWith(
        usageQuotaDay: '2026-6-22',
        limitExceededAtByPackage: {pkg: DateTime(2026, 6, 22, 12)},
      );
      final rolled = r.withQuotaRollover(DateTime(2026, 6, 23, 8));
      expect(rolled.usageQuotaDay, '2026-6-23');
      expect(rolled.limitExceededAtByPackage, isEmpty);
    });

    test('repeatLabel shortcuts', () {
      expect(rule().repeatLabel, 'Weekdays');
      expect(
        rule().copyWith(repeatDays: RepeatDay.all).repeatLabel,
        'Everyday',
      );
      expect(
        rule().copyWith(repeatDays: RepeatDay.weekend).repeatLabel,
        'Weekends',
      );
    });

    test('json round-trip', () {
      final original = rule().copyWith(
        limitExceededAtByPackage: {pkg: DateTime(2026, 6, 23, 9)},
        usageBaselineMsByPackage: {pkg: 600000},
      );
      final restored = TimeLimitRule.fromJson(original.toJson());
      expect(restored.allowedTime, original.allowedTime);
      expect(restored.blockUntil, original.blockUntil);
      expect(restored.usageBaselineMsByPackage[pkg], 600000);
    });
  });

  group('OpenLimitRule', () {
    OpenLimitRule rule() => OpenLimitRule(
          id: 'ol1',
          name: '4 opens limit',
          createdAt: created,
          maxOpens: 4,
          sessionLengthMinutes: 5,
          apps: [app],
        );

    test('blocks all listed apps while active', () {
      final at = DateTime(2026, 6, 23, 12, 0);
      expect(rule().isPackageBlocked(pkg, at), isTrue);
    });

    test('unblocks remaining quota', () {
      expect(rule().unblocksRemaining, 4);
      expect(
        rule().copyWith(unblocksUsed: 2).unblocksRemaining,
        2,
      );
      expect(rule().copyWith(unblocksUsed: 10).unblocksRemaining, 0);
    });

    test('withQuotaRollover resets daily opens', () {
      final rolled = rule()
          .copyWith(unblocksUsed: 3, unblocksQuotaDay: '2026-6-22')
          .withQuotaRollover(DateTime(2026, 6, 23, 1));
      expect(rolled.unblocksUsed, 0);
      expect(rolled.unblocksQuotaDay, '2026-6-23');
    });

    test('json round-trip', () {
      final original = rule().copyWith(unblocksUsed: 1, unblocksQuotaDay: '2026-6-23');
      final restored = OpenLimitRule.fromJson(original.toJson());
      expect(restored.maxOpens, 4);
      expect(restored.unblocksUsed, 1);
    });
  });

  group('BlockedAppDisplay', () {
    test('progressAt returns remaining fraction during unblock', () {
      final started = DateTime(2026, 6, 23, 10, 0);
      final until = DateTime(2026, 6, 23, 10, 30);
      final display = BlockedAppDisplay(
        app: app,
        isBlocked: false,
        unblockedStartedAt: started,
        unblockedUntil: until,
      );
      expect(display.progressAt(DateTime(2026, 6, 23, 10, 15)), closeTo(0.5, 0.01));
      expect(display.statusLabelAt(DateTime(2026, 6, 23, 10, 20)), '10m left');
    });

    test('hard blocked label', () {
      final display = BlockedAppDisplay(
        app: app,
        isBlocked: true,
        isHardBlocked: true,
      );
      expect(display.statusLabelAt(DateTime(2026, 6, 23, 10, 0)), 'Hard blocked');
    });
  });

  group('StreakService.isRuleActivating', () {
    test('session rule counts when schedule active', () {
      final rule = SessionRule(
        id: 's',
        name: 'All day',
        createdAt: created,
        startTime: const TimeOfDay(hour: 0, minute: 0),
        endTime: const TimeOfDay(hour: 23, minute: 59),
        repeatDays: RepeatDay.all,
        apps: [app],
      );
      final at = DateTime(2026, 6, 23, 12, 0);
      expect(StreakService.isRuleActivating(rule, at), isTrue);
      expect(StreakService.hasAnyActivatingRule([rule], at), isTrue);
    });

    test('disabled session rule does not activate streak', () {
      final rule = SessionRule(
        id: 's',
        name: 'Off',
        createdAt: created,
        startTime: const TimeOfDay(hour: 0, minute: 0),
        endTime: const TimeOfDay(hour: 23, minute: 59),
        repeatDays: RepeatDay.all,
        disabledUntil: SessionRule.indefiniteDisableUntil,
        apps: [app],
      );
      expect(
        StreakService.hasAnyActivatingRule([rule], DateTime(2026, 6, 23)),
        isFalse,
      );
    });
  });
}
