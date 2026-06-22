import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/autofocus_settings_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/settings/overlay_intervention_preview.dart';
import '../../widgets/settings/settings_row.dart';
import '../../widgets/settings/settings_section.dart';
import '../../widgets/shared/circle_icon_button.dart';

class AutofocusSettingsScreen extends StatelessWidget {
  const AutofocusSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final autofocus = context.watch<AutofocusSettingsProvider>();

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
                      'Autofocus',
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
                  const OverlayInterventionPreview(),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'Get intelligent alerts and blocks based on your activities and previous usage habits.',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SettingsSectionCard(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Interventions',
                            style: AppTheme.bodyLarge.copyWith(
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      SettingsRow(
                        icon: Icons.layers_outlined,
                        title: 'Overlay',
                        description: 'When using Distracting Apps',
                        isLast: true,
                        trailing: CupertinoSwitch(
                          value: autofocus.overlayEnabled,
                          activeTrackColor:
                              AppTheme.screenTimerControllerMintGlow,
                          inactiveTrackColor:
                              AppTheme.screenTimerControllerToggleInactive,
                          onChanged: (value) => context
                              .read<AutofocusSettingsProvider>()
                              .setOverlayEnabled(value),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
