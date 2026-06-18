import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class OnboardingProgressIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final int maxReachableStep;
  final ValueChanged<int>? onStepTap;

  const OnboardingProgressIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.maxReachableStep,
    this.onStepTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Row(
        children: List.generate(totalSteps, (index) {
          final isActive = index <= currentStep;
          final canTap = onStepTap != null && index <= maxReachableStep;
          return Expanded(
            child: GestureDetector(
              onTap: canTap ? () => onStepTap!(index) : null,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 3),
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: isActive ? AppTheme.accent : AppTheme.surface,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
