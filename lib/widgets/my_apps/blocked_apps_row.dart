import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/app_rule.dart';
import '../../providers/emergency_pass_provider.dart';
import '../../providers/rules_provider.dart';
import '../../screens/home/blocked_app_detail_screen.dart';
import '../../services/app_icon_cache.dart';
import '../../theme/app_theme.dart';
import '../shared/unblocked_app_avatar.dart';

/// Matches [_BlockedAppIcon] column: avatar, labels, and status line.
const _kBlockedAppsContentHeight =
    kUnblockedAppOuterSize + 8 + 14 + 2 + 14;

class BlockedAppsRow extends StatefulWidget {
  const BlockedAppsRow({super.key});

  @override
  State<BlockedAppsRow> createState() => _BlockedAppsRowState();
}

class _BlockedAppsRowState extends State<BlockedAppsRow> {
  Map<String, Uint8List?> _iconBytesByPackage = {};
  bool _isLoading = false;
  List<String> _loadedPackageNames = const [];
  List<String>? _pendingPackageNames;
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

  Future<void> _loadIcons(List<String> packageNames) async {
    if (packageNames.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loadedPackageNames = const [];
        _pendingPackageNames = null;
        _iconBytesByPackage = {};
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    final icons = await AppIconCache.instance.getIcons(packageNames);
    if (!mounted) return;
    if (!listEquals(packageNames, _pendingPackageNames)) return;
    setState(() {
      _loadedPackageNames = packageNames;
      _pendingPackageNames = null;
      _iconBytesByPackage = icons;
      _isLoading = false;
    });
  }

  void _scheduleIconLoad(List<BlockedAppDisplay> displays) {
    final packageNames = displays.map((d) => d.app.packageName).toList();
    if (listEquals(_loadedPackageNames, packageNames) ||
        listEquals(_pendingPackageNames, packageNames)) {
      return;
    }
    _pendingPackageNames = packageNames;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadIcons(packageNames);
    });
  }

  Future<void> _openAppDetail(BlockedAppDisplay display) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => BlockedAppDetailScreen(
          appName: display.app.appName,
          packageName: display.app.packageName,
          iconBytes: _isLoading
              ? null
              : _iconBytesByPackage[display.app.packageName],
          isBlocked: display.isBlocked,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final emergency = context.watch<EmergencyPassProvider>();
    final displays = emergency.overlayBlockedAppDisplays(
      context.watch<RulesProvider>().blockedAppsDisplay(),
    );
    _scheduleIconLoad(displays);
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Icon(
                Icons.lock_outline,
                size: 20,
                color: AppTheme.textPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                'Blocked apps',
                style: AppTheme.sectionTitle,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (displays.isEmpty)
          SizedBox(
            width: double.infinity,
            height: _kBlockedAppsContentHeight,
            child: Center(
              child: Text(
                'No apps blocked right now',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textHint,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                for (var i = 0; i < displays.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  _BlockedAppIcon(
                    appName: displays[i].app.appName,
                    iconBytes: _isLoading
                        ? null
                        : _iconBytesByPackage[displays[i].app.packageName],
                    isBlocked: displays[i].isBlocked,
                    progress: displays[i].isBlocked
                        ? null
                        : displays[i].progressAt(now),
                    statusLabel: emergency.isActive
                        ? EmergencyPassProvider.formatDurationLabel(
                            emergency.activeRemaining ?? Duration.zero,
                          )
                        : displays[i].statusLabelAt(now),
                    onTap: () => _openAppDetail(displays[i]),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _BlockedAppIcon extends StatelessWidget {
  final String appName;
  final Uint8List? iconBytes;
  final bool isBlocked;
  final double? progress;
  final String statusLabel;
  final VoidCallback onTap;

  const _BlockedAppIcon({
    required this.appName,
    this.iconBytes,
    required this.isBlocked,
    this.progress,
    required this.statusLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          UnblockedAppAvatar(
            iconBytes: iconBytes,
            isBlocked: isBlocked,
            progress: progress,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: kUnblockedAppOuterSize,
            child: Text(
              appName,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
                decoration: TextDecoration.none,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            width: kUnblockedAppOuterSize,
            child: Text(
              statusLabel,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isBlocked
                    ? AppTheme.screenTimerControllerMint
                    : AppTheme.textSecondary,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
