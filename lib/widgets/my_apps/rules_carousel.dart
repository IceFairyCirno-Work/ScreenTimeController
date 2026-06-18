import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/app_rule.dart';
import '../../providers/rules_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/duration_formatters.dart';
import '../../utils/website_helpers.dart';

const kRulesCardWidth = 180.0;
const kRulesCardHeight = 200.0;
const _kRuleCardIconSize = 32.0;

const _kRuleCardGradient = RadialGradient(
  center: Alignment(-0.8, -0.8),
  radius: 1.2,
  colors: [Color(0xFF1A3A2A), AppTheme.screenTimerControllerRuleCardBg],
  stops: [0.0, 0.7],
);

class RulesCarousel extends StatelessWidget {
  final bool showSeeAllButton;
  final bool includeTrailingCard;
  final TextStyle? titleStyle;
  final double horizontalPadding;
  final double titleHorizontalPadding;
  final double cardSpacing;
  final String? packageName;
  final VoidCallback? onSeeAllTap;
  final VoidCallback? onAddTap;
  final VoidCallback? onCreateRuleTap;
  final void Function(AppRule rule)? onRuleTap;

  const RulesCarousel({
    super.key,
    this.showSeeAllButton = true,
    this.includeTrailingCard = true,
    this.titleStyle,
    this.horizontalPadding = 20,
    this.titleHorizontalPadding = 20,
    this.cardSpacing = 12,
    this.packageName,
    this.onSeeAllTap,
    this.onAddTap,
    this.onCreateRuleTap,
    this.onRuleTap,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedTitleStyle = titleStyle ?? AppTheme.sectionTitle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: titleHorizontalPadding),
          child: Row(
            children: [
              Text('Rules', style: resolvedTitleStyle),
              if (showSeeAllButton) ...[
                const Spacer(),
                GestureDetector(
                  onTap: onSeeAllTap,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.surface,
                    ),
                    child: const Icon(
                      Icons.arrow_forward,
                      size: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        RulesCarouselRow(
          includeTrailingCard: includeTrailingCard,
          horizontalPadding: horizontalPadding,
          cardSpacing: cardSpacing,
          packageName: packageName,
          onAddTap: onAddTap,
          onCreateRuleTap: onCreateRuleTap,
          onRuleTap: onRuleTap,
        ),
      ],
    );
  }
}

class RulesCarouselRow extends StatelessWidget {
  final bool includeTrailingCard;
  final double horizontalPadding;
  final double cardSpacing;
  final String? packageName;
  final VoidCallback? onAddTap;
  final VoidCallback? onCreateRuleTap;
  final void Function(AppRule rule)? onRuleTap;

  const RulesCarouselRow({
    super.key,
    this.includeTrailingCard = true,
    this.horizontalPadding = 20,
    this.cardSpacing = 12,
    this.packageName,
    this.onAddTap,
    this.onCreateRuleTap,
    this.onRuleTap,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RulesProvider>();
    final sessionRules = packageName == null
        ? provider.sessions
        : provider.blockingRulesForApp(packageName!);
    final openLimitRules = packageName == null
        ? provider.openLimits
        : provider.openLimitRulesForApp(packageName!);
    final timeLimitRules = packageName == null
        ? provider.timeLimits
        : provider.timeLimitRulesForApp(packageName!);

    final ruleCards = <Widget>[
      ...sessionRules.map(
        (rule) => SessionRuleCard(
          rule: rule,
          onTap: onRuleTap != null ? () => onRuleTap!(rule) : null,
        ),
      ),
      ...timeLimitRules.map(
        (rule) => TimeLimitRuleCard(
          rule: rule,
          onTap: onRuleTap != null ? () => onRuleTap!(rule) : null,
        ),
      ),
      ...openLimitRules.map(
        (rule) => OpenLimitRuleCard(
          rule: rule,
          onTap: onRuleTap != null ? () => onRuleTap!(rule) : null,
        ),
      ),
    ];
    final addCard = includeTrailingCard
        ? [
            if (onAddTap != null)
              GestureDetector(
                onTap: onAddTap,
                behavior: HitTestBehavior.opaque,
                child: const TrailingRuleCard(),
              )
            else
              const TrailingRuleCard(),
          ]
        : <Widget>[];
    final allCards = [...ruleCards, ...addCard];

    if (allCards.isEmpty) {
      if (packageName != null && onCreateRuleTap != null) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: _CreateRulePillButton(onTap: onCreateRuleTap!),
        );
      }
      return SizedBox(
        height: kRulesCardHeight,
        child: Center(
          child: Text(
            'No rules yet',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textHint,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: kRulesCardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        itemCount: allCards.length,
        separatorBuilder: (_, _) => SizedBox(width: cardSpacing),
        itemBuilder: (context, index) => allCards[index],
      ),
    );
  }
}

class _CreateRulePillButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CreateRulePillButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, size: 20, color: Colors.black),
            const SizedBox(width: 8),
            Text(
              'Create a rule',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TrailingRuleCard extends StatelessWidget {
  final bool expand;

  const TrailingRuleCard({super.key, this.expand = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: expand ? double.infinity : kRulesCardWidth,
      height: expand ? kRulesCardHeight : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.screenTimerControllerRuleCardBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.add,
                size: _kRuleCardIconSize,
                color: AppTheme.textHint,
              ),
            ],
          ),
          const Spacer(),
          Opacity(
            opacity: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.screenTimerControllerGreenBadgeBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '5h 24m left',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.screenTimerControllerMint,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Add rule',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 2),
          Opacity(
            opacity: 0,
            child: Text(
              '4 apps blocked',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppTheme.textHint,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────── Dynamic rule cards ───────────────────────

/// Renders a real [SessionRule] in the rules carousel.
class SessionRuleCard extends StatelessWidget {
  final SessionRule rule;
  final bool expand;
  final DateTime Function() now;
  final VoidCallback? onTap;

  const SessionRuleCard({
    super.key,
    required this.rule,
    this.expand = false,
    this.onTap,
    DateTime Function()? now,
  }) : now = now ?? _defaultNow;

  static DateTime _defaultNow() => DateTime.now();

  /// Remaining time inside the active session window.
  Duration get _remainingInWindow {
    final current = now();
    final endMinutes = rule.endTime.hour * 60 + rule.endTime.minute;
    final currentMinutes = current.hour * 60 + current.minute;
    var diff = endMinutes - currentMinutes;
    if (diff <= 0) diff += 24 * 60;
    return Duration(minutes: diff);
  }

  /// Time until the next scheduled start, honouring [rule.repeatDays].
  Duration get _timeUntilStart =>
      rule.nextStartAfter(now()).difference(now());

  /// Combined status label shown inside the badge area.
  String get _statusBadge {
    // Temporal disable wins over schedule.
    if (rule.isCurrentlyDisabled(now())) {
      if (rule.isIndefinitelyDisabled()) return 'Disabled';
      final remaining = rule.disabledUntil!.difference(now());
      if (remaining.inHours >= 1) {
        return 'Resumes in ${formatDurationSingleUnit(remaining)}';
      }
      return 'Resumes soon';
    }
    if (!rule.isEnabled) return 'Paused';
    if (rule.isWithinWindow(now())) {
      final rem = _remainingInWindow;
      final h = rem.inHours;
      final m = rem.inMinutes.remainder(60);
      if (h > 0 && m > 0) return '${h}h ${m}m left';
      if (h > 0) return '${h}h left';
      return '${m}m left';
    }
    return 'Starts in ${formatDurationSingleUnit(_timeUntilStart)}';
  }

  bool get _isScheduleActive => rule.isScheduleActive(now());

  @override
  Widget build(BuildContext context) {
    final scheduleActive = _isScheduleActive;
    final temporallyDisabled = rule.isCurrentlyDisabled(now());

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          width: expand ? double.infinity : kRulesCardWidth,
          height: kRulesCardHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildCardBody(scheduleActive, temporallyDisabled),
              if (temporallyDisabled)
                _DisabledRuleOverlay(
                  label: rule.disabledOverlayLabel(now()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardBody(bool scheduleActive, bool temporallyDisabled) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.screenTimerControllerRuleCardBg,
        gradient: _kRuleCardGradient,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: _kRuleCardIconSize,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward,
                size: _kRuleCardIconSize,
                color: AppTheme.textHint,
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.shield,
                size: _kRuleCardIconSize,
                color: scheduleActive ? AppTheme.screenTimerControllerMint : AppTheme.textHint,
              ),
            ],
          ),
          const Spacer(),
          _buildBadge(scheduleActive, temporallyDisabled),
          const SizedBox(height: 10),
          Text(
            rule.name,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              decoration: TextDecoration.none,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.clip,
          ),
          const SizedBox(height: 2),
          Text(
            _appsBlockedLabel,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppTheme.textHint,
              decoration: TextDecoration.none,
            ),
            maxLines: 2,
            softWrap: true,
            overflow: TextOverflow.clip,
          ),
        ],
      ),
    );
  }

  String get _appsBlockedLabel =>
      WebsiteHelpers.ruleTargetsBlockedLabel(rule.apps);

  Widget _buildBadge(bool active, bool temporallyDisabled) {
    if (temporallyDisabled) {
      return const SizedBox.shrink();
    }
    if (!rule.isEnabled) {
      return _badgeBox('Paused', AppTheme.textHint);
    }
    if (active) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.screenTimerControllerGreenBadgeBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _statusBadge,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.screenTimerControllerMint,
            decoration: TextDecoration.none,
          ),
        ),
      );
    }
    return _badgeBox(_statusBadge, AppTheme.textSecondary);
  }

  Widget _badgeBox(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: color,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

/// Renders a real [TimeLimitRule] in the carousel.
class TimeLimitRuleCard extends StatelessWidget {
  final TimeLimitRule rule;
  final bool expand;
  final DateTime Function() now;
  final VoidCallback? onTap;

  const TimeLimitRuleCard({
    super.key,
    required this.rule,
    this.expand = false,
    this.onTap,
    DateTime Function()? now,
  }) : now = now ?? _defaultNow;

  static DateTime _defaultNow() => DateTime.now();

  String get _appsBlockedLabel =>
      WebsiteHelpers.ruleTargetsBlockLabel(rule.apps);

  Duration get _timeUntilActive =>
      rule.nextActiveAfter(now()).difference(now());

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
    return 'Starts in ${formatDurationSingleUnit(_timeUntilActive)}';
  }

  @override
  Widget build(BuildContext context) {
    final active = rule.isRuleActive(now());
    final temporallyDisabled = rule.isCurrentlyDisabled(now());
    final statusBadge = _statusBadge();

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          width: expand ? double.infinity : kRulesCardWidth,
          height: kRulesCardHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.screenTimerControllerRuleCardBg,
                  gradient: _kRuleCardGradient,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.hourglass_bottom_rounded,
                          size: _kRuleCardIconSize,
                          color: active
                              ? AppTheme.screenTimerControllerMint
                              : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward,
                          size: _kRuleCardIconSize,
                          color: AppTheme.textHint,
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.shield,
                          size: _kRuleCardIconSize,
                          color: active ? AppTheme.screenTimerControllerMint : AppTheme.textHint,
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (temporallyDisabled)
                      const SizedBox.shrink()
                    else if (!rule.isEnabled)
                      Text(
                        statusBadge,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textHint,
                          decoration: TextDecoration.none,
                        ),
                      )
                    else if (active)
                      Text(
                        statusBadge,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                          decoration: TextDecoration.none,
                        ),
                      )
                    else
                      Text(
                        statusBadge,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textHint,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    const SizedBox(height: 10),
                    Text(
                      rule.name,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        decoration: TextDecoration.none,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.clip,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _appsBlockedLabel,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textHint,
                        decoration: TextDecoration.none,
                      ),
                      maxLines: 2,
                      softWrap: true,
                      overflow: TextOverflow.clip,
                    ),
                  ],
                ),
              ),
              if (temporallyDisabled)
                _DisabledRuleOverlay(
                  label: rule.disabledOverlayLabel(now()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders a real [OpenLimitRule] in the carousel.
class OpenLimitRuleCard extends StatelessWidget {
  final OpenLimitRule rule;
  final bool expand;
  final DateTime Function() now;
  final VoidCallback? onTap;

  const OpenLimitRuleCard({
    super.key,
    required this.rule,
    this.expand = false,
    this.onTap,
    DateTime Function()? now,
  }) : now = now ?? _defaultNow;

  static DateTime _defaultNow() => DateTime.now();

  String get _appsBlockedLabel =>
      WebsiteHelpers.ruleTargetsBlockedLabel(rule.apps);

  Duration get _timeUntilActive =>
      rule.nextActiveAfter(now()).difference(now());

  String _statusBadge(RulesProvider provider) {
    if (rule.isCurrentlyDisabled(now())) {
      if (rule.isIndefinitelyDisabled()) return 'Disabled';
      final remaining = rule.disabledUntil!.difference(now());
      if (remaining.inHours >= 1) {
        return 'Resumes in ${formatDurationSingleUnit(remaining)}';
      }
      return 'Resumes soon';
    }
    if (!rule.isEnabled) return 'Paused';
    if (rule.isRuleActive(now())) {
      final left = provider.openLimitUnblocksRemaining(rule, now());
      return '$left open${left == 1 ? '' : 's'} left';
    }
    return 'Starts in ${formatDurationSingleUnit(_timeUntilActive)}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RulesProvider>();
    final active = rule.isRuleActive(now());
    final temporallyDisabled = rule.isCurrentlyDisabled(now());
    final statusBadge = _statusBadge(provider);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          width: expand ? double.infinity : kRulesCardWidth,
          height: kRulesCardHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.screenTimerControllerRuleCardBg,
                  gradient: _kRuleCardGradient,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.lock_outline_rounded,
                          size: _kRuleCardIconSize,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward,
                          size: _kRuleCardIconSize,
                          color: AppTheme.textHint,
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.shield,
                          size: _kRuleCardIconSize,
                          color: active ? AppTheme.screenTimerControllerMint : AppTheme.textHint,
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (active)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.screenTimerControllerGreenBadgeBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusBadge,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.screenTimerControllerMint,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      )
                    else
                      Text(
                        statusBadge,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textHint,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    const SizedBox(height: 10),
                    Text(
                      rule.name,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        decoration: TextDecoration.none,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.clip,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _appsBlockedLabel,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textHint,
                        decoration: TextDecoration.none,
                      ),
                      maxLines: 2,
                      softWrap: true,
                      overflow: TextOverflow.clip,
                    ),
                  ],
                ),
              ),
              if (temporallyDisabled)
                _DisabledRuleOverlay(
                  label: rule.disabledOverlayLabel(now()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dark scrim + horizontal pill (pause icon + duration / "Disabled").
class _DisabledRuleOverlay extends StatelessWidget {
  final String label;

  const _DisabledRuleOverlay({required this.label});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.62),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.pause_rounded,
                size: 18,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
