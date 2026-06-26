import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../widgets/settings/settings_row.dart';
import '../../widgets/settings/settings_section.dart';
import '../../widgets/shared/circle_icon_button.dart';

class AboutSettingsScreen extends StatelessWidget {
  const AboutSettingsScreen({super.key});

  static const _chevronTrailing = Icon(
    Icons.chevron_right_rounded,
    color: AppTheme.textHint,
    size: 22,
  );

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
                      'About Silo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.headingMedium.copyWith(fontSize: 20),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Responsive.centeredContent(
                context: context,
                child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 6, 24, 32),
                children: [
                  const SettingsSectionLabel(title: 'Legal'),
                  SettingsSectionCard(
                    children: [
                      SettingsRow(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Privacy Policy',
                        description: 'How Silo collects and uses your data',
                        trailing: _chevronTrailing,
                        onTap: () {},
                      ),
                      SettingsRow(
                        icon: Icons.description_outlined,
                        title: 'Terms of Use',
                        description: 'Rules and conditions for using Silo',
                        isLast: true,
                        trailing: _chevronTrailing,
                        onTap: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }
}
