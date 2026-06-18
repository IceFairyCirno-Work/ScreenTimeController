import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/app_rule.dart';
import '../../models/screen_time_data.dart';
import '../../services/app_icon_cache.dart';
import '../../services/installed_apps_cache.dart';
import '../../theme/app_theme.dart';
import '../../utils/platform_capabilities.dart';
import '../../utils/website_helpers.dart';
import '../shared/app_bottom_sheet.dart';
import '../shared/app_icon.dart';
import '../shared/blocked_website_avatar.dart';
import 'add_website_sheet.dart';

/// Mode shown by the segmented control on the "Selected" view.
enum _SelectMode { block, allowOnly }

/// Tab shown on the "Add" view.
enum _AddTab { apps, websites }

/// Public entry point — shows the selected-apps management sheet.
///
/// Opens as a stacked dark bottom sheet that visually cross-dissolves between
/// the "Selected apps & websites" list and the "Add apps & websites" picker.
/// Returns the updated app list when the user taps "Done", or `null` when
/// dismissed without changes.
Future<List<AppRuleItem>?> showSelectedAppsSheet(
  BuildContext context, {
  required List<AppRuleItem> currentApps,
  bool startOnAddView = false,
  bool popOnAddConfirm = false,
}) {
  return showAppBottomSheet<List<AppRuleItem>>(
    context: context,
    builder: (ctx) => _SelectedAppsSheet(
      initialApps: currentApps,
      initialScreen:
          startOnAddView ? _SheetScreen.add : _SheetScreen.selected,
      popOnAddConfirm: popOnAddConfirm,
    ),
  );
}

// ─────────────────────────── Root Sheet ───────────────────────────

enum _SheetScreen { selected, add }

class _SelectedAppsSheet extends StatefulWidget {
  final List<AppRuleItem> initialApps;
  final _SheetScreen initialScreen;
  final bool popOnAddConfirm;

  const _SelectedAppsSheet({
    required this.initialApps,
    this.initialScreen = _SheetScreen.selected,
    this.popOnAddConfirm = false,
  });

  @override
  State<_SelectedAppsSheet> createState() => _SelectedAppsSheetState();
}

class _SelectedAppsSheetState extends State<_SelectedAppsSheet> {
  late _SheetScreen _screen;
  late List<AppRuleItem> _apps;

  @override
  void initState() {
    super.initState();
    _screen = widget.initialScreen;
    _apps = List.from(widget.initialApps);
    if (PlatformCapabilities.supportsInstalledAppPicker) {
      InstalledAppsCache.instance.preload();
    }
  }

  void _goTo(_SheetScreen next) {
    if (next == _screen) return;
    HapticFeedback.selectionClick();
    setState(() => _screen = next);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The body cross-dissolves; the container stays put.
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    fit: StackFit.expand,
                    alignment: Alignment.topCenter,
                    children: <Widget>[
                      ...previousChildren,
                      ?currentChild,
                    ],
                  );
                },
                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: _buildScreen(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScreen() {
    switch (_screen) {
      case _SheetScreen.selected:
        return _SelectedView(
          key: const ValueKey('selected'),
          apps: _apps,
          onAdd: () => _goTo(_SheetScreen.add),
          onRemove: (item) {
            HapticFeedback.lightImpact();
            setState(() => _apps.removeWhere(
                (a) => a.packageName == item.packageName));
          },
          onDone: () => Navigator.of(context).pop(_apps),
        );
      case _SheetScreen.add:
        final openingApps = List<AppRuleItem>.from(_apps);
        final openingPackages =
            openingApps.map((a) => a.packageName).toSet();
        return _AddAppsView(
          key: const ValueKey('add'),
          initialSelectedApps: openingApps,
          onBack: widget.popOnAddConfirm
              ? () => Navigator.of(context).pop()
              : () => _goTo(_SheetScreen.selected),
          onConfirm: (chosenApps) {
            setState(() {
              final retained = _apps
                  .where((a) => !openingPackages.contains(a.packageName));
              _apps = [...retained, ...chosenApps];
            });
            if (widget.popOnAddConfirm) {
              Navigator.of(context).pop(_apps);
            } else {
              _goTo(_SheetScreen.selected);
            }
          },
        );
    }
  }
}

// ───────────────────────── Shared header ─────────────────────────

Widget _buildDragHandle() {
  return Center(
    child: Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

Widget _buildCircleButton({
  required IconData icon,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: () {
      HapticFeedback.lightImpact();
      onTap();
    },
    behavior: HitTestBehavior.opaque,
    child: Container(
      width: 38,
      height: 38,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 18, color: AppTheme.textPrimary),
    ),
  );
}

/// Full-width capsule segmented control. [selectedIndex] is the index of the
/// highlighted segment; tapping an unselected segment invokes [onChanged].
Widget _buildSegmentedControl({
  required List<String> labels,
  required int selectedIndex,
  required ValueChanged<int> onChanged,
}) {
  return Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: AppTheme.screenTimerControllerPillBg,
      borderRadius: BorderRadius.circular(28),
    ),
    child: Row(
      children: List.generate(labels.length, (i) {
        final selected = i == selectedIndex;
        return Expanded(
          child: GestureDetector(
            onTap: selected ? null : () => onChanged(i),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.surfaceLight
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (selected) ...[
                    const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: AppTheme.textPrimary,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    labels[i],
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    ),
  );
}

// ──────────────────────── "Selected" view ────────────────────────

class _SelectedView extends StatefulWidget {
  final List<AppRuleItem> apps;
  final VoidCallback onAdd;
  final ValueChanged<AppRuleItem> onRemove;
  final VoidCallback onDone;

  const _SelectedView({
    super.key,
    required this.apps,
    required this.onAdd,
    required this.onRemove,
    required this.onDone,
  });

  @override
  State<_SelectedView> createState() => _SelectedViewState();
}

class _SelectedViewState extends State<_SelectedView> {
  _SelectMode _mode = _SelectMode.block;
  final Map<String, Uint8List?> _iconCache = {};
  final Map<String, Duration> _usageByPackage = {};

  @override
  void initState() {
    super.initState();
    _loadIconsAndUsage();
  }

  Future<void> _loadIconsAndUsage() async {
    final packages = widget.apps
        .map((a) => a.packageName)
        .where((pkg) => !WebsiteHelpers.isWebsitePackage(pkg))
        .toList();
    if (packages.isEmpty) return;
    final results = await Future.wait([
      AppIconCache.instance.getIcons(packages),
      InstalledAppsCache.instance.getApps(),
    ]);
    if (!mounted) return;
    final icons = results[0] as Map<String, Uint8List?>;
    final allApps = results[1] as List<AppUsageItem>;
    final usageMap = {
      for (final app in allApps) app.packageName: app.usage,
    };
    setState(() {
      _iconCache.addAll(icons);
      _usageByPackage.addAll(usageMap);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      primary: true,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDragHandle(),
          const SizedBox(height: 14),
          _buildHeader(),
          const SizedBox(height: 24),
          _buildSegmentedControl(
            labels: ['Block', 'Allow only'],
            selectedIndex: _mode.index,
            onChanged: (i) => setState(
                () => _mode = _SelectMode.values[i]),
          ),
          const SizedBox(height: 24),
          _buildListCard(),
          const SizedBox(height: 24),
          _buildDoneButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        _buildCircleButton(
          icon: Icons.arrow_back_rounded,
          onTap: () => Navigator.of(context).pop(),
        ),
        const Expanded(
          child: Center(
            child: Text(
              'Selected apps & websites',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
        // Balance the back button so the title stays centered.
        const SizedBox(width: 38),
      ],
    );
  }

  Widget _buildListCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.screenTimerControllerRuleCardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          for (int i = 0; i < widget.apps.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: AppTheme.surfaceLight.withValues(alpha: 0.4),
              ),
            _buildAppRow(widget.apps[i]),
          ],
          if (widget.apps.isNotEmpty)
            Divider(
              height: 1,
              thickness: 1,
              color: AppTheme.surfaceLight.withValues(alpha: 0.4),
            ),
          _buildAddAppRow(),
        ],
      ),
    );
  }

  Widget _buildAppRow(AppRuleItem item) {
    if (WebsiteHelpers.isWebsitePackage(item.packageName)) {
      final domain = WebsiteHelpers.domainFromPackage(item.packageName);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            BlockedWebsiteAvatar(
              domain: domain,
              isBlocked: true,
              size: 40,
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
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Website',
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
            GestureDetector(
              onTap: () => widget.onRemove(item),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: AppTheme.surfaceLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final icon = _iconCache[item.packageName];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          AppIcon(
            iconBytes: icon,
            size: 40,
            borderRadius: 12,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.appName,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatUsageLabel(
                      _usageByPackage[item.packageName] ?? Duration.zero),
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
          GestureDetector(
            onTap: () => widget.onRemove(item),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: AppTheme.surfaceLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 16,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddAppRow() {
    return GestureDetector(
      onTap: widget.onAdd,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 22,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 14),
            Text(
              'Add app',
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

  Widget _buildDoneButton() {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          widget.onDone();
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: AppTheme.accent,
            borderRadius: BorderRadius.circular(27),
          ),
          child: Center(
            child: Text(
              'Done',
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
    );
  }
}

// ───────────────────────── "Add" view ─────────────────────────

class _AddAppsView extends StatefulWidget {
  final List<AppRuleItem> initialSelectedApps;
  final VoidCallback onBack;
  final ValueChanged<List<AppRuleItem>> onConfirm;

  const _AddAppsView({
    super.key,
    required this.initialSelectedApps,
    required this.onBack,
    required this.onConfirm,
  });

  @override
  State<_AddAppsView> createState() => _AddAppsViewState();
}

class _AddAppsViewState extends State<_AddAppsView> {
  _AddTab _tab = _AddTab.apps;
  List<AppUsageItem> _allApps = const [];
  final Set<String> _picked = {};
  final Set<String> _pickedWebsites = {};
  // Icons for picked apps, supplied by each row as it is toggled on.
  final Map<String, Uint8List?> _pickedIcons = {};
  bool _loading = true;
  String _query = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    for (final app in widget.initialSelectedApps) {
      if (WebsiteHelpers.isWebsitePackage(app.packageName)) {
        _pickedWebsites.add(
          WebsiteHelpers.domainFromPackage(app.packageName),
        );
        continue;
      }
      _picked.add(app.packageName);
      if (app.iconBytes != null) {
        _pickedIcons[app.packageName] = app.iconBytes;
      }
    }
    if (PlatformCapabilities.supportsInstalledAppPicker) {
      _loadApps();
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadApps() async {
    final apps = await InstalledAppsCache.instance.getApps();
    if (!mounted) return;
    setState(() {
      _allApps = apps;
      for (final app in apps) {
        if (_picked.contains(app.packageName)) {
          _pickedIcons[app.packageName] ??= app.iconBytes;
        }
      }
      _loading = false;
    });
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  void _togglePick(AppUsageItem app, Uint8List? icon) {
    final pkg = app.packageName;
    HapticFeedback.selectionClick();
    setState(() {
      if (_picked.contains(pkg)) {
        _picked.remove(pkg);
        _pickedIcons.remove(pkg);
      } else {
        _picked.add(pkg);
        _pickedIcons[pkg] = icon;
      }
    });
  }

  List<AppUsageItem> get _filteredApps {
    if (_query.isEmpty) return _allApps;
    final q = _query.toLowerCase();
    return _allApps
        .where((a) =>
            a.appName.toLowerCase().contains(q) ||
            a.packageName.toLowerCase().contains(q))
        .toList();
  }

  int get _totalSelected => _picked.length + _pickedWebsites.length;

  void _confirm() {
    final chosenApps = _allApps
        .where((a) => _picked.contains(a.packageName))
        .map((a) => AppRuleItem(
              packageName: a.packageName,
              appName: a.appName,
              iconBytes: _pickedIcons[a.packageName],
            ))
        .toList();
    final chosenWebsites = _pickedWebsites
        .map(
          (domain) => AppRuleItem(
            packageName: WebsiteHelpers.packageForDomain(domain),
            appName: domain,
          ),
        )
        .toList();
    widget.onConfirm([...chosenApps, ...chosenWebsites]);
  }

  Future<void> _addWebsiteManually() async {
    final domain = await showAddWebsiteSheet(context);
    if (domain == null || !mounted) return;
    if (_pickedWebsites.contains(domain)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$domain is already selected'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    HapticFeedback.lightImpact();
    setState(() => _pickedWebsites.add(domain));
  }

  void _removeWebsite(String domain) {
    HapticFeedback.lightImpact();
    setState(() => _pickedWebsites.remove(domain));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDragHandle(),
              const SizedBox(height: 14),
              _buildHeader(),
              const SizedBox(height: 24),
              _buildSegmentedControl(
                labels: ['Apps', 'Websites'],
                selectedIndex: _tab.index,
                onChanged: (i) =>
                    setState(() => _tab = _AddTab.values[i]),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
        Expanded(child: _buildBody()),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: _buildConfirmButton(),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        _buildCircleButton(
          icon: Icons.arrow_back_rounded,
          onTap: widget.onBack,
        ),
        const Expanded(
          child: Center(
            child: Text(
              'Add apps & websites',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 38),
      ],
    );
  }

  Widget _buildBody() {
    switch (_tab) {
      case _AddTab.apps:
        return _buildAppsBody();
      case _AddTab.websites:
        return _buildWebsitesBody();
    }
  }

  // ─────────── Apps tab: search + checkbox list ───────────

  Widget _buildAppsBody() {
    if (!PlatformCapabilities.supportsInstalledAppPicker) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.hourglass_top_outlined,
                size: 40,
                color: AppTheme.textHint.withValues(alpha: 0.8),
              ),
              const SizedBox(height: 16),
              Text(
                'App selection requires Screen Time API',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Coming after Apple Family Controls approval. '
                'You can still add websites from the Websites tab.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textSecondary,
                  height: 1.45,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppTheme.screenTimerControllerMint,
          strokeWidth: 2.5,
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildSearchBar(),
        ),
        const SizedBox(height: 14),
        Expanded(child: _buildAppsList()),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.screenTimerControllerPillBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppTheme.surfaceLight.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
                decoration: TextDecoration.none,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 14),
                hintText: 'Search',
                hintStyle: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textHint,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
          const Icon(
            Icons.search_rounded,
            size: 20,
            color: AppTheme.textPrimary,
          ),
        ],
      ),
    );
  }

  Widget _buildAppsList() {
    final apps = _filteredApps;
    if (apps.isEmpty) {
      return Center(
        child: Text(
          'No apps found',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
            decoration: TextDecoration.none,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.screenTimerControllerRuleCardBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: ListView.separated(
          primary: true,
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          itemCount: apps.length,
          separatorBuilder: (_, _) => Divider(
            height: 1,
            thickness: 1,
            color: AppTheme.surfaceLight.withValues(alpha: 0.3),
          ),
          itemBuilder: (_, i) => _AppCheckRow(
            key: ValueKey(apps[i].packageName),
            app: apps[i],
            picked: _picked.contains(apps[i].packageName),
            onToggle: _togglePick,
          ),
        ),
      ),
    );
  }

  // ─────────── Websites tab: manual add ───────────

  Widget _buildWebsitesBody() {
    final websites = _pickedWebsites.toList()..sort();
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.screenTimerControllerRuleCardBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            for (var i = 0; i < websites.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: AppTheme.surfaceLight.withValues(alpha: 0.3),
                ),
              _buildWebsitePickRow(websites[i]),
            ],
            if (websites.isNotEmpty)
              Divider(
                height: 1,
                thickness: 1,
                color: AppTheme.surfaceLight.withValues(alpha: 0.3),
              ),
            GestureDetector(
              onTap: _addWebsiteManually,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        size: 22,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'Add manually',
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebsitePickRow(String domain) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          BlockedWebsiteAvatar(
            domain: domain,
            isBlocked: true,
            size: 40,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              domain,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _removeWebsite(domain),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: AppTheme.surfaceLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 16,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────── Confirm button ───────────

  Widget _buildConfirmButton() {
    final count = _totalSelected;
    final label = count == 0
        ? 'Save'
        : 'Add $count item${count == 1 ? '' : 's'}';
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          _confirm();
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: AppTheme.accent,
            borderRadius: BorderRadius.circular(27),
          ),
          child: Center(
            child: Text(
              label,
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
    );
  }
}

// ───────────────────── App check row (self-contained) ─────────────────────

String _formatUsageLabel(Duration usage) {
  if (usage.inMinutes < 1) return 'Less than 1m today';
  final h = usage.inHours;
  final m = usage.inMinutes.remainder(60);
  if (h > 0) return '${h}h ${m}m today';
  return '${m}m today';
}

Widget _buildCheckboxWidget(bool checked) {
  return AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    width: 26,
    height: 26,
    decoration: BoxDecoration(
      color: checked ? AppTheme.accent : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: checked ? AppTheme.accent : AppTheme.surfaceLight,
        width: 2,
      ),
    ),
    child: checked
        ? const Icon(
            Icons.check_rounded,
            size: 18,
            color: AppTheme.textOnAccent,
          )
        : null,
  );
}

/// A single app row in the "Add apps" list.
///
/// Stateless: the icon is bundled inside [AppUsageItem] (fetched in a single
/// native batch call), so there is no per-row async loading. A `ValueKey`
/// based on the package name is supplied by the caller so that the list never
/// reuses a row's identity for a different app during search filtering.
class _AppCheckRow extends StatelessWidget {
  final AppUsageItem app;
  final bool picked;
  final void Function(AppUsageItem app, Uint8List? icon) onToggle;

  const _AppCheckRow({
    super.key,
    required this.app,
    required this.picked,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onToggle(app, app.iconBytes),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            AppIcon(
              iconBytes: app.iconBytes,
              size: 40,
              borderRadius: 12,
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
                    _formatUsageLabel(app.usage),
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
            _buildCheckboxWidget(picked),
          ],
        ),
      ),
    );
  }
}
