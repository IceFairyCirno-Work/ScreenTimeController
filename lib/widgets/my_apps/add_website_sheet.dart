import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../../utils/website_helpers.dart';
import '../shared/app_bottom_sheet.dart';

/// Prompts the user to enter a domain (e.g. `twitter.com`).
/// Returns the normalized domain, or `null` when dismissed.
Future<String?> showAddWebsiteSheet(BuildContext context) {
  return showAppBottomSheet<String>(
    context: context,
    builder: (ctx) => const _AddWebsiteSheet(),
  );
}

class _AddWebsiteSheet extends StatefulWidget {
  const _AddWebsiteSheet();

  @override
  State<_AddWebsiteSheet> createState() => _AddWebsiteSheetState();
}

class _AddWebsiteSheetState extends State<_AddWebsiteSheet> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final domain = WebsiteHelpers.normalizeDomain(_controller.text);
    if (!WebsiteHelpers.isValidDomain(domain)) {
      setState(() => _error = 'Enter a valid domain like example.com');
      return;
    }
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(domain);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 20),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Add website',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter a domain like twitter.com',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppTheme.textSecondary,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.screenTimerControllerPillBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _error != null
                    ? AppTheme.screenTimerControllerDeepFocus.withValues(alpha: 0.5)
                    : AppTheme.surfaceLight.withValues(alpha: 0.5),
              ),
            ),
            child: TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _submit(),
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
                decoration: TextDecoration.none,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'example.com',
                hintStyle: GoogleFonts.inter(
                  fontSize: 16,
                  color: AppTheme.textHint,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.screenTimerControllerDeepFocus,
                decoration: TextDecoration.none,
              ),
            ),
          ],
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _submit,
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                color: AppTheme.accent,
                borderRadius: BorderRadius.circular(27),
              ),
              child: Center(
                child: Text(
                  'Add website',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textOnAccent,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}
