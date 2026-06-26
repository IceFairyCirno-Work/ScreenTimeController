import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/app_folder.dart';
import '../../models/app_rule.dart';
import '../../models/screen_time_data.dart';
import '../../providers/emergency_pass_provider.dart';
import '../../providers/folder_apps_provider.dart';
import '../../providers/rules_provider.dart';
import '../../services/screen_time_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../utils/platform_capabilities.dart';
import '../../widgets/my_apps/add_rule_sheet.dart';
import '../../widgets/my_apps/rule_detail_navigation.dart';
import '../../widgets/my_apps/rules_carousel.dart';
import '../../widgets/shared/disabled_unblock_action.dart';
import '../../widgets/shared/unblocked_app_avatar.dart';
import '../unblock_duration_screen.dart';

const _kCategories = ['Distracting', 'None'];

class BlockedAppDetailScreen extends StatefulWidget {
  final String appName;
  final String packageName;
  final Uint8List? iconBytes;
  final bool isBlocked;

  const BlockedAppDetailScreen({
    super.key,
    required this.appName,
    required this.packageName,
    this.iconBytes,
    this.isBlocked = false,
  });

  @override
  State<BlockedAppDetailScreen> createState() => _BlockedAppDetailScreenState();
}

class _BlockedAppDetailScreenState extends State<BlockedAppDetailScreen> {
  final _categoryKey = GlobalKey();
  final _screenTimeService = ScreenTimeService();
  Timer? _countdownTimer;
  BlockedAppTodayStats _todayStats = BlockedAppTodayStats.empty;
  int _statsRefreshTicks = 0;

  static const _statsRefreshInterval = 15;

  @override
  void initState() {
    super.initState();
    _loadTodayStats();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _statsRefreshTicks++;
      if (_statsRefreshTicks >= _statsRefreshInterval) {
        _statsRefreshTicks = 0;
        _loadTodayStats();
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _loadTodayStats() async {
    final stats = await _screenTimeService.fetchBlockedAppTodayStats(
      widget.packageName,
    );
    if (!mounted) return;
    setState(() => _todayStats = stats);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _handleBack() {
    Navigator.pop(context);
  }

  Future<void> _openCreateRule() async {
    final rule = await showAddRuleSheet(
      context,
      defaultApps: [
        AppRuleItem(
          packageName: widget.packageName,
          appName: widget.appName,
          iconBytes: widget.iconBytes,
        ),
      ],
      startOnSchedule: true,
    );
    if (rule == null || !mounted) return;
    await context.read<RulesProvider>().addRule(rule);
  }

  Future<void> _toggleBlockState() async {
    if (context.read<EmergencyPassProvider>().manualUnblocksDisabled) return;

    final provider = context.read<RulesProvider>();
    if (provider.isNeverAllowedPackage(widget.packageName)) return;

    final display = provider.displayForPackage(widget.packageName);
    final isHardBlocked = display?.isHardBlocked ?? false;
    final isBlocked = display?.isBlocked ?? widget.isBlocked;

    if (isHardBlocked) return;

    if (isBlocked) {
      final fixedMinutes = provider.fixedUnblockMinutesForPackage(
        widget.packageName,
      );
      if (fixedMinutes == null &&
          !provider.packageCanUnblock(widget.packageName)) {
        return;
      }
      final minutes = await showUnblockFlow(
        context,
        targetName: widget.appName,
        fixedMinutes: fixedMinutes,
      );
      if (minutes == null || !mounted) return;
      await provider.unblockPackage(
        widget.packageName,
        Duration(minutes: minutes),
      );
      if (!mounted) return;
      await _loadTodayStats();
      return;
    }

    await provider.reblockPackage(widget.packageName);
  }

  TextStyle get _sectionTitleStyle => GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppTheme.textPrimary,
    decoration: TextDecoration.none,
  );

  String _categoryFor(FolderAppsProvider folderApps) =>
      folderApps.isInFolder(AppFolderType.distracting, widget.packageName)
      ? 'Distracting'
      : 'None';

  Future<void> _showCategoryDropdown() async {
    final renderBox =
        _categoryKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final folderApps = context.read<FolderAppsProvider>();
    final currentCategory = _categoryFor(folderApps);
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    final selected = await showMenu<String>(
      context: context,
      color: AppTheme.screenTimerControllerCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height + 6,
        offset.dx + size.width,
        offset.dy + size.height + 6,
      ),
      items: [
        for (final option in _kCategories)
          PopupMenuItem<String>(
            value: option,
            child: Row(
              children: [
                _buildRadioIndicator(selected: currentCategory == option),
                const SizedBox(width: 12),
                Text(
                  option,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    if (selected == null || selected == currentCategory) return;

    if (selected == 'Distracting') {
      await folderApps.addAppToFolder(
        AppFolderType.distracting,
        packageName: widget.packageName,
        appName: widget.appName,
      );
    } else {
      await folderApps.removeAppFromFolder(
        AppFolderType.distracting,
        widget.packageName,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final folderApps = context.watch<FolderAppsProvider>();
    final emergency = context.watch<EmergencyPassProvider>();
    final category = _categoryFor(folderApps);
    final provider = context.watch<RulesProvider>();
    final isNeverAllowed = provider.isNeverAllowedPackage(widget.packageName);
    final display = emergency.overlayBlockedAppDisplay(
      provider.displayForPackage(widget.packageName),
    );
    final rulesForApp = provider.blockingRulesForApp(widget.packageName);
    final isHardBlocked = display?.isHardBlocked ?? false;
    final isBlocked =
        isNeverAllowed || (display?.isBlocked ?? widget.isBlocked);
    final now = DateTime.now();
    final progress = isBlocked ? null : display?.progressAt(now);
    final countdownLabel = emergency.manualUnblocksDisabled && emergency.activeRemaining != null
        ? EmergencyPassProvider.formatDurationLabel(emergency.activeRemaining!)
        : display?.statusLabelAt(now);
    final showUnblockBar = display != null && !isNeverAllowed;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Responsive.centeredContent(
                  context: context,
                  child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildBackButton(),
                            const SizedBox(height: 24),
                            _buildAppProfile(
                              category: category,
                              isBlocked: isBlocked,
                              progress: progress,
                              countdownLabel: countdownLabel,
                            ),
                            const SizedBox(height: 32),
                            _buildTodaySection(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      RulesCarousel(
                        showSeeAllButton: false,
                        includeTrailingCard: false,
                        titleStyle: _sectionTitleStyle,
                        packageName: widget.packageName,
                        onCreateRuleTap: rulesForApp.isEmpty
                            ? _openCreateRule
                            : null,
                        onRuleTap: (rule) =>
                            RuleDetailNavigation.openRuleDetail(context, rule),
                      ),
                    ],
                  ),
                ),
              ),
              ),
              if (showUnblockBar)
                _buildUnblockButton(
                  isBlocked: isBlocked,
                  isHardBlocked: isHardBlocked,
                  canUnblock: provider.packageCanUnblock(widget.packageName),
                  emergencyPassActive: emergency.manualUnblocksDisabled,
                ),
              if (isNeverAllowed) _buildNeverAllowedBanner(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: _handleBack,
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
    );
  }

  Widget _buildAppProfile({
    required String category,
    required bool isBlocked,
    required double? progress,
    required String? countdownLabel,
  }) {
    return Column(
      children: [
        Center(
          child: UnblockedAppAvatar(
            iconBytes: widget.iconBytes,
            isBlocked: isBlocked,
            progress: progress,
          ),
        ),
        if (!isBlocked && countdownLabel != null) ...[
          const SizedBox(height: 12),
          Text(
            countdownLabel,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
              decoration: TextDecoration.none,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            widget.appName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: GestureDetector(
            key: _categoryKey,
            onTap: _showCategoryDropdown,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    category,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    size: 22,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTodaySection() {
    if (!PlatformCapabilities.supportsRealUsageStats) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Today', style: _sectionTitleStyle),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.surfaceLight),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Per-app stats require Screen Time API on iOS. '
              'They will appear after Apple Family Controls approval.',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
                height: 1.5,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      );
    }

    final opensLabel = '${_todayStats.opens}';
    final screenTimeLabel = ScreenTimeData.formatMetricDuration(
      _todayStats.screenTime,
    );
    final unblocksLabel = '${_todayStats.unblocks}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Today', style: _sectionTitleStyle),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.surfaceLight),
            borderRadius: BorderRadius.circular(16),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Expanded(child: _buildMetricColumn(opensLabel, 'Opens')),
                _buildMetricDivider(),
                Expanded(
                  child: _buildMetricColumn(screenTimeLabel, 'Screen time'),
                ),
                _buildMetricDivider(),
                Expanded(child: _buildMetricColumn(unblocksLabel, 'Unblocks')),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricColumn(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: AppTheme.textHint,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricDivider() {
    return Container(width: 1, color: AppTheme.surfaceLight);
  }

  Widget _buildRadioIndicator({required bool selected}) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppTheme.screenTimerControllerMint : AppTheme.textHint,
          width: 2,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.screenTimerControllerMint,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildNeverAllowedBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: AppTheme.screenTimerControllerDeepFocus.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.block_rounded, size: 20, color: AppTheme.screenTimerControllerDeepFocus),
            const SizedBox(width: 8),
            Text(
              'Never allowed',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.screenTimerControllerDeepFocus,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnblockButton({
    required bool isBlocked,
    required bool isHardBlocked,
    required bool canUnblock,
    required bool emergencyPassActive,
  }) {
    if (emergencyPassActive) {
      return const DisabledUnblockAction();
    }

    // Hard blocked: app is locked by a Hard mode rule and cannot be unblocked.
    if (isHardBlocked) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: AppTheme.screenTimerControllerDeepFocus.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_rounded, size: 20, color: AppTheme.screenTimerControllerDeepFocus),
              const SizedBox(width: 8),
              Text(
                'Hard blocked',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.screenTimerControllerDeepFocus,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isBlocked && !canUnblock) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(50),
          ),
          child: Text(
            'Unblock used',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textHint,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: GestureDetector(
        onTap: _toggleBlockState,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.accent,
            borderRadius: BorderRadius.circular(50),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isBlocked ? Icons.lock_open : Icons.lock,
                size: 20,
                color: AppTheme.accentInverse,
              ),
              const SizedBox(width: 8),
              Text(
                isBlocked ? 'Unblock' : 'Relock',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentInverse,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
