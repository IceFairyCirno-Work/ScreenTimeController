import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class HomeHeader extends StatelessWidget {
  final int streakCount;
  final VoidCallback onProfileTap;

  const HomeHeader({
    super.key,
    required this.streakCount,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: [
          Text(
            'Silo',
            style: AppTheme.headingMedium.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Icon(Icons.local_fire_department, color: AppTheme.screenTimerControllerFlame, size: 22),
              const SizedBox(width: 4),
              Text(
                '$streakCount',
                style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: onProfileTap,
                child: CustomPaint(
                  painter: _HexagonPainter(),
                  child: const SizedBox(
                    width: 36,
                    height: 36,
                    child: Icon(
                      Icons.person_outline,
                      color: AppTheme.screenTimerControllerMint,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HexagonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.screenTimerControllerMint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();
    final w = size.width;
    final h = size.height;
    path.moveTo(w * 0.5, 2);
    path.lineTo(w - 4, h * 0.28);
    path.lineTo(w - 4, h * 0.72);
    path.lineTo(w * 0.5, h - 2);
    path.lineTo(4, h * 0.72);
    path.lineTo(4, h * 0.28);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
