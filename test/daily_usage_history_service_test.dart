import 'package:flutter_test/flutter_test.dart';
import 'package:screen_time_controller/services/daily_usage_history_service.dart';
import 'package:screen_time_controller/services/screen_time_service.dart';

class _FakeScreenTimeService extends ScreenTimeService {
  _FakeScreenTimeService(this._byDay);

  final Map<String, int?> _byDay;

  @override
  Future<int?> fetchDayTotalMs(DateTime day) async {
    final key = DailyUsageHistoryService.dateKey(day);
    return _byDay[key];
  }
}

void main() {
  group('DailyUsageHistoryService', () {
    test('uses today live total from home screen', () async {
      final now = DateTime(2026, 6, 17, 15);
      const todayMs = 6 * 3600000 + 22 * 60000;

      final service = DailyUsageHistoryService(
        screenTimeService: _FakeScreenTimeService({}),
      );

      final history = await service.loadLast7Days(
        fallbackHoursPerDay: 5,
        now: now,
        todayTotalMs: todayMs,
      );

      expect(history.dailyHours.last, closeTo(6 + 22 / 60, 0.01));
    });

    test('rejects insane phone totals', () async {
      final now = DateTime(2026, 6, 17, 15);

      final service = DailyUsageHistoryService(
        screenTimeService: _FakeScreenTimeService({
          '2026-06-16': 40 * 3600000,
        }),
      );

      final history = await service.loadLast7Days(
        fallbackHoursPerDay: 6,
        now: now,
        todayTotalMs: 2 * 3600000,
      );

      expect(history.dailyHours[5], 6);
      expect(history.dailyHours.last, 2);
      expect(history.averageHours, 2);
      expect(history.measuredDayCount, 1);
    });

    test('average uses only phone-measured days', () async {
      final now = DateTime(2026, 6, 17, 15);
      final service = DailyUsageHistoryService(
        screenTimeService: _FakeScreenTimeService({
          '2026-06-11': 4 * 3600000,
          '2026-06-12': 8 * 3600000,
        }),
      );

      final history = await service.loadLast7Days(
        fallbackHoursPerDay: 10,
        now: now,
        todayTotalMs: 6 * 3600000,
      );

      expect(history.measuredDayCount, 3);
      expect(history.averageHours, closeTo(6, 0.01));
    });

    test('accepts zero usage for today from live total', () async {
      final now = DateTime(2026, 6, 17, 10);

      final service = DailyUsageHistoryService(
        screenTimeService: _FakeScreenTimeService({}),
      );

      final history = await service.loadLast7Days(
        fallbackHoursPerDay: 6,
        now: now,
        todayTotalMs: 0,
      );

      expect(history.dailyHours.last, 0);
      expect(history.measuredDayCount, 1);
    });
  });
}
