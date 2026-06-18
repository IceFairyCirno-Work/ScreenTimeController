import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// A glowing hexagon-framed avatar with a green-to-cyan gradient border
/// containing a minimalist white user silhouette.
///
/// Used in two places on the profile screen:
///  - the large avatar in the profile summary (morphs into the header)
///  - the morph target inside the sticky header (when scrolled)
class ProfileAvatar extends StatelessWidget {
  final double size;

  /// Stroke width of the gradient border.
  final double borderWidth;

  /// Whether to render the soft outer glow. Disabled for the header version to
  /// keep the top bar visually quiet.
  final bool showGlow;

  const ProfileAvatar({
    super.key,
    required this.size,
    this.borderWidth = 2.0,
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _HexagonPainter(
          borderWidth: borderWidth,
          showGlow: showGlow,
        ),
        child: Center(
          child: Icon(
            Icons.person_outline,
            size: size * 0.42,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// Paints a pointy-top hexagon filled with a dark center, surrounded by a
/// green→cyan gradient stroke and an optional outer glow.
class _HexagonPainter extends CustomPainter {
  final double borderWidth;
  final bool showGlow;

  _HexagonPainter({
    required this.borderWidth,
    required this.showGlow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final hex = _hexagonPath(Size(w, h));

    // Outer glow layers (only when enabled).
    if (showGlow) {
      final glowPaint = Paint()
        ..color = AppTheme.screenTimerControllerMintGlow.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth + 6
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawPath(hex, glowPaint);

      final innerGlow = Paint()
        ..color = AppTheme.screenTimerControllerMintGlow.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth + 3
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawPath(hex, innerGlow);
    }

    // Dark fill so the silhouette reads against any background.
    final fillPaint = Paint()
      ..color = const Color(0xFF0E0E0E)
      ..style = PaintingStyle.fill;
    canvas.drawPath(hex, fillPaint);

    // Green→cyan gradient stroke.
    final borderPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppTheme.screenTimerControllerMintGlow,
          AppTheme.screenTimerControllerMint,
        ],
      ).createShader(Rect.fromCenter(center: center, width: w, height: h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(hex, borderPaint);
  }

  /// A pointy-top hexagon inscribed in [size].
  Path _hexagonPath(Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final radius = math.min(w, h) / 2;
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = -math.pi / 2 + i * (math.pi / 3);
      final x = cx + radius * math.cos(angle);
      final y = cy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _HexagonPainter oldDelegate) =>
      oldDelegate.borderWidth != borderWidth ||
      oldDelegate.showGlow != showGlow;
}
