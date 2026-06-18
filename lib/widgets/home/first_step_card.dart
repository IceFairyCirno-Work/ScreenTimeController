import 'package:flutter/material.dart';

import '../../services/streak_copy.dart';
import '../../theme/app_theme.dart';

class FirstStepCard extends StatelessWidget {
  final int streakCount;

  const FirstStepCard({super.key, required this.streakCount});

  @override
  Widget build(BuildContext context) {
    final copy = StreakCopy.forStreak(streakCount);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
      decoration: BoxDecoration(
        color: AppTheme.screenTimerControllerCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.title,
                  style: AppTheme.bodyLarge.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  copy.body,
                  style: AppTheme.bodyMedium.copyWith(
                    fontSize: 14,
                    height: 1.45,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const _FireLogo(),
        ],
      ),
    );
  }
}

class _FireLogo extends StatelessWidget {
  const _FireLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.local_fire_department,
            size: 72,
            color: AppTheme.screenTimerControllerFlame.withValues(alpha: 0.2),
          ),
          Icon(
            Icons.local_fire_department,
            size: 56,
            color: AppTheme.screenTimerControllerFlame.withValues(alpha: 0.45),
          ),
          const Icon(
            Icons.local_fire_department,
            size: 44,
            color: AppTheme.screenTimerControllerFlame,
          ),
        ],
      ),
    );
  }
}
