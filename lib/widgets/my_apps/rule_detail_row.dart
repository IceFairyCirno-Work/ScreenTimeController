import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';

class RuleDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool compact;

  const RuleDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final labelSize = compact ? 14.0 : 15.0;
    final labelWeight = compact ? FontWeight.w400 : FontWeight.w500;
    final valueWeight = compact ? FontWeight.w500 : FontWeight.w600;
    final verticalPadding = compact ? 15.0 : 14.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: verticalPadding),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: labelSize,
                fontWeight: labelWeight,
                color: AppTheme.textSecondary,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: labelSize,
                fontWeight: valueWeight,
                color: valueColor ?? AppTheme.textPrimary,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
