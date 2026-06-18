import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Referral & rewards section: a header line ("Share pass, get rewards" +
/// "0" count) and a large horizontal gradient pass card with a faint laurel
/// seal watermark, the Silo logo, and a "30-day guest pass"
/// subtitle.
class ProfilePassSection extends StatelessWidget {
  final int remainingPasses;
  final VoidCallback? onShareApp;

  const ProfilePassSection({
    super.key,
    this.remainingPasses = 0,
    this.onShareApp,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header line.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Text(
                'Share pass, get rewards',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  decoration: TextDecoration.none,
                ),
              ),
              const Spacer(),
              Text(
                '$remainingPasses',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // The pass card.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _PassCard(),
        ),
        const SizedBox(height: 14),
        // White "Share app" button directly under the pass card.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _ShareAppButton(onTap: onShareApp),
        ),
      ],
    );
  }
}

/// A solid white pill button labeled "Share app". Meets the 48dp minimum touch
/// target and gives a subtle press feedback via InkWell.
class _ShareAppButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _ShareAppButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          alignment: Alignment.center,
          child: Text(
            'Share app',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black,
              letterSpacing: 0.2,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}

class _PassCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.65,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          // Glowing light-green → teal → soft gold gradient.
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFB8F5D6), // light green
              Color(0xFF6FE7C4), // mint/teal
              Color(0xFF5DD9B8), // teal
              Color(0xFFD9C58E), // soft gold undertone
            ],
            stops: [0.0, 0.35, 0.7, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6FE7C4).withValues(alpha: 0.35),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Faint laurel seal watermark in the background layer.
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: CustomPaint(
                  painter: _SealWatermarkPainter(),
                ),
              ),
            ),
            // Centered logo + subtitle.
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Silo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.3,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '30-day guest pass',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.9),
                      letterSpacing: 0.3,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A faint, simplified version of the laurel seal used as a background
/// watermark on the pass card.
class _SealWatermarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = math.min(w, h) * 0.42;

    final watermarkPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Outer ring.
    canvas.drawCircle(center, radius, watermarkPaint);
    // Inner ring.
    canvas.drawCircle(center, radius * 0.62, watermarkPaint);

    // Mirrored laurel arcs on both sides.
    _drawWreathArc(canvas, center, radius * 0.92, mirror: false);
    _drawWreathArc(canvas, center, radius * 0.92, mirror: true);

    // Curved Latin text hint around the top.
    _drawCurvedText(
      canvas,
      center,
      radius * 0.82,
      'THE FOCUS COMPANY',
      startAngle: -math.pi / 2 - 0.7,
      sweepAngle: 1.4,
    );

    // Small crescent moon at the top.
    _drawCrescent(canvas, center, radius);
  }

  void _drawWreathArc(
    Canvas canvas,
    Offset center,
    double radius, {
    required bool mirror,
  }) {
    final sign = mirror ? -1.0 : 1.0;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final startAngle = math.pi * (mirror ? 0.40 : 0.60);
    final endAngle = math.pi * (mirror ? -0.10 : 1.10);
    final steps = 12;

    final path = Path();
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final angle = startAngle + (endAngle - startAngle) * t;
      final x = center.dx + sign * radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);

    // Tiny leaves along the arc.
    final leafPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    final leafCount = 7;
    for (var i = 0; i < leafCount; i++) {
      final t = (i + 0.5) / leafCount;
      final angle = startAngle + (endAngle - startAngle) * t;
      final anchor = Offset(
        center.dx + sign * radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      final outward = i.isEven ? 1.0 : -1.0;
      final baseAngle = angle + (math.pi / 2 * outward);
      final dx = sign * math.cos(baseAngle) * 6;
      final dy = math.sin(baseAngle) * 6;
      final tip = Offset(anchor.dx + dx, anchor.dy + dy);
      canvas.drawCircle(
        Offset(
          (anchor.dx + tip.dx) / 2,
          (anchor.dy + tip.dy) / 2,
        ),
        2.5,
        leafPaint,
      );
    }
  }

  void _drawCurvedText(
    Canvas canvas,
    Offset center,
    double radius,
    String text, {
    required double startAngle,
    required double sweepAngle,
  }) {
    final chars = text.split('');
    final perChar = sweepAngle / chars.length;
    for (var i = 0; i < chars.length; i++) {
      final angle = startAngle + perChar * (i + 0.5);
      final tp = TextPainter(
        text: TextSpan(
          text: chars[i],
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: radius * 0.085,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle + math.pi / 2);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  void _drawCrescent(Canvas canvas, Offset center, double radius) {
    final moonCenter =
        Offset(center.dx, center.dy - radius * 0.70);
    final moonR = radius * 0.08;
    canvas.saveLayer(
      Rect.fromCircle(center: moonCenter, radius: moonR + 2),
      Paint(),
    );
    canvas.drawCircle(
      moonCenter,
      moonR,
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );
    canvas.drawCircle(
      Offset(moonCenter.dx + moonR * 0.45, moonCenter.dy - moonR * 0.15),
      moonR,
      Paint()..blendMode = BlendMode.dstOut,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
