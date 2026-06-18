import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/account_reset_service.dart';
import '../../theme/app_theme.dart';
import '../shared/app_bottom_sheet.dart';
import '../shared/hold_to_confirm_button.dart';

/// Confirmation sheet for permanently deleting local account data.
Future<bool?> showDeleteAccountSheet(BuildContext context) {
  return showAppBottomSheet<bool>(
    context: context,
    backgroundColor: AppTheme.screenTimerControllerCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => const _DeleteAccountSheet(),
  );
}

class _DeleteAccountSheet extends StatefulWidget {
  const _DeleteAccountSheet();

  @override
  State<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<_DeleteAccountSheet> {
  static const _accent = AppTheme.screenTimerControllerDeepFocus;

  bool _isDeleting = false;

  Future<void> _deleteAccount() async {
    if (_isDeleting) return;
    setState(() => _isDeleting = true);

    try {
      await AccountResetService.instance.deleteAccount(context);
    } catch (e, stack) {
      debugPrint('Account deletion failed: $e\n$stack');
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete account. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 28,
        right: 28,
        top: 32,
        bottom: 32 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _accent,
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.delete_outline_rounded,
              color: _accent,
              size: 28,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Delete your account?',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'This permanently removes your profile, rules, streaks, gems, '
            'and all other app data on this device. You will start fresh '
            'from onboarding.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: AppTheme.textSecondary,
              height: 1.5,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 28),
          if (_isDeleting)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: CircularProgressIndicator(
                color: AppTheme.highlightPurple,
              ),
            )
          else ...[
            HoldToConfirmButton(
              label: 'Hold to delete',
              holdingLabel: 'Keep holding...',
              onComplete: _deleteAccount,
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
