import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class ScoreSection extends StatelessWidget {
  final int score;
  final VoidCallback onTap;

  const ScoreSection({
    super.key,
    required this.score,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Text('Score', style: AppTheme.screenTimerControllerScoreLabel),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$score', style: AppTheme.screenTimerControllerScore),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Icon(
                  Icons.arrow_drop_down,
                  color: AppTheme.screenTimerControllerMint,
                  size: 28,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
