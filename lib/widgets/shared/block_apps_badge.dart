import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Pill badge showing how many apps are blocked for a timer session.
///
/// Displays `Block apps  No` when [blockedCount] is zero, otherwise
/// `Block N apps` (e.g. `Block 1 apps`).
class BlockAppsBadge extends StatelessWidget {
  final int blockedCount;
  final VoidCallback? onTap;

  const BlockAppsBadge({
    super.key,
    required this.blockedCount,
    this.onTap,
  });

  String get _label {
    if (blockedCount == 0) return 'Block apps  No';
    return 'Block $blockedCount apps';
  }

  @override
  Widget build(BuildContext context) {
    final hasApps = blockedCount > 0;
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF1A1A1A).withValues(alpha: 0.85),
        border: Border.all(
          color: hasApps
              ? Colors.white.withValues(alpha: 0.25)
              : const Color(0xFF2A2A2A),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.shield_outlined,
            color:
                hasApps ? Colors.white : Colors.white.withValues(alpha: 0.7),
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            _label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: hasApps ? Colors.white : const Color(0xFFAEAEB2),
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );

    return Center(
      child: onTap == null
          ? badge
          : GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: badge,
            ),
    );
  }
}
