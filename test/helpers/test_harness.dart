import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [child] inside a [MaterialApp] with a fixed logical viewport.
Future<void> pumpWithSize(
  WidgetTester tester,
  Widget child, {
  required Size size,
  double textScaleFactor = 1.0,
  EdgeInsets padding = EdgeInsets.zero,
}) {
  return tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: size,
        padding: padding,
        textScaler: TextScaler.linear(textScaleFactor),
      ),
      child: MaterialApp(
        home: Scaffold(body: child),
      ),
    ),
  );
}

/// Common phone / tablet sizes used across layout tests.
class TestViewports {
  static const compactPhone = Size(320, 640);
  static const phone = Size(390, 844);
  static const tablet = Size(768, 1024);
  static const largeTablet = Size(1024, 1366);
}
