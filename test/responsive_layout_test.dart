import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screen_time_controller/utils/responsive.dart';

import 'helpers/test_harness.dart';

void main() {
  group('Responsive breakpoints', () {
    testWidgets('compact phone uses 20px horizontal padding', (tester) async {
      await pumpWithSize(
        tester,
        Builder(
          builder: (context) {
            expect(Responsive.isCompactPhone(context), isTrue);
            expect(Responsive.isTablet(context), isFalse);
            expect(Responsive.horizontalPadding(context), 20);
            return const SizedBox();
          },
        ),
        size: TestViewports.compactPhone,
      );
    });

    testWidgets('standard phone uses 24px horizontal padding', (tester) async {
      await pumpWithSize(
        tester,
        Builder(
          builder: (context) {
            expect(Responsive.isCompactPhone(context), isFalse);
            expect(Responsive.isTablet(context), isFalse);
            expect(Responsive.horizontalPadding(context), 24);
            return const SizedBox();
          },
        ),
        size: TestViewports.phone,
      );
    });

    testWidgets('tablet uses 40px padding and caps content width', (tester) async {
      await pumpWithSize(
        tester,
        Builder(
          builder: (context) {
            expect(Responsive.isTablet(context), isTrue);
            expect(Responsive.horizontalPadding(context), 40);
            expect(
              Responsive.contentMaxWidth(context),
              Responsive.contentMaxWidthTablet,
            );
            return const SizedBox();
          },
        ),
        size: TestViewports.tablet,
      );
    });
  });

  group('Responsive grid columns', () {
    testWidgets('phone rules grid stays at 2 columns', (tester) async {
      await pumpWithSize(
        tester,
        Builder(
          builder: (context) {
            expect(Responsive.gridCrossAxisCount(context), 2);
            expect(Responsive.folderGridCrossAxisCount(context), 2);
            return const SizedBox();
          },
        ),
        size: TestViewports.phone,
      );
    });

    testWidgets('tablet rules grid uses 3 or 4 columns', (tester) async {
      await pumpWithSize(
        tester,
        Builder(
          builder: (context) {
            expect(Responsive.gridCrossAxisCount(context), 3);
            expect(Responsive.folderGridCrossAxisCount(context), 3);
            return const SizedBox();
          },
        ),
        size: TestViewports.tablet,
      );

      await pumpWithSize(
        tester,
        Builder(
          builder: (context) {
            expect(Responsive.gridCrossAxisCount(context), 4);
            return const SizedBox();
          },
        ),
        size: TestViewports.largeTablet,
      );
    });
  });

  group('Responsive component sizing', () {
    testWidgets('timer clock scales with viewport', (tester) async {
      double? phoneClock;
      double? tabletClock;

      await pumpWithSize(
        tester,
        Builder(
          builder: (context) {
            phoneClock = Responsive.timerClockWidth(context);
            return const SizedBox();
          },
        ),
        size: TestViewports.phone,
      );

      await pumpWithSize(
        tester,
        Builder(
          builder: (context) {
            tabletClock = Responsive.timerClockWidth(context);
            return const SizedBox();
          },
        ),
        size: TestViewports.tablet,
      );

      expect(phoneClock, lessThanOrEqualTo(260));
      expect(tabletClock, lessThanOrEqualTo(360));
      expect(tabletClock!, greaterThan(phoneClock!));
    });

    testWidgets('rules card dimensions grow on tablet', (tester) async {
      double? phoneW;
      double? tabletW;

      await pumpWithSize(
        tester,
        Builder(
          builder: (context) {
            phoneW = Responsive.rulesCardWidth(context);
            return const SizedBox();
          },
        ),
        size: TestViewports.phone,
      );

      await pumpWithSize(
        tester,
        Builder(
          builder: (context) {
            tabletW = Responsive.rulesCardWidth(context);
            return const SizedBox();
          },
        ),
        size: TestViewports.tablet,
      );

      expect(phoneW, 180);
      expect(tabletW, 220);
    });

    testWidgets('scroll bottom padding clears floating nav', (tester) async {
      await pumpWithSize(
        tester,
        Builder(
          builder: (context) {
            final padding = Responsive.scrollBottomPadding(context);
            expect(padding, greaterThan(74));
            return const SizedBox();
          },
        ),
        size: TestViewports.phone,
        padding: const EdgeInsets.only(bottom: 34),
      );
    });
  });

  group('Responsive text scaling', () {
    testWidgets('clamps text scale above 1.3x', (tester) async {
      await pumpWithSize(
        tester,
        Builder(
          builder: (context) {
            final scaler = Responsive.clampedTextScaler(context);
            expect(scaler.scale(16), closeTo(16 * 1.3, 0.01));
            return const SizedBox();
          },
        ),
        size: TestViewports.phone,
        textScaleFactor: 2.0,
      );
    });

    testWidgets('preserves text scale at or below 1.3x', (tester) async {
      await pumpWithSize(
        tester,
        Builder(
          builder: (context) {
            final scaler = Responsive.clampedTextScaler(context);
            expect(scaler.scale(16), closeTo(19.2, 0.01));
            return const SizedBox();
          },
        ),
        size: TestViewports.phone,
        textScaleFactor: 1.2,
      );
    });
  });

  group('Responsive layout wrappers', () {
    testWidgets('centeredContent leaves phone child unchanged', (tester) async {
      await pumpWithSize(
        tester,
        Builder(
          builder: (context) {
            return Responsive.centeredContent(
              context: context,
              child: const Text('hello'),
            );
          },
        ),
        size: TestViewports.phone,
      );

      expect(find.text('hello'), findsOneWidget);
      expect(find.byType(Center), findsNothing);
    });

    testWidgets('centeredContent wraps tablet child in max width', (tester) async {
      await pumpWithSize(
        tester,
        Builder(
          builder: (context) {
            return Responsive.centeredContent(
              context: context,
              child: const Text('tablet'),
            );
          },
        ),
        size: TestViewports.tablet,
      );

      expect(find.byType(Center), findsOneWidget);
      final constrained = tester.widgetList<ConstrainedBox>(
        find.descendant(
          of: find.byType(Center),
          matching: find.byType(ConstrainedBox),
        ),
      );
      expect(constrained.length, 1);
      expect(
        constrained.first.constraints.maxWidth,
        Responsive.contentMaxWidthTablet,
      );
    });

    testWidgets('ResponsiveCenteredTab centers on tablet', (tester) async {
      await pumpWithSize(
        tester,
        const ResponsiveCenteredTab(child: Text('tab')),
        size: TestViewports.tablet,
      );
      expect(find.byType(Center), findsOneWidget);
      expect(find.text('tab'), findsOneWidget);
    });

    testWidgets('constrainedSheet caps bottom sheet on tablet', (tester) async {
      await pumpWithSize(
        tester,
        Builder(
          builder: (context) {
            return Responsive.constrainedSheet(
              context: context,
              child: const SizedBox(height: 200, child: Text('sheet')),
            );
          },
        ),
        size: TestViewports.tablet,
      );

      final box = tester.widget<ConstrainedBox>(
        find.descendant(
          of: find.byType(Align),
          matching: find.byType(ConstrainedBox),
        ),
      );
      expect(box.constraints.maxWidth, Responsive.sheetMaxWidthTablet);
    });
  });
}
