import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/app_folder.dart';
import '../../providers/folder_apps_provider.dart';
import '../../providers/rules_provider.dart';
import '../../screens/home/blocked_app_detail_screen.dart';
import '../../services/app_icon_cache.dart';
import '../../theme/app_theme.dart';
import '../../widgets/my_apps/allow_adult_websites_sheet.dart';
import '../../widgets/my_apps/selected_apps_sheet.dart';
import '../../widgets/shared/app_icon.dart';

class AppFolderDetailScreen extends StatefulWidget {
  final AppFolderType folderType;

  const AppFolderDetailScreen({
    super.key,
    required this.folderType,
  });

  @override
  State<AppFolderDetailScreen> createState() => _AppFolderDetailScreenState();
}

class _AppFolderDetailScreenState extends State<AppFolderDetailScreen> {
  Map<String, Uint8List?> _iconBytesByPackage = {};
  bool _isLoadingIcons = true;
  List<String> _loadedPackageNames = const [];

  AppFolder get _folder => AppFolder.forType(widget.folderType);

  @override
  void initState() {
    super.initState();
    _loadIconsFor(
      context.read<FolderAppsProvider>().appsFor(widget.folderType),
    );
  }

  Future<void> _persistApps(List<FolderAppItem> apps) async {
    await context.read<FolderAppsProvider>().updateFolder(
          widget.folderType,
          apps,
        );
    if (!mounted) return;
    await _loadIconsFor(apps);
  }

  void _handleBack() {
    Navigator.pop(context);
  }

  Future<void> _openAllowAdultWebsitesSheet() async {
    final confirmed = await showAllowAdultWebsitesSheet(context);
    if (!mounted || confirmed != true) return;
    await context.read<FolderAppsProvider>().setAdultWebsitesBlocked(false);
  }

  Future<void> _onAdultWebsitesToggle(bool enabled) async {
    if (enabled) {
      await context.read<FolderAppsProvider>().setAdultWebsitesBlocked(true);
      return;
    }
    await _openAllowAdultWebsitesSheet();
  }

  Future<void> _openAddSheet(List<FolderAppItem> apps) async {
    final currentApps = apps.map((item) => item.toAppRuleItem()).toList();
    final updated = await showSelectedAppsSheet(
      context,
      currentApps: currentApps,
      startOnAddView: true,
      popOnAddConfirm: true,
    );
    if (updated == null || !mounted) return;

    final folderProvider = context.read<FolderAppsProvider>();
    final merged = folderProvider.mergeRuleItemsIntoFolder(
      widget.folderType,
      updated,
    );
    await _persistApps(merged);
  }

  Future<void> _openAppDetail(FolderAppItem app) async {
    HapticFeedback.lightImpact();
    final iconBytes =
        _isLoadingIcons ? null : _iconBytesByPackage[app.packageName];
    final display =
        context.read<RulesProvider>().displayForPackage(app.packageName);

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => BlockedAppDetailScreen(
          appName: app.appName,
          packageName: app.packageName,
          iconBytes: iconBytes,
          isBlocked: widget.folderType == AppFolderType.neverAllowed
              ? true
              : (display?.isBlocked ?? false),
        ),
      ),
    );
  }

  Future<void> _removeApp(
    List<FolderAppItem> apps,
    FolderAppItem item,
  ) async {
    final next = List<FolderAppItem>.from(apps)
      ..removeWhere((app) => app.packageName == item.packageName);
    await _persistApps(next);
  }

  Future<void> _loadIconsFor(List<FolderAppItem> apps) async {
    final packageNames = apps.map((item) => item.packageName).toList();
    if (_listEquals(packageNames, _loadedPackageNames) && !_isLoadingIcons) {
      return;
    }

    if (packageNames.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loadedPackageNames = const [];
        _iconBytesByPackage = {};
        _isLoadingIcons = false;
      });
      return;
    }

    setState(() => _isLoadingIcons = true);
    final icons = await AppIconCache.instance.getIcons(packageNames);
    if (!mounted) return;
    setState(() {
      _loadedPackageNames = packageNames;
      _iconBytesByPackage = icons;
      _isLoadingIcons = false;
    });
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final apps = context.watch<FolderAppsProvider>().appsFor(widget.folderType);
    if (!_listEquals(
      apps.map((item) => item.packageName).toList(),
      _loadedPackageNames,
    )) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadIconsFor(apps);
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: _buildHeader(),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildBannerCard(),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildAppList(apps),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            _handleBack();
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_back,
              size: 20,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _folder.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              decoration: TextDecoration.none,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBannerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _folder.bannerText,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: AppTheme.textPrimary,
          height: 1.45,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }

  Widget _buildAppList(List<FolderAppItem> apps) {
    final adultBlocked = context.watch<FolderAppsProvider>().adultWebsitesBlocked;

    return Column(
      children: [
        for (final app in apps) ...[
          _buildAppRow(apps, app),
          const SizedBox(height: 4),
        ],
        if (widget.folderType == AppFolderType.neverAllowed) ...[
          _buildAdultWebsitesRow(adultBlocked),
          const SizedBox(height: 4),
        ],
        _buildAddRow(apps),
      ],
    );
  }

  Widget _buildAdultWebsitesRow(bool isBlocked) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.block_rounded,
              size: 22,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Adult websites',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          SizedBox(
            height: 28,
            child: CupertinoSwitch(
              value: isBlocked,
              activeTrackColor: AppTheme.screenTimerControllerMintGlow,
              inactiveTrackColor: AppTheme.screenTimerControllerToggleInactive,
              onChanged: _onAdultWebsitesToggle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppRow(List<FolderAppItem> apps, FolderAppItem app) {
    final iconBytes =
        _isLoadingIcons ? null : _iconBytesByPackage[app.packageName];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _openAppDetail(app),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  AppIcon(
                    iconBytes: iconBytes,
                    size: 44,
                    borderRadius: 12,
                    fallbackIconColor: AppTheme.textPrimary,
                    fallbackIconSize: 20,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.appName,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatFolderAddedAt(app.addedAt),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.textSecondary,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _removeApp(apps, app);
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 18,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddRow(List<FolderAppItem> apps) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _openAddSheet(apps);
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 22,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(width: 14),
            Text(
              'Add app or website',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
