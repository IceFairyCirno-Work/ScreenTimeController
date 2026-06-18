import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NextButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool isEnabled;

  const NextButton({
    super.key,
    this.text = 'Continue',
    required this.onTap,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: isEnabled ? AppTheme.accent : AppTheme.surface,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Center(
          child: Text(
            text,
            style: AppTheme.buttonText.copyWith(
              color: isEnabled ? AppTheme.textOnAccent : AppTheme.textHint,
            ),
          ),
        ),
      ),
    );
  }
}
