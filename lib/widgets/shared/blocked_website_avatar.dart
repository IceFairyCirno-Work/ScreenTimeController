import 'package:flutter/material.dart';

import '../../utils/website_helpers.dart';

const kBlockedWebsiteAvatarSize = 48.0;
const kBlockedWebsiteAvatarRadius = 12.0;
const kBlockedWebsiteLockSize = 20.0;

/// Squared website avatar with rounded corners, domain color, and lock overlay.
class BlockedWebsiteAvatar extends StatelessWidget {
  final String domain;
  final bool isBlocked;
  final double? progress;
  final double size;

  const BlockedWebsiteAvatar({
    super.key,
    required this.domain,
    required this.isBlocked,
    this.progress,
    this.size = kBlockedWebsiteAvatarSize,
  });

  @override
  Widget build(BuildContext context) {
    final color = WebsiteHelpers.colorForDomain(domain);
    final innerRadius =
        kBlockedWebsiteAvatarRadius * (size / kBlockedWebsiteAvatarSize);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(innerRadius),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isBlocked) ...[
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(innerRadius),
              ),
            ),
            const Icon(
              Icons.lock_rounded,
              size: kBlockedWebsiteLockSize,
              color: Colors.white,
            ),
          ] else
            Icon(
              Icons.language_rounded,
              size: size * 0.42,
              color: Colors.white.withValues(alpha: 0.9),
            ),
        ],
      ),
    );
  }
}
