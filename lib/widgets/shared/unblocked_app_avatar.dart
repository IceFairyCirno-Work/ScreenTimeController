import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'app_icon.dart';

const kUnblockedAppOuterSize = 72.0;
const kUnblockedAppInnerSize = 66.0;
const kUnblockedAppLockSize = 22.0;
const kUnblockedAppRingStroke = 3.0;

/// App icon with blocked lock overlay or unblock progress ring.
class UnblockedAppAvatar extends StatelessWidget {
  final Uint8List? iconBytes;
  final bool isBlocked;
  final double? progress;
  final double outerSize;
  final double innerSize;

  const UnblockedAppAvatar({
    super.key,
    this.iconBytes,
    required this.isBlocked,
    this.progress,
    this.outerSize = kUnblockedAppOuterSize,
    this.innerSize = kUnblockedAppInnerSize,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: outerSize,
      height: outerSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isBlocked)
            Container(
              width: outerSize,
              height: outerSize,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.screenTimerControllerMint,
                    AppTheme.screenTimerControllerMintGlow,
                  ],
                ),
              ),
            )
          else if (progress != null)
            CustomPaint(
              size: Size(outerSize, outerSize),
              painter: UnblockProgressRingPainter(progress: progress!),
            )
          else
            Container(
              width: outerSize,
              height: outerSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.screenTimerControllerMint.withValues(alpha: 0.35),
                  width: kUnblockedAppRingStroke,
                ),
              ),
            ),
          Container(
            width: innerSize,
            height: innerSize,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.surface,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AppIcon(
                  iconBytes: iconBytes,
                  size: innerSize,
                  borderRadius: innerSize / 2,
                  fallbackIconColor: AppTheme.textPrimary,
                  fallbackIconSize: innerSize * 0.37,
                ),
                if (isBlocked) ...[
                  Container(
                    width: innerSize,
                    height: innerSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.4),
                    ),
                  ),
                  Icon(
                    Icons.lock,
                    size: kUnblockedAppLockSize,
                    color: Colors.white,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Green ring whose arc length reflects remaining unblock time.
class UnblockProgressRingPainter extends CustomPainter {
  final double progress;

  const UnblockProgressRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final inset = kUnblockedAppRingStroke / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - kUnblockedAppRingStroke,
      size.height - kUnblockedAppRingStroke,
    );

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = kUnblockedAppRingStroke
      ..color = AppTheme.screenTimerControllerMint.withValues(alpha: 0.18);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = kUnblockedAppRingStroke
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppTheme.screenTimerControllerMint, AppTheme.screenTimerControllerMintGlow],
      ).createShader(rect);

    canvas.drawArc(rect, 0, 2 * math.pi, false, track);
    if (progress > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        arc,
      );
    }
  }

  @override
  bool shouldRepaint(covariant UnblockProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
