import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/app_rule.dart';
import '../../providers/emergency_pass_provider.dart';
import '../../providers/rules_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/cjk_time_formatter.dart';
import 'rule_detail_row.dart';
import '../shared/app_bottom_sheet.dart';
import '../shared/disabled_unblock_action.dart';

/// Outcome of the rule detail sheet.
enum RuleDetailAction {
  /// User dismissed the sheet (drag down / tap outside / close button).
  cancelled,

  /// User tapped the primary "Unblock all apps" / "Block all apps" button,
  /// requesting a toggle of the rule's enabled state.
  toggleRequested,

  /// User tapped "Edit rule" and wants to open the editor flow.
  editRequested,

  /// User tapped "Disable rule" on an inactive rule — open the disable flow.
  disableRequested,

  /// User tapped "Re-enable rule" on a temporarily disabled rule.
  reenableRequested,
}

/// Public entry point — shows the rule detail bottom sheet for a [SessionRule].
///
/// Returns the action taken by the user so the caller can react (e.g. toggle
/// or refresh the UI after an edit/disable/remove performed in the edit flow).
Future<RuleDetailAction> showRuleDetailSheet(
  BuildContext context,
  SessionRule rule, {
  DateTime Function()? now,
}) {
  return showAppBottomSheet<RuleDetailAction>(
    context: context,
    builder: (ctx) => _RuleDetailSheet(rule: rule, now: now),
  ).then((action) => action ?? RuleDetailAction.cancelled);
}

class _RuleDetailSheet extends StatelessWidget {
  final SessionRule rule;
  final DateTime Function() now;

  const _RuleDetailSheet({
    required this.rule,
    DateTime Function()? now,
  }) : now = now ?? _defaultNow;

  static DateTime _defaultNow() => DateTime.now();

  /// Rule is inside its schedule window and not user-disabled (card appearance).
  bool get _isScheduleActive =>
      rule.isScheduleActive(now());

  /// Show "Unblock all apps" when blocking, or new apps were added mid-unblock.
  /// Hard mode rules and never-allowed-only rules never offer unblocks.
  bool _showUnblockAll(BuildContext context) {
    if (!_isScheduleActive) return false;
    return context.read<RulesProvider>().ruleHasUnblockableApps(
          rule,
          now(),
        );
  }

  /// Remaining time inside the active session window, otherwise time until the
  /// next scheduled start (honouring repeat days).
  Duration get _remaining {
    final current = now();
    final endMinutes = rule.endTime.hour * 60 + rule.endTime.minute;
    final currentMinutes = current.hour * 60 + current.minute;

    if (_isScheduleActive) {
      final diff = endMinutes - currentMinutes;
      return Duration(minutes: diff < 0 ? diff + 24 * 60 : diff);
    }
    return rule.nextStartAfter(current).difference(current);
  }

  String get _countdownLabel {
    // Temporal disable overrides the schedule-based countdown.
    if (rule.isCurrentlyDisabled(now())) {
      if (rule.isIndefinitelyDisabled()) return 'Disabled';
      final rem = rule.disabledUntil!.difference(now());
      final h = rem.inHours;
      final m = rem.inMinutes.remainder(60);
      if (h > 0 && m > 0) return '${h}h ${m}m until resume';
      if (h > 0) return '${h}h until resume';
      return '${m}m until resume';
    }
    final h = _remaining.inHours;
    final m = _remaining.inMinutes.remainder(60);
    final prefix = _isScheduleActive ? 'left' : 'until start';
    if (h > 0 && m > 0) return '${h}h ${m}m $prefix';
    if (h > 0) return '${h}h $prefix';
    return '${m}m $prefix';
  }

  /// Progress (0.0 – 1.0) of the green fill inside the countdown pill. When
  /// active it reflects elapsed session time; when inactive it is small to
  /// imply "waiting".
  double get _countdownProgress {
    if (!_isScheduleActive) return 0.12;
    final startMinutes = rule.startTime.hour * 60 + rule.startTime.minute;
    final endMinutes = rule.endTime.hour * 60 + rule.endTime.minute;
    final total = (endMinutes - startMinutes).abs();
    if (total == 0) return 0.5;
    final elapsed = total - _remaining.inMinutes;
    return (elapsed / total).clamp(0.12, 0.95);
  }

  String get _blockAppsValue {
    final count = rule.apps.length;
    return '$count ${count == 1 ? 'app' : 'apps'}';
  }

  @override
  Widget build(BuildContext context) {
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
                primary: true,
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  children: [
                    const SizedBox(height: 28),
                    _buildStatusOverview(),
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

  // ─────────────────────────── Header ───────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Column(
        children: [
          // Top drag handle
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
          // Close button (left aligned, circular dark)
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).pop();
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
          ),
        ],
      ),
    );
  }

  // ─────────────────────── Status & Overview ────────────────────

  Widget _buildStatusOverview() {
    final active = _isScheduleActive;
    final temporallyDisabled = rule.isCurrentlyDisabled(now());
    return Column(
      children: [
        _buildFlowBadge(active, temporallyDisabled),
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
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _subtitleLabel,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppTheme.textSecondary,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 18),
        _buildCountdownPill(active, temporallyDisabled),
      ],
    );
  }

  String get _subtitleLabel {
    final count = rule.apps.length;
    final appsPart = count == 0
        ? 'No apps blocked'
        : 'Block $count ${count == 1 ? 'app' : 'apps'}';
    if (rule.isCurrentlyDisabled(now())) return 'Temporarily disabled';
    if (!rule.isEnabled) return 'Paused';
    return appsPart;
  }

  /// Flow badge: calendar checklist (green-outlined) → chevron → shield (mint).
  Widget _buildFlowBadge(bool active, bool temporallyDisabled) {
    final calendarColor = active ? AppTheme.screenTimerControllerMint : AppTheme.textSecondary;
    final shieldColor = temporallyDisabled
        ? AppTheme.textHint
        : (active ? AppTheme.screenTimerControllerMint : AppTheme.textHint);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: active
              ? AppTheme.screenTimerControllerMint.withValues(alpha: 0.25)
              : AppTheme.cardBorder,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CircleIcon(
            icon: Icons.calendar_today_outlined,
            color: calendarColor,
            filled: false,
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.arrow_forward,
            size: 18,
            color: AppTheme.textHint,
          ),
          const SizedBox(width: 8),
          _CircleIcon(
            icon: Icons.shield_outlined,
            color: shieldColor,
            filled: active,
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownPill(bool active, bool temporallyDisabled) {
    final textColor = temporallyDisabled
        ? AppTheme.textSecondary
        : (active ? AppTheme.screenTimerControllerMint : AppTheme.textSecondary);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 120, maxWidth: 240),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(19),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            // Partial green fill from the left
            FractionallySizedBox(
              widthFactor: _countdownProgress,
              heightFactor: 1,
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.screenTimerControllerGreenBadgeBg,
                      AppTheme.screenTimerControllerGreenBadgeBg
                          .withValues(alpha: 0.55),
                    ],
                  ),
                ),
              ),
            ),
            // Text label centered
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _countdownLabel,
                    maxLines: 1,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────── Configuration Details ─────────────────

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
              compact: true,
              label: 'During this time',
              value: CjkTimeFormatter.formatRange(rule.startTime, rule.endTime),
            ),
            _divider(),
            RuleDetailRow(
              compact: true,
              label: 'On these days',
              value: rule.repeatLabel,
            ),
            _divider(),
            RuleDetailRow(
              compact: true,
              label: 'Block apps',
              value: _blockAppsValue,
            ),
            _divider(),
            RuleDetailRow(
              compact: true,
              label: 'Breaks allowed',
              value: rule.isHardMode ? 'No' : 'Yes',
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

  // ──────────────────────── Bottom Footer ───────────────────────

  Widget _buildFooter(BuildContext context) {
    final emergency = context.watch<EmergencyPassProvider>();
    final disabled = rule.isCurrentlyDisabled(now());
    final unblocked = rule.isCurrentlyUnblocked(now());
    final scheduleActive = _isScheduleActive;
    final showUnblockAll = _showUnblockAll(context);

    if (disabled && rule.isIndefinitelyDisabled()) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: _buildAccentButton(
          context,
          label: 'Re-enable rule',
          onTap: () {
            HapticFeedback.mediumImpact();
            Navigator.of(context).pop(RuleDetailAction.reenableRequested);
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
                Navigator.of(context).pop(RuleDetailAction.toggleRequested);
              },
            ),
            const SizedBox(height: 14),
            _buildEditLink(context),
          ],
        ),
      );
    }

    if (unblocked && scheduleActive) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: _buildProminentEditLink(context),
      );
    }

    // Inactive, temporarily disabled, or outside schedule — Edit + Disable.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAccentButton(
            context,
            label: 'Edit rule',
            icon: Icons.edit_rounded,
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.of(context).pop(RuleDetailAction.editRequested);
            },
          ),
          const SizedBox(height: 14),
          _buildFooterTextLink(
            icon: Icons.delete_outline_rounded,
            label: 'Disable rule',
            color: AppTheme.screenTimerControllerDeepFocus,
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop(RuleDetailAction.disableRequested);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAccentButton(
    BuildContext context, {
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

  Widget _buildEditLink(BuildContext context) {
    return _buildFooterTextLink(
      icon: Icons.edit_rounded,
      label: 'Edit rule',
      color: AppTheme.textPrimary,
      iconSize: 15,
      fontSize: 14,
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).pop(RuleDetailAction.editRequested);
      },
    );
  }

  Widget _buildProminentEditLink(BuildContext context) {
    return _buildFooterTextLink(
      icon: Icons.edit_rounded,
      label: 'Edit rule',
      color: AppTheme.textPrimary,
      iconSize: 20,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).pop(RuleDetailAction.editRequested);
      },
    );
  }

  /// Compact icon + label action — shared by Edit / Disable footer links.
  Widget _buildFooterTextLink({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    double iconSize = 15,
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w500,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: iconSize, color: color),
            const SizedBox(width: 8),
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
}

// ─────────────────────────── Helpers ───────────────────────────

class _CircleIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool filled;

  const _CircleIcon({
    required this.icon,
    required this.color,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color.withValues(alpha: 0.18) : Colors.transparent,
        border: Border.all(color: color, width: 1.4),
      ),
      child: Icon(icon, size: 15, color: color),
    );
  }
}
