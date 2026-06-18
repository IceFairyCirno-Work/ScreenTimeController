import 'package:flutter/material.dart';

import '../../models/gem_unlock_info.dart';
import '../../theme/app_theme.dart';
import '../../widgets/home/gem_unlock_sheet.dart';

/// Full-screen welcome gem ceremony shown before the user enters home.
class WelcomeGemScreen extends StatelessWidget {
  final GemUnlockInfo info;
  final VoidCallback onConfirm;

  const WelcomeGemScreen({
    super.key,
    required this.info,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          bottom: false,
          child: GemUnlockContent(
            info: info,
            confirmOnly: true,
            onComplete: (_) => onConfirm(),
          ),
        ),
      ),
    );
  }
}
