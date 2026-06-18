import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/user_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/settings/account_field_row.dart';
import '../../widgets/settings/age_picker_sheet.dart';
import '../../widgets/settings/delete_account_sheet.dart';
import '../../screens/settings/occupation_edit_screen.dart';
import '../../widgets/settings/username_rename_sheet.dart';
import '../../widgets/shared/circle_icon_button.dart';

class MyAccountScreen extends StatelessWidget {
  const MyAccountScreen({super.key});

  static const _destructiveColor = AppTheme.screenTimerControllerDeepFocus;

  Future<void> _editName(BuildContext context) async {
    final userData = context.read<UserData>();
    final updated = await showUsernameRenameSheet(
      context,
      currentName: userData.displayName,
    );
    if (updated == null || !context.mounted) return;
    await userData.setDisplayName(updated);
  }

  void _editOccupation(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OccupationEditScreen()),
    );
  }

  Future<void> _editAge(BuildContext context) async {
    final userData = context.read<UserData>();
    final selected = await showAgePickerSheet(
      context,
      currentAge: userData.age ?? userData.ageMidpoint.round(),
    );
    if (selected == null || !context.mounted) return;
    await userData.setAge(selected);
  }

  String _ageDisplay(UserData userData) {
    if (userData.age != null) return userData.age.toString();
    if (userData.ageRange != null) {
      return userData.ageMidpoint.round().toString();
    }
    return 'Not set';
  }

  Future<void> _deleteAccount(BuildContext context) async {
    await showDeleteAccountSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final userData = context.watch<UserData>();

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
                      'My account',
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
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                children: [
                  AccountFieldRow(
                    icon: Icons.person_outline_rounded,
                    title: 'Your name',
                    value: userData.displayName,
                    onTap: () => _editName(context),
                  ),
                  AccountFieldRow(
                    icon: Icons.work_outline_rounded,
                    title: 'Occupation',
                    value: userData.occupation ?? 'Not set',
                    onTap: () => _editOccupation(context),
                  ),
                  AccountFieldRow(
                    icon: Icons.cake_outlined,
                    title: 'My age',
                    value: _ageDisplay(userData),
                    showDivider: false,
                    onTap: () => _editAge(context),
                  ),
                  const SizedBox(height: 48),
                  InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.logout_rounded,
                            color: AppTheme.textHint,
                            size: 22,
                          ),
                          const SizedBox(width: 14),
                          Text(
                            'Sign out',
                            style: AppTheme.bodyLarge.copyWith(
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(left: 36),
                    child: Text(
                      'You may lose access to certain features like streak, '
                      'community and others',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _DeleteAccountButton(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _deleteAccount(context);
                    },
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

class _DeleteAccountButton extends StatelessWidget {
  final VoidCallback onTap;

  const _DeleteAccountButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: AppTheme.screenTimerControllerPillBg,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.delete_outline_rounded,
              color: MyAccountScreen._destructiveColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Delete my account',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: MyAccountScreen._destructiveColor,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
