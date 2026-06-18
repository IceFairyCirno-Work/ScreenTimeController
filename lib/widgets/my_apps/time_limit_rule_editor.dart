import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/app_rule.dart';
import '../../theme/app_theme.dart';
import '../../utils/time_limit_formatter.dart';
import '../shared/duration_pill_picker.dart';
import 'hold_to_commit_button.dart';

/// Editing surface for a Time limit rule. Mirrors [ScheduleRuleEditor] layout.
class TimeLimitRuleEditor extends StatefulWidget {
  final String? customName;
  final VoidCallback onBack;
  final VoidCallback onRename;
  final Future<List<AppRuleItem>?> Function(List<AppRuleItem> currentApps)
      onSelectApps;
  final ValueChanged<TimeLimitRule> onCommit;
  final ValueChanged<TimeLimitRule>? onChanged;
  final TimeLimitRule? initial;
  final bool editMode;
  final VoidCallback? onDisable;
  final List<AppRuleItem>? defaultApps;

  const TimeLimitRuleEditor({
    super.key,
    this.customName,
    required this.onBack,
    required this.onRename,
    required this.onSelectApps,
    required this.onCommit,
    this.onChanged,
    this.initial,
    this.defaultApps,
    this.editMode = false,
    this.onDisable,
  });

  @override
  State<TimeLimitRuleEditor> createState() => _TimeLimitRuleEditorState();
}

class _TimeLimitRuleEditorState extends State<TimeLimitRuleEditor> {
  late Duration _allowedTime;
  late Duration _blockUntil;
  late final Set<RepeatDay> _activeDays;
  late bool _hardMode;
  late final List<AppRuleItem> _selectedApps;

  @override
  void initState() {
    super.initState();
    final rule = widget.initial;
    _allowedTime = TimeLimitFormatter.nearestAllowedDuration(
      rule?.allowedTime ?? const Duration(minutes: 30),
    );
    _blockUntil = TimeLimitFormatter.nearestBlockUntil(
      rule?.blockUntil ?? TimeLimitFormatter.tomorrowBlockUntil,
    );
    _activeDays = Set.from(rule?.repeatDays ?? RepeatDay.weekdays);
    _hardMode = rule?.difficulty == RuleDifficulty.deepFocus;
    _selectedApps = List.from(
      rule?.apps ?? widget.defaultApps ?? const <AppRuleItem>[],
    );
  }

  String get _daysLabel {
    if (_activeDays.length == 7) return 'Everyday';
    if (_activeDays.length == 5 &&
        RepeatDay.weekdays.every(_activeDays.contains)) {
      return 'Weekdays';
    }
    return 'Custom';
  }

  String get _title =>
      widget.customName ?? TimeLimitFormatter.formatTitle(_allowedTime);

  void _toggleDay(RepeatDay day) {
    setState(() {
      if (_activeDays.contains(day)) {
        if (_activeDays.length > 1) _activeDays.remove(day);
      } else {
        _activeDays.add(day);
      }
    });
    _emitChange();
  }

  TimeLimitRule _buildDraft() {
    final now = DateTime.now();
    return TimeLimitRule(
      id: widget.initial?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: widget.customName ?? TimeLimitFormatter.formatTitle(_allowedTime),
      difficulty: _hardMode ? RuleDifficulty.deepFocus : RuleDifficulty.strict,
      apps: _selectedApps,
      isEnabled: widget.initial?.isEnabled ?? true,
      createdAt: widget.initial?.createdAt ?? now,
      allowedTime: _allowedTime,
      blockUntil: _blockUntil,
      repeatDays: _activeDays.toList()
        ..sort((a, b) => a.index.compareTo(b.index)),
      disabledUntil: widget.initial?.disabledUntil,
      unblockedUntilByPackage: widget.initial?.unblockedUntilByPackage ?? const {},
      unblockedStartedAtByPackage:
          widget.initial?.unblockedStartedAtByPackage ?? const {},
      limitExceededAtByPackage:
          widget.initial?.limitExceededAtByPackage ?? const {},
      usageQuotaDay: widget.initial?.usageQuotaDay ??
          TimeLimitRule.quotaDayKey(now),
    );
  }

  void _emitChange() => widget.onChanged?.call(_buildDraft());

  void _commit() => widget.onCommit(_buildDraft());

  Future<void> _pickAllowedTime() async {
    final picked = await showDurationWheelDialog<Duration>(
      context: context,
      title: 'For this long',
      options: TimeLimitFormatter.allowedDurationOptions,
      labelFor: TimeLimitFormatter.formatDurationShort,
      selected: _allowedTime,
    );
    if (picked != null && mounted) {
      setState(() => _allowedTime = picked);
      _emitChange();
    }
  }

  Future<void> _pickBlockUntil() async {
    final picked = await showDurationWheelDialog<Duration>(
      context: context,
      title: 'Until',
      options: TimeLimitFormatter.blockUntilOptions,
      labelFor: TimeLimitFormatter.formatBlockUntilLabel,
      selected: _blockUntil,
    );
    if (picked != null && mounted) {
      setState(() => _blockUntil = picked);
      _emitChange();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            children: [
              _buildTriggerDayCard(),
              const SizedBox(height: 14),
              _buildActionCard(),
              const SizedBox(height: 24),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: widget.editMode
              ? _buildEditActions()
              : HoldToCommitButton(
                  onCommit: _commit,
                  enabled: _selectedApps.isNotEmpty,
                ),
        ),
      ],
    );
  }

  Widget _buildEditActions() {
    return Column(
      children: [
        _buildSaveButton(),
        const SizedBox(height: 10),
        _buildDisableButton(),
      ],
    );
  }

  Widget _buildSaveButton() {
    final enabled = _selectedApps.isNotEmpty;
    return SizedBox(
      width: double.infinity,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: GestureDetector(
          onTap: enabled
              ? () {
                  HapticFeedback.mediumImpact();
                  _commit();
                }
              : null,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              color: AppTheme.accent,
              borderRadius: BorderRadius.circular(27),
            ),
            child: Center(
              child: Text(
                'Save',
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
      ),
    );
  }

  Widget _buildDisableButton() {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onDisable?.call();
        },
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.delete_outline_rounded,
                size: 16,
                color: AppTheme.screenTimerControllerDeepFocus,
              ),
              const SizedBox(width: 8),
              Text(
                'Disable rule',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.screenTimerControllerDeepFocus,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
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
          Row(
            children: [
              _buildHeaderButton(icon: Icons.arrow_back, onTap: widget.onBack),
              Expanded(
                child: Center(
                  child: Text(
                    _title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
              _buildHeaderButton(
                icon: Icons.edit_outlined,
                onTap: widget.onRename,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
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

  Widget _buildTriggerDayCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: AppTheme.screenTimerControllerRuleCardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWhenIUseHeader(),
          const SizedBox(height: 16),
          _buildSelectedAppsRow(),
          const SizedBox(height: 14),
          _buildDivider(),
          const SizedBox(height: 14),
          _buildDurationRow(),
          const SizedBox(height: 14),
          _buildDivider(),
          const SizedBox(height: 14),
          _buildDaysHeader(),
          const SizedBox(height: 12),
          _buildDayTokens(),
        ],
      ),
    );
  }

  Widget _buildWhenIUseHeader() {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.screenTimerControllerMint.withValues(alpha: 0.15),
          ),
          child: const Icon(
            Icons.hourglass_bottom_rounded,
            size: 16,
            color: AppTheme.screenTimerControllerMint,
          ),
        ),
        const SizedBox(width: 10),
        RichText(
          text: TextSpan(
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
            children: [
              TextSpan(
                text: 'When I use ',
                style: TextStyle(color: AppTheme.textPrimary),
              ),
              TextSpan(
                text: 'Block',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedAppsRow() {
    final count = _selectedApps.length;
    return GestureDetector(
      onTap: _openAppsSheet,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Text(
            'Selected Apps',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
              decoration: TextDecoration.none,
            ),
          ),
          const Spacer(),
          Text(
            count == 0 ? 'None' : '$count app${count == 1 ? '' : 's'}',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: count == 0 ? AppTheme.textHint : AppTheme.screenTimerControllerMint,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.arrow_forward,
            size: 18,
            color: AppTheme.screenTimerControllerMint,
          ),
        ],
      ),
    );
  }

  Widget _buildDurationRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'For this long',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Daily',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textHint,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
        DurationPillPicker(
          label: TimeLimitFormatter.formatDurationShort(_allowedTime),
          onTap: _pickAllowedTime,
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: AppTheme.surfaceLight.withValues(alpha: 0.35),
    );
  }

  Widget _buildDaysHeader() {
    return Row(
      children: [
        Text(
          'On these days:',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
            decoration: TextDecoration.none,
          ),
        ),
        const Spacer(),
        Text(
          _daysLabel,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppTheme.textHint,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }

  Widget _buildDayTokens() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: RepeatDay.all.map((day) {
        final active = _activeDays.contains(day);
        return GestureDetector(
          onTap: () => _toggleDay(day),
          behavior: HitTestBehavior.opaque,
          child: _DayToken(letter: day.shortLabel[0], active: active),
        );
      }).toList(),
    );
  }

  Widget _buildActionCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: AppTheme.screenTimerControllerRuleCardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBlockStatusRow(),
          const SizedBox(height: 14),
          _buildUntilRow(),
          const SizedBox(height: 14),
          _buildDivider(),
          const SizedBox(height: 14),
          _buildHardModeRow(),
        ],
      ),
    );
  }

  Widget _buildBlockStatusRow() {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.screenTimerControllerMint, width: 1.6),
          ),
          child: const Icon(
            Icons.verified_user_outlined,
            size: 16,
            color: AppTheme.screenTimerControllerMint,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Then block app',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }

  Widget _buildUntilRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Until',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimary,
            decoration: TextDecoration.none,
          ),
        ),
        const Spacer(),
        DurationPillPicker(
          label: TimeLimitFormatter.formatBlockUntilLabel(_blockUntil),
          onTap: _pickBlockUntil,
        ),
      ],
    );
  }

  Widget _buildHardModeRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Hard mode',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildProBadge(),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                'No unblocks allowed',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textHint,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 28,
          child: CupertinoSwitch(
            value: _hardMode,
            activeTrackColor: AppTheme.screenTimerControllerMint,
            onChanged: (v) {
              setState(() => _hardMode = v);
              _emitChange();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppTheme.screenTimerControllerMint.withValues(alpha: 0.7),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt, size: 10, color: AppTheme.screenTimerControllerMint),
          const SizedBox(width: 2),
          Text(
            'PRO',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppTheme.screenTimerControllerMint,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAppsSheet() async {
    final updated = await widget.onSelectApps(List.from(_selectedApps));
    if (updated != null && mounted) {
      setState(() {
        _selectedApps
          ..clear()
          ..addAll(updated);
      });
      _emitChange();
    }
  }
}

class _DayToken extends StatelessWidget {
  final String letter;
  final bool active;

  const _DayToken({required this.letter, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? Colors.white : AppTheme.surfaceLight,
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: active ? Colors.black : Colors.white,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}
