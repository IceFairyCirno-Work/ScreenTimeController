import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_permission.dart';
import '../../providers/permissions_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/platform_capabilities.dart';
import 'permission_row.dart';

/// Grouped permission list shared by onboarding and settings.
class PermissionsGroupList extends StatelessWidget {
  final bool lockRequiredWhenGranted;
  final bool singleSection;
  final bool hideSectionHeader;

  const PermissionsGroupList({
    super.key,
    this.lockRequiredWhenGranted = true,
    this.singleSection = false,
    this.hideSectionHeader = false,
  });

  bool _isOn(PermissionsProvider permissions, AppPermissionType type) {
    if (type == AppPermissionType.notifications) {
      return permissions.notificationsOn;
    }
    return permissions.isGranted(type);
  }

  @override
  Widget build(BuildContext context) {
    final permissions = context.watch<PermissionsProvider>();

    if (singleSection) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (PlatformCapabilities.isIOS) ...[
            const _IosFeatureAvailabilityCard(),
            const SizedBox(height: 20),
          ],
          if (!hideSectionHeader)
            const PermissionSectionHeader(
              title: 'Permissions',
              padding: EdgeInsets.only(bottom: 14),
            ),
          ...platformAllPermissions.asMap().entries.map(
            (entry) => PermissionRow(
              permission: entry.value,
              isOn: _isOn(permissions, entry.value),
              lockWhenGranted: lockRequiredWhenGranted &&
                  entry.value != AppPermissionType.notifications &&
                  entry.value != AppPermissionType.screenTimeApi,
              isLast: entry.key == platformAllPermissions.length - 1,
              onChanged: (value) => permissions.onToggle(entry.value, value),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (PlatformCapabilities.isIOS) ...[
          const _IosFeatureAvailabilityCard(),
          const SizedBox(height: 20),
        ],
        if (platformRequiredPermissions.isNotEmpty) ...[
          const PermissionSectionHeader(title: 'Required'),
          ...platformRequiredPermissions.asMap().entries.map(
            (entry) => PermissionRow(
              permission: entry.value,
              isOn: permissions.isGranted(entry.value),
              lockWhenGranted: lockRequiredWhenGranted,
              isLast: entry.key == platformRequiredPermissions.length - 1,
              onChanged: (value) => permissions.onToggle(entry.value, value),
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (platformOtherPermissions.isNotEmpty) ...[
          PermissionSectionHeader(
            title: platformRequiredPermissions.isEmpty ? 'Permissions' : 'Other',
          ),
          ...platformOtherPermissions.asMap().entries.map(
            (entry) => PermissionRow(
              permission: entry.value,
              isOn: _isOn(permissions, entry.value),
              isLast: entry.key == platformOtherPermissions.length - 1,
              onChanged: (value) => permissions.onToggle(entry.value, value),
            ),
          ),
        ],
      ],
    );
  }
}

class _IosFeatureAvailabilityCard extends StatelessWidget {
  const _IosFeatureAvailabilityCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.screenTimerControllerPillBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What works on iOS today',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          const _FeatureRow(
            available: true,
            label: 'Focus timers, rules, streaks & gems',
          ),
          const _FeatureRow(
            available: true,
            label: 'Rule notifications',
          ),
          const _FeatureRow(
            available: true,
            label: 'Estimated screen time from onboarding',
          ),
          const SizedBox(height: 8),
          Text(
            'Needs Screen Time API',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          const _FeatureRow(
            available: false,
            label: 'App picker & native blocking',
          ),
          const _FeatureRow(
            available: false,
            label: 'Real usage stats & enforcement',
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final bool available;
  final String label;

  const _FeatureRow({
    required this.available,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            available ? Icons.check_circle_outline : Icons.schedule_outlined,
            size: 18,
            color: available
                ? AppTheme.screenTimerControllerMint
                : AppTheme.textHint,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
                height: 1.45,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
