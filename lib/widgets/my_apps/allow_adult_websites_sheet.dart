import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../shared/app_bottom_sheet.dart';
import '../shared/hold_to_confirm_button.dart';

/// Bottom sheet shown when the user tries to disable adult website blocking.
Future<bool?> showAllowAdultWebsitesSheet(BuildContext context) {
  return showAppBottomSheet<bool>(
    context: context,
    backgroundColor: const Color(0xFF1A1A1A),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => const _AllowAdultWebsitesSheet(),
  );
}

class _AllowAdultWebsitesSheet extends StatelessWidget {
  const _AllowAdultWebsitesSheet();

  static const _accent = Color(0xFFFF3B30);

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
              Icons.warning_amber_rounded,
              color: _accent,
              size: 28,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Allow adult websites?',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Are you sure you want to allow access to adult websites?',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: const Color(0xFFAEAEB2),
              height: 1.5,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 28),
          HoldToConfirmButton(
            label: 'Hold to allow',
            onComplete: () => Navigator.pop(context, true),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFAEAEB2),
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
