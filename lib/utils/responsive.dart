import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared responsive layout helpers for phone and tablet targets.
class Responsive {
  Responsive._();

  static const tabletBreakpoint = 600.0;
  static const compactPhoneBreakpoint = 360.0;
  static const contentMaxWidthTablet = 600.0;
  static const sheetMaxWidthTablet = 560.0;
  static const maxTextScaleFactor = 1.3;

  static Size sizeOf(BuildContext context) => MediaQuery.sizeOf(context);

  static EdgeInsets paddingOf(BuildContext context) =>
      MediaQuery.paddingOf(context);

  static bool isTablet(BuildContext context) =>
      sizeOf(context).shortestSide >= tabletBreakpoint;

  static bool isCompactPhone(BuildContext context) =>
      sizeOf(context).shortestSide < compactPhoneBreakpoint;

  static bool isLandscape(BuildContext context) =>
      sizeOf(context).width > sizeOf(context).height;

  static double horizontalPadding(BuildContext context) {
    if (isTablet(context)) return 40;
    if (isCompactPhone(context)) return 20;
    return 24;
  }

  static double contentMaxWidth(BuildContext context) {
    final width = sizeOf(context).width;
    if (!isTablet(context)) return width;
    return math.min(width, contentMaxWidthTablet);
  }

  static int gridCrossAxisCount(BuildContext context) {
    if (!isTablet(context)) return 2;
    final width = sizeOf(context).width;
    if (width >= 900) return 4;
    return 3;
  }

  static int folderGridCrossAxisCount(BuildContext context) {
    if (!isTablet(context)) return 2;
    return 3;
  }

  static double wheelPickerWidth(BuildContext context) {
    final width = sizeOf(context).width;
    return math.min(280, width * 0.55).clamp(200.0, 280.0).toDouble();
  }

  static double heroHeight(BuildContext context, {double topInset = 0}) {
    final height = sizeOf(context).height;
    return (height * 0.32).clamp(220.0, 320.0) + topInset;
  }

  /// Bottom spacer so scroll content clears the floating tab bar.
  static double scrollBottomPadding(BuildContext context) {
    const navContentHeight = 74.0;
    const buffer = 20.0;
    return navContentHeight + paddingOf(context).bottom + buffer;
  }

  static double rulesCardWidth(BuildContext context) {
    if (isTablet(context)) return 220;
    if (isCompactPhone(context)) return 168;
    return 180;
  }

  static double rulesCardHeight(BuildContext context) {
    if (isTablet(context)) return 220;
    return 200;
  }

  static double timerClockWidth(BuildContext context) {
    final width = sizeOf(context).width;
    final maxClock = isTablet(context) ? 360.0 : 260.0;
    return (width - 48).clamp(200.0, maxClock);
  }

  static double profileChartHeight(BuildContext context) {
    final width = sizeOf(context).width;
    return math.max(180, math.min(240, width * 0.25));
  }

  static TextScaler clampedTextScaler(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final scale = scaler.scale(1);
    if (scale <= maxTextScaleFactor) return scaler;
    return TextScaler.linear(maxTextScaleFactor);
  }

  /// Centers tab content on tablets while leaving phones full-bleed.
  static Widget centeredContent({
    required BuildContext context,
    required Widget child,
    bool enabled = true,
  }) {
    if (!enabled || !isTablet(context)) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: contentMaxWidth(context)),
        child: child,
      ),
    );
  }

  /// Constrains bottom sheets on wide screens.
  static Widget constrainedSheet({
    required BuildContext context,
    required Widget child,
  }) {
    if (!isTablet(context)) return child;
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: sheetMaxWidthTablet),
        child: child,
      ),
    );
  }
}

/// Centers a tab child on tablets while keeping phones full-bleed.
class ResponsiveCenteredTab extends StatelessWidget {
  final Widget child;

  const ResponsiveCenteredTab({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Responsive.centeredContent(context: context, child: child);
  }
}
