import 'package:flutter/material.dart';

import '../../screens/settings/about_settings_screen.dart';
import '../../screens/settings/autofocus_settings_screen.dart';
import '../../screens/settings/emergency_pass_screen.dart';
import '../../screens/settings/my_account_screen.dart';
import '../../screens/settings/permissions_settings_screen.dart';
import '../../theme/app_theme.dart';
import '../../widgets/settings/settings_row.dart';
import '../../widgets/settings/settings_section.dart';
import '../../widgets/shared/circle_icon_button.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _chevronTrailing = Icon(
    Icons.chevron_right_rounded,
    color: AppTheme.textHint,
    size: 22,
  );

  void _openMyAccount(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MyAccountScreen()),
    );
  }

  void _openPermissions(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PermissionsSettingsScreen()),
    );
  }

  void _openEmergencyPass(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EmergencyPassScreen()),
    );
  }

  void _openAbout(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AboutSettingsScreen()),
    );
  }

  void _openAutofocus(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AutofocusSettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: Row(
                children: [
                  CircleIconButton(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Settings',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.headingMedium.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 6, 24, 32),
                children: [
                  const SettingsSectionLabel(title: 'Profile'),
                  SettingsSectionCard(
                    children: [
                      SettingsRow(
                        icon: Icons.person_outline_rounded,
                        title: 'My account',
                        trailing: _chevronTrailing,
                        onTap: () => _openMyAccount(context),
                      ),
                      SettingsRow(
                        icon: Icons.paid_outlined,
                        title: 'Membership',
                        isLast: true,
                        trailing: Text(
                          'Free',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const SettingsSectionLabel(title: 'Personalize'),
                  SettingsSectionCard(
                    children: [
                      SettingsRow(
                        icon: Icons.auto_fix_high_rounded,
                        title: 'Autofocus',
                        isLast: true,
                        trailing: _chevronTrailing,
                        onTap: () => _openAutofocus(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const SettingsSectionLabel(title: 'Support'),
                  SettingsSectionCard(
                    children: [
                      SettingsRow(
                        icon: Icons.help_outline_rounded,
                        title: 'Help centre',
                        trailing: _chevronTrailing,
                        onTap: () {},
                      ),
                      SettingsRow(
                        icon: Icons.confirmation_number_outlined,
                        title: 'Emergency pass',
                        isLast: true,
                        trailing: _chevronTrailing,
                        onTap: () => _openEmergencyPass(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const SettingsSectionLabel(title: 'Other'),
                  SettingsSectionCard(
                    children: [
                      SettingsRow(
                        icon: Icons.tune_rounded,
                        title: 'Permissions',
                        trailing: _chevronTrailing,
                        onTap: () => _openPermissions(context),
                      ),
                      SettingsRow(
                        icon: Icons.restore_rounded,
                        title: 'Restore purchase',
                        trailing: _chevronTrailing,
                        onTap: () {},
                      ),
                      SettingsRow(
                        icon: Icons.info_outline_rounded,
                        title: 'About Silo',
                        isLast: true,
                        trailing: _chevronTrailing,
                        onTap: () => _openAbout(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'v0.9',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
