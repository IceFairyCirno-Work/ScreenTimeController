import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/app_rule.dart';
import '../../providers/emergency_pass_provider.dart';
import '../../providers/rules_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../widgets/my_apps/add_rule_sheet.dart';
import '../../widgets/my_apps/rule_detail_navigation.dart';
import '../../widgets/my_apps/rules_carousel.dart';
import '../../widgets/shared/blocked_website_avatar.dart';
import '../../widgets/shared/disabled_unblock_action.dart';
import '../unblock_duration_screen.dart';

class BlockedWebsiteDetailScreen extends StatefulWidget {
  final String domain;
  final String packageName;
  final bool isBlocked;

  const BlockedWebsiteDetailScreen({
    super.key,
    required this.domain,
    required this.packageName,
    this.isBlocked = false,
  });

  @override
  State<BlockedWebsiteDetailScreen> createState() =>
      _BlockedWebsiteDetailScreenState();
}

class _BlockedWebsiteDetailScreenState extends State<BlockedWebsiteDetailScreen> {
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

  void _handleBack() {
    Navigator.pop(context);
  }

  Future<void> _openCreateRule() async {
    final rule = await showAddRuleSheet(
      context,
      defaultApps: [
        AppRuleItem(
          packageName: widget.packageName,
          appName: widget.domain,
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
        targetName: widget.domain,
        fixedMinutes: fixedMinutes,
      );
      if (minutes == null || !mounted) return;
      await provider.unblockPackage(
        widget.packageName,
        Duration(minutes: minutes),
      );
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

  @override
  Widget build(BuildContext context) {
    final emergency = context.watch<EmergencyPassProvider>();
    final provider = context.watch<RulesProvider>();
    final display = emergency.overlayBlockedAppDisplay(
      provider.displayForPackage(widget.packageName),
    );
    final rulesForWebsite = provider.blockingRulesForApp(widget.packageName);
    final isHardBlocked = display?.isHardBlocked ?? false;
    final isBlocked = display?.isBlocked ?? widget.isBlocked;
    final now = DateTime.now();
    final progress = isBlocked ? null : display?.progressAt(now);
    final countdownLabel = emergency.manualUnblocksDisabled && emergency.activeRemaining != null
        ? EmergencyPassProvider.formatDurationLabel(emergency.activeRemaining!)
        : display?.statusLabelAt(now);
    final showUnblockBar = display != null;

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
                            _buildWebsiteProfile(
                              isBlocked: isBlocked,
                              progress: progress,
                              countdownLabel: countdownLabel,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      RulesCarousel(
                        showSeeAllButton: false,
                        includeTrailingCard: false,
                        titleStyle: _sectionTitleStyle,
                        packageName: widget.packageName,
                        onCreateRuleTap: rulesForWebsite.isEmpty
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

  Widget _buildWebsiteProfile({
    required bool isBlocked,
    required double? progress,
    required String? countdownLabel,
  }) {
    return Column(
      children: [
        Center(
          child: BlockedWebsiteAvatar(
            domain: widget.domain,
            isBlocked: isBlocked,
            progress: progress,
            size: 72,
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
            widget.domain,
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
      ],
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
