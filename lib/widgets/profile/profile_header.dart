import 'package:flutter/material.dart';

import '../shared/circle_icon_button.dart';

/// Fixed header for the profile screen.
///
///  - Left: circular button with a left-pointing navigation arrow (←).
///  - Right: circular button with a settings gear icon (⚙).
///
/// The animated mini avatar that appears between the buttons on scroll is
/// rendered as a separate overlay by [ProfileScreen] so it can morph from the
/// large avatar instead of crossfading two separate widgets.
class ProfileHeader extends StatelessWidget {
  final VoidCallback onBackTap;
  final VoidCallback onSettingsTap;

  const ProfileHeader({
    super.key,
    required this.onBackTap,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 6,
        16,
        10,
      ),
      child: Row(
        children: [
          // ── Left: back arrow ──
          CircleIconButton(
            icon: Icons.arrow_back,
            onTap: onBackTap,
          ),
          // Spacer so the right button sits at the trailing edge. The center
          // is intentionally left empty — the morphing avatar overlay floats
          // above this row.
          const Spacer(),
          // ── Right: settings gear ──
          CircleIconButton(
            icon: Icons.settings,
            onTap: onSettingsTap,
          ),
        ],
      ),
    );
  }
}
