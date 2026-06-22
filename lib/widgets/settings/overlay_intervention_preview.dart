import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Preview image showing the distracting-app overlay intervention.
class OverlayInterventionPreview extends StatelessWidget {
  static const _assetPath = 'assets/images/overlay_intervention_preview.png';

  const OverlayInterventionPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: 0.35,
        child: Image.asset(
          _assetPath,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: double.infinity,
              height: 200,
              color: AppTheme.screenTimerControllerPillBg,
              alignment: Alignment.center,
              child: Text(
                'Preview unavailable',
                style: AppTheme.bodyMedium,
              ),
            );
          },
        ),
      ),
    );
  }
}
