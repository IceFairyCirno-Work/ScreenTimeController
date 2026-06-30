import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screen_time_controller/models/app_rule.dart';
import 'package:screen_time_controller/utils/cjk_time_formatter.dart';
import 'package:screen_time_controller/utils/duration_formatters.dart';
import 'package:screen_time_controller/utils/open_limit_formatter.dart';
import 'package:screen_time_controller/utils/rule_notification_schedule.dart';

void main() {
  group('formatDurationSingleUnit', () {
    test('prefers days then hours then minutes', () {
      expect(formatDurationSingleUnit(const Duration(days: 2)), '2d');
      expect(formatDurationSingleUnit(const Duration(hours: 3)), '3h');
      expect(formatDurationSingleUnit(const Duration(minutes: 45)), '45m');
      expect(formatDurationSingleUnit(const Duration(minutes: 0)), '1m');
    });
  });

  group('CjkTimeFormatter', () {
    test('formats AM and PM times', () {
      expect(
        CjkTimeFormatter.format(const TimeOfDay(hour: 9, minute: 5)),
        '上午9:05',
      );
      expect(
        CjkTimeFormatter.format(const TimeOfDay(hour: 17, minute: 0)),
        '下午5:00',
      );
      expect(
        CjkTimeFormatter.format(const TimeOfDay(hour: 0, minute: 30)),
        '上午12:30',
      );
    });

    test('formatRange joins with en-dash', () {
      expect(
        CjkTimeFormatter.formatRange(
          const TimeOfDay(hour: 9, minute: 0),
          const TimeOfDay(hour: 17, minute: 0),
        ),
        '上午9:00 – 下午5:00',
      );
    });

    test('isDefaultRangeName detects auto titles', () {
      const start = TimeOfDay(hour: 9, minute: 0);
      const end = TimeOfDay(hour: 17, minute: 0);
      expect(
        CjkTimeFormatter.isDefaultRangeName(
          CjkTimeFormatter.formatRange(start, end),
          start,
          end,
        ),
        isTrue,
      );
      expect(
        CjkTimeFormatter.isDefaultRangeName('Custom name', start, end),
        isFalse,
      );
    });
  });

  group('OpenLimitFormatter', () {
    test('title and session length', () {
      expect(OpenLimitFormatter.formatTitle(4), '4 opens limit');
      expect(OpenLimitFormatter.formatSessionLength(5), '5m');
    });

    test('isDefaultOpenLimitName', () {
      expect(OpenLimitFormatter.isDefaultOpenLimitName('4 opens limit', 4), isTrue);
      expect(OpenLimitFormatter.isDefaultOpenLimitName('My rule', 4), isFalse);
    });
  });

  group('RuleNotificationSchedule', () {
    final created = DateTime(2026, 1, 1);
    final app = const AppRuleItem(
      packageName: 'com.example',
      appName: 'Example',
    );

    SessionRule morningRule() => SessionRule(
          id: 'notify-1',
          name: 'Work hours',
          createdAt: created,
          startTime: const TimeOfDay(hour: 9, minute: 0),
          endTime: const TimeOfDay(hour: 17, minute: 0),
          repeatDays: RepeatDay.weekdays,
          apps: [app],
        );

    test('isEligible rejects disabled rules', () {
      final disabled = morningRule().copyWith(
        disabledUntil: SessionRule.indefiniteDisableUntil,
      );
      expect(
        RuleNotificationSchedule.isEligible(
          disabled,
          DateTime(2026, 6, 23, 8),
        ),
        isFalse,
      );
    });

    test('from returns schedule with next start and end', () {
      final from = DateTime(2026, 6, 23, 8, 30); // Monday before window
      final schedule = RuleNotificationSchedule.from(morningRule(), from);
      expect(schedule, isNotNull);
      expect(schedule!.ruleId, 'notify-1');
      expect(schedule.ruleName, 'Work hours');
      expect(schedule.nextStart, DateTime(2026, 6, 23, 9, 0));
      expect(schedule.blockingDurationLabel, '8h0m');
      expect(schedule.nextEnd, DateTime(2026, 6, 23, 17, 0));
    });

    test('from returns null when rule not eligible', () {
      final off = morningRule().copyWith(isEnabled: false);
      expect(
        RuleNotificationSchedule.from(off, DateTime(2026, 6, 23, 10)),
        isNull,
      );
    });
  });
}
