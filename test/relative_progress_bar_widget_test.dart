import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screen_time_controller/widgets/shared/relative_progress_bar.dart';

import 'helpers/test_harness.dart';

void main() {
  group('RelativeProgressBar widget', () {
    Widget buildBar({
      double current = 120,
      double average = 100,
      bool isLowerBetter = true,
    }) {
      return RelativeProgressBar(
        title: 'Screen time',
        todayLabel: '2h',
        currentValue: current,
        averageValue: average,
        isLowerBetter: isLowerBetter,
      );
    }

    testWidgets('renders title and today label', (tester) async {
      await pumpWithSize(
        tester,
        buildBar(),
        size: TestViewports.phone,
      );
      expect(find.text('Screen time'), findsOneWidget);
      expect(find.text('2h'), findsOneWidget);
      expect(find.text('AVG'), findsOneWidget);
    });

    testWidgets('shows increase fill to the right when higher is worse', (tester) async {
      await pumpWithSize(
        tester,
        buildBar(current: 150, average: 100, isLowerBetter: true),
        size: TestViewports.phone,
      );
      await tester.pumpAndSettle();
      expect(find.byType(RelativeProgressBar), findsOneWidget);
    });

    testWidgets('formatMinutes and formatTime24 helpers', (tester) async {
      expect(RelativeProgressBar.formatMinutes(45), '45m');
      expect(RelativeProgressBar.formatMinutes(90), '1h 30m');
      expect(RelativeProgressBar.formatMinutes(120), '2h');
      expect(
        RelativeProgressBar.formatTime24(DateTime(2026, 6, 23, 8, 5)),
        '08:05',
      );
      expect(
        RelativeProgressBar.minutesSinceMidnight(DateTime(2026, 6, 23, 1, 30)),
        90,
      );
    });
  });
}
