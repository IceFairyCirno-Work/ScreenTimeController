import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/app_permission.dart';
import '../../theme/app_theme.dart';

/// A single permission row with icon, title, description, and toggle.
class PermissionRow extends StatelessWidget {
  final AppPermissionType permission;
  final bool isOn;
  final bool lockWhenGranted;
  final bool isLast;
  final ValueChanged<bool>? onChanged;

  const PermissionRow({
    super.key,
    required this.permission,
    required this.isOn,
    this.lockWhenGranted = false,
    this.isLast = false,
    this.onChanged,
  });

  bool get _isLocked => lockWhenGranted && isOn;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            permission.icon,
            color: AppTheme.textHint,
            size: 22,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  permission.title,
                  style: AppTheme.bodyLarge.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  permission.description,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          CupertinoSwitch(
            value: isOn,
            activeTrackColor: AppTheme.screenTimerControllerMintGlow,
            inactiveTrackColor: AppTheme.screenTimerControllerToggleInactive,
            onChanged: _isLocked ? null : onChanged,
          ),
        ],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row,
        if (!isLast)
          const Divider(
            height: 1,
            thickness: 1,
            indent: 52,
            color: Color(0x663A3A3C),
          ),
      ],
    );
  }
}

/// Left-aligned section title for permission groups.
class PermissionSectionHeader extends StatelessWidget {
  final String title;
  final EdgeInsetsGeometry padding;

  const PermissionSectionHeader({
    super.key,
    required this.title,
    this.padding = const EdgeInsets.only(bottom: 14, top: 4),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        title,
        style: AppTheme.headingMedium.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }
}
