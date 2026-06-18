import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class MetricsRow extends StatelessWidget {
  final int sleepScore;
  final int focus;
  final int rest;
  final bool showBracket;
  final double animationProgress;

  const MetricsRow({
    super.key,
    required this.sleepScore,
    required this.focus,
    required this.rest,
    this.showBracket = true,
    this.animationProgress = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          if (showBracket) ...[
            CustomPaint(
              painter: _BracketPainter(),
              child: const SizedBox(height: 12, width: double.infinity),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: _MetricPill(
                  icon: Icons.nightlight_round,
                  value: sleepScore,
                  label: 'Sleep',
                  progress: (sleepScore / 100).clamp(0.0, 1.0),
                  animationProgress: animationProgress,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricPill(
                  icon: Icons.hourglass_bottom_outlined,
                  value: focus,
                  label: 'Focus',
                  progress: (focus / 100).clamp(0.0, 1.0),
                  animationProgress: animationProgress,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricPill(
                  icon: Icons.park_outlined,
                  value: rest,
                  label: 'Rest',
                  progress: (rest / 100).clamp(0.0, 1.0),
                  animationProgress: animationProgress,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  final double progress;
  final double animationProgress;

  const _MetricPill({
    required this.icon,
    required this.value,
    required this.label,
    required this.progress,
    required this.animationProgress,
  });

  @override
  Widget build(BuildContext context) {
    final animatedProgress = (progress * animationProgress).clamp(0.0, 1.0);
    final isActive = progress > 0;
    final iconColor = isActive ? AppTheme.screenTimerControllerMint : AppTheme.textSecondary;

    const strokeWidth = 1.4;
    const glowPadding = 6.0;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(glowPadding),
          child: CustomPaint(
            foregroundPainter: _ProgressBorderPainter(
              progress: animatedProgress,
              borderRadius: 24,
              strokeWidth: strokeWidth,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.screenTimerControllerPillBg,
                borderRadius: BorderRadius.circular(24),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: iconColor, size: 17),
                    const SizedBox(width: 4),
                    Text(
                      '$value',
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _ProgressBorderPainter extends CustomPainter {
  final double progress;
  final double borderRadius;
  final double strokeWidth;

  _ProgressBorderPainter({
    required this.progress,
    required this.borderRadius,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(borderRadius),
    );

    // Background border (dim gray)
    final backgroundPaint = Paint()
      ..color = AppTheme.cardBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawRRect(rrect, backgroundPaint);

    if (progress <= 0) return;

    final path = Path()..addRRect(rrect);
    final pathMetrics = path.computeMetrics().first;
    final sweep = pathMetrics.length * progress;
    // RRect contour starts at the top-left arc (left, top + r), not the flat top edge.
    final topCenterOffset = _topCenterPathOffset(rect, rrect.tlRadiusX);
    final progressPath = _extractClockwisePath(
      pathMetrics,
      topCenterOffset,
      sweep,
    );

    // Layer 1: Outer glow (blurred, wider stroke)
    final glowPaint = Paint()
      ..color = AppTheme.screenTimerControllerMintGlow.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 4
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawPath(progressPath, glowPaint);

    // Layer 2: Inner glow (softer, tighter)
    final innerGlowPaint = Paint()
      ..color = AppTheme.screenTimerControllerMintGlow.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 2
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    canvas.drawPath(progressPath, innerGlowPaint);

    // Layer 3: Solid progress line on top
    final progressPaint = Paint()
      ..color = AppTheme.screenTimerControllerMint
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(progressPath, progressPaint);
  }

  /// Distance along the RRect contour to the geometric top-center point.
  double _topCenterPathOffset(Rect rect, double radius) {
    final topArcLength = radius * math.pi / 2;
    final topEdgeLength = math.max(0.0, rect.width - 2 * radius);
    return topArcLength + topEdgeLength / 2;
  }

  /// Extracts a path segment clockwise from [startOffset], sweeping [sweep]
  /// length along the capsule perimeter (toward the right).
  Path _extractClockwisePath(
    PathMetric pathMetrics,
    double startOffset,
    double sweep,
  ) {
    final totalLength = pathMetrics.length;
    if (sweep <= 0) return Path();

    final startPos = startOffset % totalLength;
    final endPos = startPos + sweep;

    if (endPos <= totalLength) {
      return pathMetrics.extractPath(startPos, endPos);
    }

    final firstSegment = pathMetrics.extractPath(startPos, totalLength);
    final secondSegment = pathMetrics.extractPath(0, endPos - totalLength);
    return Path()
      ..addPath(firstSegment, Offset.zero)
      ..addPath(secondSegment, Offset.zero);
  }

  @override
  bool shouldRepaint(covariant _ProgressBorderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class _BracketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.screenTimerControllerMint.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final w = size.width;
    final h = size.height;
    final path = Path();
    path.moveTo(w * 0.12, h);
    path.lineTo(w * 0.12, h * 0.3);
    path.lineTo(w * 0.5, 0);
    path.lineTo(w * 0.88, h * 0.3);
    path.lineTo(w * 0.88, h);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
