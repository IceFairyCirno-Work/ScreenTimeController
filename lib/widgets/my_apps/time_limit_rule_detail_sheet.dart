import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/app_rule.dart';
import '../../providers/emergency_pass_provider.dart';
import '../../providers/rules_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/duration_formatters.dart';
import '../../utils/time_limit_formatter.dart';
import '../../utils/website_helpers.dart';
import 'rule_detail_row.dart';
import '../shared/app_bottom_sheet.dart';
import '../shared/disabled_unblock_action.dart';

enum TimeLimitDetailAction {
  cancelled,
  toggleRequested,
  editRequested,
  disableRequested,
  reenableRequested,
}

Future<TimeLimitDetailAction> showTimeLimitRuleDetailSheet(
  BuildContext context,
  TimeLimitRule rule, {
  DateTime Function()? now,
}) {
  return showAppBottomSheet<TimeLimitDetailAction>(
    context: context,
    builder: (ctx) => _TimeLimitRuleDetailSheet(rule: rule, now: now),
  ).then((action) => action ?? TimeLimitDetailAction.cancelled);
}

class _TimeLimitRuleDetailSheet extends StatelessWidget {
  final TimeLimitRule rule;
  final DateTime Function() now;

  const _TimeLimitRuleDetailSheet({
    required this.rule,
    DateTime Function()? now,
  }) : now = now ?? _defaultNow;

  static DateTime _defaultNow() => DateTime.now();

  bool get _isRuleActive => rule.isRuleActive(now());

  bool _showUnblockAll(BuildContext context) {
    if (!_isRuleActive) return false;
    return context.read<RulesProvider>().timeLimitRuleHasUnblockableApps(
          rule,
          now(),
        );
  }

  bool _isCurrentlyUnblocked() {
    final moment = now();
    return rule.apps.any(
      (a) => rule.isPackageTemporarilyUnblocked(a.packageName, moment),
    );
  }

  String _statusBadge() {
    final moment = now();
    if (rule.isCurrentlyDisabled(moment)) {
      if (rule.isIndefinitelyDisabled()) return 'Disabled';
      final remaining = rule.disabledUntil!.difference(moment);
      if (remaining.inHours >= 1) {
        return 'Resumes in ${formatDurationSingleUnit(remaining)}';
      }
      return 'Resumes soon';
    }
    if (!rule.isEnabled) return 'Paused';
    if (rule.isRuleActive(moment)) {
      if (rule.apps.isEmpty) return 'No apps selected';
      return 'Monitoring';
    }
    final untilActive = rule.nextActiveAfter(moment).difference(moment);
    return 'Starts in ${formatDurationSingleUnit(untilActive)}';
  }

  String _countdownLabel() => _statusBadge();

  @override
  Widget build(BuildContext context) {
    final active = _isRuleActive;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
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
            _buildHeader(context),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  children: [
                    const SizedBox(height: 28),
                    _buildFlowBadge(active),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        rule.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      WebsiteHelpers.ruleTargetsBlockLabel(rule.apps),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(19),
                      ),
                      child: Text(
                        _countdownLabel(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildConfigDetails(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
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
          ),
        ],
      ),
    );
  }

  Widget _buildFlowBadge(bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: active
              ? AppTheme.screenTimerControllerMint.withValues(alpha: 0.25)
              : AppTheme.cardBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.hourglass_bottom_rounded,
            size: 18,
            color: active ? AppTheme.screenTimerControllerMint : AppTheme.textSecondary,
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward, size: 18, color: AppTheme.textHint),
          const SizedBox(width: 8),
          Icon(
            Icons.shield_outlined,
            size: 18,
            color: active ? AppTheme.screenTimerControllerMint : AppTheme.textHint,
          ),
        ],
      ),
    );
  }

  Widget _buildConfigDetails() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.screenTimerControllerRuleCardBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            RuleDetailRow(
              label: 'Daily limit',
              value: TimeLimitFormatter.formatDurationShort(rule.allowedTime),
            ),
            _divider(),
            RuleDetailRow(
              label: 'Block until',
              value: TimeLimitFormatter.formatBlockUntilLabel(rule.blockUntil),
            ),
            _divider(),
            RuleDetailRow(label: 'On these days', value: rule.repeatLabel),
            _divider(),
            RuleDetailRow(
              label: 'Hard mode',
              value: rule.isHardMode ? 'On' : 'Off',
              valueColor:
                  rule.isHardMode ? AppTheme.screenTimerControllerDeepFocus : AppTheme.screenTimerControllerMint,
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 0.5,
        color: AppTheme.cardBorder.withValues(alpha: 0.6),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final emergency = context.watch<EmergencyPassProvider>();
    final disabled = rule.isCurrentlyDisabled(now());
    final unblocked = _isCurrentlyUnblocked();
    final showUnblockAll = _showUnblockAll(context);

    if (disabled && rule.isIndefinitelyDisabled()) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: _accentButton(
          label: 'Re-enable rule',
          onTap: () {
            HapticFeedback.mediumImpact();
            Navigator.of(context)
                .pop(TimeLimitDetailAction.reenableRequested);
          },
        ),
      );
    }

    if (showUnblockAll) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UnblockAccentButton(
              label: 'Unblock all apps',
              enabled: !emergency.manualUnblocksDisabled,
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.of(context)
                    .pop(TimeLimitDetailAction.toggleRequested);
              },
            ),
            const SizedBox(height: 14),
            _textLink(
              label: 'Edit rule',
              icon: Icons.edit_rounded,
              iconSize: 15,
              fontSize: 14,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.of(context)
                    .pop(TimeLimitDetailAction.editRequested);
              },
            ),
          ],
        ),
      );
    }

    if (unblocked && _isRuleActive) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: _prominentEditLink(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop(TimeLimitDetailAction.editRequested);
          },
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        children: [
          _accentButton(
            label: 'Edit rule',
            icon: Icons.edit_rounded,
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.of(context).pop(TimeLimitDetailAction.editRequested);
            },
          ),
          const SizedBox(height: 14),
          _textLink(
            label: 'Disable rule',
            color: AppTheme.screenTimerControllerDeepFocus,
            icon: Icons.delete_outline_rounded,
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context)
                  .pop(TimeLimitDetailAction.disableRequested);
            },
          ),
        ],
      ),
    );
  }

  Widget _accentButton({
    required String label,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: AppTheme.accent,
            borderRadius: BorderRadius.circular(27),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: AppTheme.textOnAccent),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textOnAccent,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _textLink({
    required String label,
    required VoidCallback onTap,
    Color color = AppTheme.textPrimary,
    IconData? icon,
    double iconSize = 16,
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w500,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: iconSize, color: color),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: fontSize,
                fontWeight: fontWeight,
                color: color,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _prominentEditLink({required VoidCallback onTap}) {
    return _textLink(
      label: 'Edit rule',
      icon: Icons.edit_rounded,
      iconSize: 20,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      onTap: onTap,
    );
  }
}
