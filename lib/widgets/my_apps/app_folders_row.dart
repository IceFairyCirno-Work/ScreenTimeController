import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/app_folder.dart';
import '../../providers/folder_apps_provider.dart';
import '../../services/app_icon_cache.dart';
import '../../theme/app_theme.dart';
import '../shared/app_icon.dart';

const _kRulesCardWidth = 200.0;
const _kFolderCardSize = _kRulesCardWidth * 0.75;
const _kFolderScale = _kFolderCardSize / 96.0;
const _kFolderPadding = 10.0 * _kFolderScale;
const _kFolderIconSize = 34.0 * _kFolderScale;
const _kFolderGridSpacing = 5.0 * _kFolderScale;
const _kFolderBorderRadius = 22.0 * _kFolderScale;
const _kFolderIconBorderRadius = 7.0 * _kFolderScale;

class AppFoldersRow extends StatefulWidget {
  final ValueChanged<AppFolderType> onFolderTap;

  const AppFoldersRow({
    super.key,
    required this.onFolderTap,
  });

  @override
  State<AppFoldersRow> createState() => _AppFoldersRowState();
}

class _AppFoldersRowState extends State<AppFoldersRow> {
  Map<String, Uint8List?> _iconBytesByPackage = {};
  List<String> _loadedPackageNames = const [];
  List<String>? _pendingPackageNames;

  Future<void> _loadIcons(List<String> packageNames) async {
    if (packageNames.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loadedPackageNames = const [];
        _pendingPackageNames = null;
        _iconBytesByPackage = {};
      });
      return;
    }

    final icons = await AppIconCache.instance.getIcons(packageNames);
    if (!mounted) return;
    if (!listEquals(packageNames, _pendingPackageNames)) return;

    setState(() {
      _loadedPackageNames = packageNames;
      _pendingPackageNames = null;
      _iconBytesByPackage
        ..removeWhere((pkg, _) => !packageNames.contains(pkg))
        ..addAll(icons);
    });
  }

  void _scheduleIconLoad(Map<AppFolderType, List<FolderAppItem>> folderApps) {
    final packageNames = AppFolder.all
        .expand((folder) => folderApps[folder.type] ?? const <FolderAppItem>[])
        .map((item) => item.packageName)
        .toSet()
        .toList()
      ..sort();

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

  List<String> _coverPackageNames(List<FolderAppItem> apps) {
    final sorted = List<FolderAppItem>.from(apps)
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return sorted.map((item) => item.packageName).toList();
  }

  @override
  Widget build(BuildContext context) {
    final folderApps = context.watch<FolderAppsProvider>().folderApps;
    _scheduleIconLoad(folderApps);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Apps',
            style: AppTheme.sectionTitle,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: _kFolderCardSize + 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: AppFolder.all.length,
            separatorBuilder: (_, _) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final folder = AppFolder.all[index];
              final apps = folderApps[folder.type] ?? const [];
              return _FolderCard(
                title: folder.title,
                subtitle: folder.subtitleFor(apps.length),
                packageNames: _coverPackageNames(apps),
                showEye: folder.showEye,
                iconBytesByPackage: _iconBytesByPackage,
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onFolderTap(folder.type);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FolderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> packageNames;
  final bool showEye;
  final Map<String, Uint8List?> iconBytesByPackage;
  final VoidCallback onTap;

  const _FolderCard({
    required this.title,
    required this.subtitle,
    required this.packageNames,
    required this.onTap,
    this.showEye = false,
    this.iconBytesByPackage = const {},
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: _kFolderCardSize,
            height: _kFolderCardSize,
            padding: EdgeInsets.all(_kFolderPadding),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(_kFolderBorderRadius),
            ),
            child: showEye
                ? Center(
                    child: Icon(
                      Icons.visibility_off_outlined,
                      size: 28 * _kFolderScale,
                      color: AppTheme.textHint,
                    ),
                  )
                : _buildGrid(),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              decoration: TextDecoration.none,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 1),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: AppTheme.textHint,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGrid() {
    final count = packageNames.length;
    final int overflowCount;
    final List<String> visiblePackages;

    if (count > 4) {
      visiblePackages = packageNames.take(3).toList();
      overflowCount = count - 3;
    } else {
      visiblePackages = packageNames.take(4).toList();
      overflowCount = 0;
    }

    final cells = <Widget>[
      for (final packageName in visiblePackages)
        AppIcon(
          iconBytes: iconBytesByPackage[packageName],
          size: _kFolderIconSize,
          borderRadius: _kFolderIconBorderRadius,
          fallbackIconColor: AppTheme.textPrimary,
          fallbackIconSize: 12 * _kFolderScale,
        ),
    ];

    if (overflowCount > 0) {
      cells.add(
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(_kFolderIconBorderRadius),
          ),
          child: Center(
            child: Text(
              '+$overflowCount',
              style: GoogleFonts.inter(
                fontSize: 9 * _kFolderScale,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      );
    }

    while (cells.length < 4) {
      cells.add(
        Container(
          decoration: BoxDecoration(
            color: AppTheme.screenTimerControllerCard,
            borderRadius: BorderRadius.circular(_kFolderIconBorderRadius),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: _kFolderGridSpacing,
      crossAxisSpacing: _kFolderGridSpacing,
      physics: const NeverScrollableScrollPhysics(),
      children: cells.take(4).toList(),
    );
  }
}
