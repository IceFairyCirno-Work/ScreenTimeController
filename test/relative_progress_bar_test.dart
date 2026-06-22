import 'package:flutter_test/flutter_test.dart';
import 'package:screen_time_controller/theme/app_theme.dart';
import 'package:screen_time_controller/widgets/shared/relative_progress_bar.dart';

void main() {
  group('RelativeProgressBar.visualDeltaRatio', () {
    test('preserves sign', () {
      expect(
        RelativeProgressBar.visualDeltaRatio(0.4),
        greaterThan(0),
      );
      expect(
        RelativeProgressBar.visualDeltaRatio(-0.4),
        lessThan(0),
      );
    });

    test('keeps different magnitudes distinguishable', () {
      final small = RelativeProgressBar.visualDeltaRatio(0.2).abs();
      final medium = RelativeProgressBar.visualDeltaRatio(0.6).abs();
      final large = RelativeProgressBar.visualDeltaRatio(1.4).abs();
      final huge = RelativeProgressBar.visualDeltaRatio(2.8).abs();

      expect(small, lessThan(medium));
      expect(medium, lessThan(large));
      expect(large, lessThan(huge));
      expect(huge, lessThan(1.0));
    });

    test('does not hard-clamp 100%+ changes to the same length', () {
      final at100 = RelativeProgressBar.visualDeltaRatio(1.0).abs();
      final at200 = RelativeProgressBar.visualDeltaRatio(2.0).abs();

      expect(at100, isNot(equals(at200)));
    });
  });

  group('RelativeProgressBar.effectiveAverage', () {
    test('uses floor when history average is zero but today has usage', () {
      expect(
        RelativeProgressBar.effectiveAverage(
          averageValue: 0,
          currentValue: 2,
          minimumAverageWhenEmpty: 1,
        ),
        1,
      );
    });

    test('keeps real average when available', () {
      expect(
        RelativeProgressBar.effectiveAverage(
          averageValue: 15,
          currentValue: 2,
          minimumAverageWhenEmpty: 1,
        ),
        15,
      );
    });
  });

  group('RelativeProgressBar.changeColorForMagnitude', () {
    test('uses mint for large changes and orange for small', () {
      expect(
        RelativeProgressBar.changeColorForMagnitude(
          visualMagnitude: 0.5,
          threshold: 0.4,
          largeChangeColor: AppTheme.screenTimerControllerMint,
          smallChangeColor: AppTheme.screenTimerControllerFlame,
        ),
        AppTheme.screenTimerControllerMint,
      );
      expect(
        RelativeProgressBar.changeColorForMagnitude(
          visualMagnitude: 0.2,
          threshold: 0.4,
          largeChangeColor: AppTheme.screenTimerControllerMint,
          smallChangeColor: AppTheme.screenTimerControllerFlame,
        ),
        AppTheme.screenTimerControllerFlame,
      );
    });
  });
}
