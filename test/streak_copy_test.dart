import 'package:flutter_test/flutter_test.dart';
import 'package:screen_time_controller/services/streak_copy.dart';

void main() {
  group('StreakCopy.forStreak', () {
    test('returns zero copy when streak is 0', () {
      final copy = StreakCopy.forStreak(0);
      expect(copy.title, StreakCopy.zero.title);
      expect(copy.body, StreakCopy.zero.body);
    });

    test('capstone overrides daily rotation on milestone days', () {
      expect(StreakCopy.forStreak(7).title, 'One week in');
      expect(StreakCopy.forStreak(365).title, 'One year of focus');
    });

    test('uses daily pool on non-capstone days', () {
      expect(StreakCopy.forStreak(2).title, 'Building momentum');
      expect(StreakCopy.forStreak(8).title, 'Still on track');
    });

    test('day 1 uses capstone not daily slot', () {
      expect(StreakCopy.forStreak(1).title, 'First step taken');
      expect(StreakCopy.forStreak(1).title, isNot('Keep it going'));
    });
  });
}
