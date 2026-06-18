import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/app_rule.dart';
import '../../providers/rules_provider.dart';
import '../../screens/home/blocked_website_detail_screen.dart';
import '../../theme/app_theme.dart';
import '../../utils/website_helpers.dart';
import '../shared/blocked_website_avatar.dart';

class BlockedWebsitesRow extends StatefulWidget {
  const BlockedWebsitesRow({super.key});

  @override
  State<BlockedWebsitesRow> createState() => _BlockedWebsitesRowState();
}

class _BlockedWebsitesRowState extends State<BlockedWebsitesRow> {
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _openWebsiteDetail(BlockedAppDisplay display) async {
    final domain = WebsiteHelpers.domainFromPackage(display.app.packageName);
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => BlockedWebsiteDetailScreen(
          domain: domain,
          packageName: display.app.packageName,
          isBlocked: display.isBlocked,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displays = context.watch<RulesProvider>().blockedWebsitesDisplay();
    if (displays.isEmpty) return const SizedBox.shrink();

    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Icon(
                Icons.language_rounded,
                size: 20,
                color: AppTheme.textPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                'Blocked websites',
                style: AppTheme.sectionTitle,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < displays.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _BlockedWebsiteRow(
            display: displays[i],
            now: now,
            onTap: () => _openWebsiteDetail(displays[i]),
          ),
        ],
        const SizedBox(height: 48),
      ],
    );
  }
}

class _BlockedWebsiteRow extends StatelessWidget {
  final BlockedAppDisplay display;
  final DateTime now;
  final VoidCallback onTap;

  const _BlockedWebsiteRow({
    required this.display,
    required this.now,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final domain = WebsiteHelpers.domainFromPackage(display.app.packageName);
    final isBlocked = display.isBlocked;
    final progress = isBlocked ? null : display.progressAt(now);
    final statusLabel = display.statusLabelAt(now);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            BlockedWebsiteAvatar(
              domain: domain,
              isBlocked: isBlocked,
              progress: progress,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    domain,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      decoration: TextDecoration.none,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    statusLabel,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isBlocked ? AppTheme.screenTimerControllerMint : AppTheme.textSecondary,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: AppTheme.textHint,
            ),
          ],
        ),
      ),
    );
  }
}
