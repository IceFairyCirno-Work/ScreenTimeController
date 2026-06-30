import 'package:flutter_test/flutter_test.dart';
import 'package:screen_time_controller/models/screen_time_data.dart';
import 'package:screen_time_controller/services/screen_timer_controller_score_calculator.dart';

void main() {
  final calculator = ScreenTimerControllerScoreCalculator();

  group('calculateEstimated (iOS fallback)', () {
    test('moderate daily hours produce mid-range score', () {
      final metrics = calculator.calculateEstimated(dailyHoursEstimate: 8);
      expect(metrics.score, greaterThan(0));
      expect(metrics.score, lessThan(100));
      expect(metrics.focus, lessThan(100));
    });

    test('low daily hours yield higher focus and rest', () {
      final low = calculator.calculateEstimated(dailyHoursEstimate: 2);
      final high = calculator.calculateEstimated(dailyHoursEstimate: 12);
      expect(low.focus, greaterThan(high.focus));
      expect(low.rest, greaterThan(high.rest));
    });

    test('no permission with estimate uses calculateEstimated path', () {
      final metrics = calculator.calculate(
        data: const ScreenTimeData(
          todayTotal: Duration.zero,
          weekTotal: Duration.zero,
          topApps: [],
          hasPermission: false,
        ),
        dailyHoursEstimate: 6,
      );
      expect(metrics.score, greaterThan(0));
    });
  });

  group('mergeBaselines', () {
    test('prefers non-zero primary values', () {
      const primary = ScoreBreakdownBaselines(
        avgScreenMinutes: 120,
        avgSleepMinutes: 0,
        avgDistractionMinutes: 30,
        avgTop3Minutes: 0,
      );
      const rolling = ScoreBreakdownBaselines(
        avgScreenMinutes: 90,
        avgSleepMinutes: 15,
        avgDistractionMinutes: 20,
        avgTop3Minutes: 45,
      );
      final merged = calculator.mergeBaselines(primary: primary, rolling: rolling);
      expect(merged.avgScreenMinutes, 120);
      expect(merged.avgSleepMinutes, 15);
      expect(merged.avgDistractionMinutes, 30);
      expect(merged.avgTop3Minutes, 45);
    });
  });

  group('usageBreakdown', () {
    test('returns zero when no permission', () {
      final breakdown = calculator.usageBreakdown(
        data: const ScreenTimeData(
          todayTotal: Duration(minutes: 60),
          weekTotal: Duration.zero,
          topApps: [],
          hasPermission: false,
        ),
      );
      expect(breakdown.distractionMinutes, 0);
      expect(breakdown.top3Minutes, 0);
    });
  });
}
