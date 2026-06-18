import 'package:flutter_test/flutter_test.dart';
import 'package:screen_time_controller/models/screen_time_data.dart';
import 'package:screen_time_controller/services/screen_timer_controller_score_calculator.dart';

void main() {
  final calculator = ScreenTimerControllerScoreCalculator();

  ScreenTimeData data({
    int todayMinutes = 0,
    int nightMinutes = 0,
    List<AppUsageItem> topApps = const [],
    bool hasPermission = true,
  }) {
    return ScreenTimeData(
      todayTotal: Duration(minutes: todayMinutes),
      weekTotal: Duration.zero,
      topApps: topApps,
      hasPermission: hasPermission,
      nightUsageMinutes: nightMinutes,
    );
  }

  AppUsageItem app(String package, String name, int minutes) => AppUsageItem(
        appName: name,
        packageName: package,
        usage: Duration(minutes: minutes),
      );

  group('ScreenTimerControllerScoreCalculator', () {
    test('no permission returns zero metrics', () {
      final metrics = calculator.calculate(
        data: data(hasPermission: false),
      );
      expect(metrics.score, 0);
      expect(metrics.sleep, 0);
      expect(metrics.focus, 0);
      expect(metrics.rest, 0);
    });

    test('zero usage with permission returns perfect score', () {
      final metrics = calculator.calculate(
        data: data(todayMinutes: 0, hasPermission: true),
      );
      expect(metrics.score, 100);
      expect(metrics.sleepScore, 100);
      expect(metrics.focus, 100);
      expect(metrics.rest, 100);
    });

    test('score equals rounded average of sleepScore, focus, and rest', () {
      final cases = <({
        int night,
        int today,
        List<AppUsageItem> apps,
        Set<String> distracting,
      })>[
        (
          night: 25,
          today: 180,
          apps: [
            app('com.instagram.android', 'Instagram', 72),
            app('com.example.work', 'Work', 50),
            app('com.example.notes', 'Notes', 28),
            app('com.example.other', 'Other', 30),
          ],
          distracting: const {},
        ),
        (
          night: 0,
          today: 120,
          apps: [
            app('com.example.a', 'App A', 80),
            app('com.example.b', 'App B', 30),
            app('com.example.c', 'App C', 10),
          ],
          distracting: const {},
        ),
        (
          night: 60,
          today: 60,
          apps: [
            app('com.example.only', 'Only', 60),
          ],
          distracting: const {},
        ),
      ];

      for (final c in cases) {
        final metrics = calculator.calculate(
          data: data(
            todayMinutes: c.today,
            nightMinutes: c.night,
            topApps: c.apps,
          ),
          distractingFolderPackages: c.distracting,
        );
        final expected =
            ((metrics.sleepScore + metrics.focus + metrics.rest) / 3)
                .round()
                .clamp(0, 100);
        expect(metrics.score, expected, reason: 'night=${c.night} today=${c.today}');
      }
    });

    test('plan example: night=25, distracting=72/180, top3=150/180 → score≈59', () {
      final metrics = calculator.calculate(
        data: data(
          todayMinutes: 180,
          nightMinutes: 25,
          topApps: [
            app('com.instagram.android', 'Instagram', 72),
            app('com.example.work', 'Work', 50),
            app('com.example.notes', 'Notes', 28),
            app('com.example.other', 'Other', 30),
          ],
        ),
      );

      expect(metrics.sleep, 25);
      expect(metrics.sleepScore, 79);
      expect(metrics.focus, 60);
      expect(metrics.rest, 37);
      expect(metrics.score, 59);
    });

    test('no distracting usage yields focus=100', () {
      final metrics = calculator.calculate(
        data: data(
          todayMinutes: 120,
          topApps: [
            app('com.example.work', 'Work', 80),
            app('com.example.notes', 'Notes', 40),
          ],
        ),
      );

      expect(metrics.focus, 100);
    });

    test('removed top-app fallback does not punish when no distracting found', () {
      final metrics = calculator.calculate(
        data: data(
          todayMinutes: 100,
          topApps: [
            app('com.example.work', 'Work', 100),
          ],
        ),
      );

      expect(metrics.focus, 100);
    });

    test('distracting folder packages count toward focus', () {
      final metrics = calculator.calculate(
        data: data(
          todayMinutes: 100,
          topApps: [
            app('com.custom.game', 'My Game', 40),
            app('com.example.work', 'Work', 60),
          ],
        ),
        distractingFolderPackages: {'com.custom.game'},
      );

      expect(metrics.focus, 60);
    });

    test('always-allowed packages are excluded from distracting', () {
      final metrics = calculator.calculate(
        data: data(
          todayMinutes: 100,
          topApps: [
            app('com.instagram.android', 'Instagram', 50),
            app('com.example.work', 'Work', 50),
          ],
        ),
        alwaysAllowedPackages: {'com.instagram.android'},
      );

      expect(metrics.focus, 100);
    });

    group('rest top-3 concentration', () {
      final top3Cases = <(double share, int expectedRest)>[
        (0.33, 75),
        (0.67, 50),
        (1.0, 25),
      ];

      for (final (share, expectedRest) in top3Cases) {
        test('top3 share ${(share * 100).round()}% → rest $expectedRest', () {
          final today = 180;
          final top3 = (today * share).round();
          final metrics = calculator.calculate(
            data: data(
              todayMinutes: today,
              topApps: [
                app('com.example.a', 'A', top3),
              ],
            ),
          );

          expect(metrics.rest, expectedRest);
        });
      }

      test('uses sum of top 3 apps only', () {
        final metrics = calculator.calculate(
          data: data(
            todayMinutes: 200,
            topApps: [
              app('com.example.a', 'A', 70),
              app('com.example.b', 'B', 50),
              app('com.example.c', 'C', 30),
            ],
          ),
        );

        // top3 = 150, concentration = 0.75, rest = round(100 * (1 - 0.75 * 0.75)) = 44
        expect(metrics.rest, 44);
      });
    });

    group('sleepScore', () {
      final sleepCases = <(int minutes, int expectedScore)>[
        (0, 100),
        (30, 75),
        (60, 50),
        (90, 25),
        (120, 0),
      ];

      for (final (minutes, expectedScore) in sleepCases) {
        test('$minutes night minutes → sleepScore $expectedScore', () {
          final metrics = calculator.calculate(
            data: data(
              todayMinutes: 60,
              nightMinutes: minutes,
              topApps: [app('com.example.work', 'Work', 60)],
            ),
          );

          expect(metrics.sleep, minutes);
          expect(metrics.sleepScore, expectedScore);
        });
      }
    });
  });
}
