import 'dart:math';
import 'package:flutter/material.dart';

import '../../models/focus_template.dart';

/// Shared grain overlay used by all template painters for a cohesive texture.
void _addGrain(Canvas canvas, Size size, Random rng, {int count = 1800}) {
  for (int i = 0; i < count; i++) {
    final x = rng.nextDouble() * size.width;
    final y = rng.nextDouble() * size.height;
    final a = rng.nextDouble() * 0.07;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, y), width: 1.5, height: 1.5),
      Paint()..color = Colors.white.withValues(alpha: a),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 1. DEEP STUDY — deep indigo/violet, desk lamp glow, floating particles
// ═══════════════════════════════════════════════════════════════════
class DeepStudyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(11);

    // Deep night-sky gradient
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF1A1340),
          Color(0xFF2D1B69),
          Color(0xFF0E0A2E),
        ],
        stops: [0.0, 0.5, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Warm desk-lamp glow (bottom-right)
    final lampPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.75, 0.55),
        radius: 0.7,
        colors: [
          const Color(0xFFFFB347).withValues(alpha: 0.45),
          const Color(0xFFFF8C42).withValues(alpha: 0.15),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, lampPaint);

    // Floating dust particles (knowledge/sparkles)
    for (int i = 0; i < 35; i++) {
      final cx = rng.nextDouble() * size.width;
      final cy = rng.nextDouble() * size.height * 0.7;
      final r = 1.0 + rng.nextDouble() * 2.5;
      final a = 0.2 + rng.nextDouble() * 0.5;
      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()..color = const Color(0xFFFFE5B4).withValues(alpha: a),
      );
    }

    // Subtle horizontal "book stack" lines (abstract knowledge shelves)
    final linePaint = Paint()
      ..color = const Color(0xFF6A5ACD).withValues(alpha: 0.18)
      ..strokeWidth = 2.0;
    for (int i = 0; i < 4; i++) {
      final y = size.height * (0.62 + i * 0.08);
      final startX = size.width * 0.1 + rng.nextDouble() * 30;
      final endX = size.width * 0.9 - rng.nextDouble() * 30;
      canvas.drawLine(Offset(startX, y), Offset(endX, y), linePaint);
    }

    _addGrain(canvas, size, rng);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════
// 2. COMMUTE — city silhouette at warm sunrise
// ═══════════════════════════════════════════════════════════════════
class CommutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(22);

    // Sunrise gradient
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF1B1F3B),
          Color(0xFF6B2D5C),
          Color(0xFFE8743A),
          Color(0xFFFFB347),
        ],
        stops: [0.0, 0.35, 0.75, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, skyPaint);

    // Sun glow
    final sunPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, 0.75),
        radius: 0.5,
        colors: [
          const Color(0xFFFFD580).withValues(alpha: 0.8),
          const Color(0xFFFF8C42).withValues(alpha: 0.3),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sunPaint);

    // Skyline silhouette
    final cityPaint = Paint()..color = const Color(0xFF0E0A1F);
    double x = 0;
    while (x < size.width) {
      final w = 14.0 + rng.nextDouble() * 30;
      final h = 30.0 + rng.nextDouble() * 80;
      canvas.drawRect(
        Rect.fromLTWH(x, size.height - h, w, h),
        cityPaint,
      );
      // Windows
      for (int wy = 0; wy < h - 10; wy += 10) {
        for (int wx = 3; wx < w - 3; wx += 7) {
          if (rng.nextDouble() > 0.7) {
            canvas.drawRect(
              Rect.fromLTWH(x + wx, size.height - h + wy + 4, 2, 3),
              Paint()..color = const Color(0xFFFFE5B4).withValues(alpha: 0.6),
            );
          }
        }
      }
      x += w + 2;
    }

    _addGrain(canvas, size, rng);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════
// 3. WORKOUT — energetic red-orange with motion streaks
// ═══════════════════════════════════════════════════════════════════
class WorkoutPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(33);

    // Energetic red-orange gradient
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF2A0A0A),
          Color(0xFFB22222),
          Color(0xFFFF6347),
          Color(0xFFFF8C00),
        ],
        stops: [0.0, 0.35, 0.7, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Dynamic motion streaks (diagonal energy lines)
    final streakPaint = Paint()
      ..color = const Color(0xFFFFD700).withValues(alpha: 0.25)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 10; i++) {
      final startX = rng.nextDouble() * size.width;
      final startY = -20.0 + rng.nextDouble() * size.height;
      final length = 60.0 + rng.nextDouble() * 120;
      final path = Path()
        ..moveTo(startX, startY)
        ..lineTo(startX + length * 0.3, startY + length);
      canvas.drawPath(path, streakPaint);
    }

    // Central energy burst (radial pulse)
    final burstPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, 0.3),
        radius: 0.6,
        colors: [
          const Color(0xFFFFEB3B).withValues(alpha: 0.5),
          const Color(0xFFFF6347).withValues(alpha: 0.2),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, burstPaint);

    // Sweat/spark particles
    for (int i = 0; i < 30; i++) {
      final cx = rng.nextDouble() * size.width;
      final cy = rng.nextDouble() * size.height;
      final r = 1.0 + rng.nextDouble() * 2.0;
      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()..color = const Color(0xFFFFEB3B).withValues(alpha: 0.5),
      );
    }

    _addGrain(canvas, size, rng);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════
// 4. READING — warm amber, cozy library atmosphere
// ═══════════════════════════════════════════════════════════════════
class ReadingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(44);

    // Warm cozy gradient (candlelit)
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF2E1810),
          Color(0xFF6B4423),
          Color(0xFF8B5A2B),
          Color(0xFFA0723A),
        ],
        stops: [0.0, 0.4, 0.75, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Candle glow (warm central light)
    final candlePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.3, 0.4),
        radius: 0.65,
        colors: [
          const Color(0xFFFFE4B5).withValues(alpha: 0.7),
          const Color(0xFFFFA500).withValues(alpha: 0.25),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, candlePaint);

    // Abstract book pages (soft horizontal cream strokes)
    final pagePaint = Paint()
      ..color = const Color(0xFFFFF8DC).withValues(alpha: 0.18)
      ..strokeWidth = 1.5;
    for (int i = 0; i < 12; i++) {
      final y = size.height * (0.45 + rng.nextDouble() * 0.4);
      final startX = size.width * 0.15 + rng.nextDouble() * 40;
      final endX = size.width * 0.85 - rng.nextDouble() * 40;
      canvas.drawLine(Offset(startX, y), Offset(endX, y), pagePaint);
    }

    // Floating dust motes in candlelight
    for (int i = 0; i < 25; i++) {
      final cx = rng.nextDouble() * size.width;
      final cy = rng.nextDouble() * size.height;
      final r = 0.8 + rng.nextDouble() * 1.8;
      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()..color = const Color(0xFFFFE4B5).withValues(alpha: 0.45),
      );
    }

    _addGrain(canvas, size, rng);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════
// 5. WEEKEND ZEN — calm teal/green, serene nature
// ═══════════════════════════════════════════════════════════════════
class WeekendZenPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(55);

    // Serene nature gradient
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF0A2E2A),
          Color(0xFF1A5253),
          Color(0xFF3A7D6E),
          Color(0xFF8FBC8F),
        ],
        stops: [0.0, 0.4, 0.75, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Soft morning mist
    final mistPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, 0.65),
        radius: 0.8,
        colors: [
          const Color(0xFFE0F2E9).withValues(alpha: 0.3),
          const Color(0xFF8FBC8F).withValues(alpha: 0.1),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, mistPaint);

    // Mountain layers (calm horizon)
    for (int layer = 0; layer < 3; layer++) {
      final yBase = size.height * (0.55 + layer * 0.1);
      final path = Path()..moveTo(0, yBase + 40);
      double x = 0;
      while (x < size.width) {
        final peakH = 20.0 + rng.nextDouble() * (50 - layer * 10);
        path.lineTo(x + 20, yBase - peakH);
        path.lineTo(x + 40, yBase + 10);
        x += 40;
      }
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.close();
      canvas.drawPath(
        path,
        Paint()..color = Color(0xFF1A3A36).withValues(alpha: 0.5 - layer * 0.12),
      );
    }

    // Floating leaves/petals
    for (int i = 0; i < 20; i++) {
      final cx = rng.nextDouble() * size.width;
      final cy = rng.nextDouble() * size.height * 0.7;
      final r = 1.5 + rng.nextDouble() * 2.5;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: r * 2, height: r),
        Paint()..color = const Color(0xFFC8E6C9).withValues(alpha: 0.55),
      );
    }

    _addGrain(canvas, size, rng);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Returns the matching painter for a [FocusTemplateArt] value.
CustomPainter painterForArt(FocusTemplateArt art) {
  switch (art) {
    case FocusTemplateArt.deepStudy:
      return DeepStudyPainter();
    case FocusTemplateArt.commute:
      return CommutePainter();
    case FocusTemplateArt.workout:
      return WorkoutPainter();
    case FocusTemplateArt.reading:
      return ReadingPainter();
    case FocusTemplateArt.weekendZen:
      return WeekendZenPainter();
  }
}
