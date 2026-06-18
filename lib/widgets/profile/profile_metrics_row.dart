import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Two-column metrics row centered below the username on the profile screen.
///
///  - Left: hourglass icon, large value, "FOCUS HOURS" label.
///  - Right: flame icon, large value, "DAY STREAK" label (yellow tinted).
class ProfileMetricsRow extends StatelessWidget {
  final String focusHoursValue;
  final String dayStreakValue;

  const ProfileMetricsRow({
    super.key,
    this.focusHoursValue = '--',
    this.dayStreakValue = '0',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricColumn(
            icon: Icons.hourglass_bottom_outlined,
            iconColor: AppTheme.textSecondary,
            value: focusHoursValue,
            valueColor: AppTheme.textPrimary,
            label: 'FOCUS HOURS',
            labelColor: AppTheme.textSecondary,
          ),
        ),
        // Thin vertical divider between the two columns.
        Container(
          width: 1,
          height: 48,
          color: AppTheme.cardBorder.withValues(alpha: 0.6),
        ),
        Expanded(
          child: _MetricColumn(
            icon: Icons.local_fire_department,
            iconColor: AppTheme.screenTimerControllerFlame,
            iconGlow: true,
            value: dayStreakValue,
            valueColor: const Color(0xFFFFC857),
            label: 'DAY STREAK',
            labelColor: const Color(0xFFFFC857).withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

class _MetricColumn extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final bool iconGlow;
  final String value;
  final Color valueColor;
  final String label;
  final Color labelColor;

  const _MetricColumn({
    required this.icon,
    required this.iconColor,
    this.iconGlow = false,
    required this.value,
    required this.valueColor,
    required this.label,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(
      icon,
      size: 26,
      color: iconColor,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Wrap the glowing flame in its own paint layer so the glow never
        // bleeds into sibling widgets during scroll.
        if (iconGlow)
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: iconColor.withValues(alpha: 0.55),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: iconWidget,
          )
        else
          iconWidget,
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: valueColor,
            height: 1.0,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: labelColor,
            letterSpacing: 1.2,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}
