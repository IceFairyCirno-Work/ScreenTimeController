import 'package:flutter_test/flutter_test.dart';
import 'package:screen_time_controller/services/streak_service.dart';

void main() {
  group('StreakService.calculateStreak', () {
    final wed = DateTime(2026, 6, 17);

    test('returns 0 when no qualified days', () {
      expect(StreakService.calculateStreak({}, wed), 0);
    });

    test('counts a single qualified today', () {
      expect(
        StreakService.calculateStreak({'2026-06-17'}, wed),
        1,
      );
    });

    test('counts consecutive days ending today', () {
      expect(
        StreakService.calculateStreak({
          '2026-06-15',
          '2026-06-16',
          '2026-06-17',
        }, wed),
        3,
      );
    });

    test('resets to 0 when yesterday was missed', () {
      expect(
        StreakService.calculateStreak({
          '2026-06-14',
          '2026-06-15',
        }, wed),
        0,
      );
    });

    test('shows yesterday streak while today is still open', () {
      expect(
        StreakService.calculateStreak({
          '2026-06-15',
          '2026-06-16',
        }, wed),
        2,
      );
    });

    test('breaks on first gap in the sequence', () {
      expect(
        StreakService.calculateStreak({
          '2026-06-14',
          '2026-06-16',
          '2026-06-17',
        }, wed),
        2,
      );
    });
  });
}
