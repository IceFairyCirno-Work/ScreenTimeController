import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/app_rule.dart';
import '../../theme/app_theme.dart';
import '../../utils/open_limit_formatter.dart';
import 'hold_to_commit_button.dart';

/// Editing surface for an Open limit rule. Mirrors [ScheduleRuleEditor] layout.
class OpenLimitRuleEditor extends StatefulWidget {
  final String? customName;
  final VoidCallback onBack;
  final VoidCallback onRename;
  final Future<List<AppRuleItem>?> Function(List<AppRuleItem> currentApps)
      onSelectApps;
  final ValueChanged<OpenLimitRule> onCommit;
  final ValueChanged<OpenLimitRule>? onChanged;
  final OpenLimitRule? initial;
  final bool editMode;
  final VoidCallback? onDisable;
  final List<AppRuleItem>? defaultApps;

  const OpenLimitRuleEditor({
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
  State<OpenLimitRuleEditor> createState() => _OpenLimitRuleEditorState();
}

class _OpenLimitRuleEditorState extends State<OpenLimitRuleEditor> {
  static const _minOpens = 1;
  static const _maxOpens = 10;
  static const _minSessionMinutes = 1;
  static const _maxSessionMinutes = 60;

  late int _maxOpensValue;
  late int _sessionMinutes;
  late final Set<RepeatDay> _activeDays;
  late bool _hardMode;
  late final List<AppRuleItem> _selectedApps;

  @override
  void initState() {
    super.initState();
    final rule = widget.initial;
    _maxOpensValue = rule?.maxOpens ?? 4;
    _sessionMinutes = rule?.sessionLengthMinutes ?? 5;
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
      widget.customName ?? OpenLimitFormatter.formatTitle(_maxOpensValue);

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

  OpenLimitRule _buildDraft() {
    final now = DateTime.now();
    return OpenLimitRule(
      id: widget.initial?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: widget.customName ?? OpenLimitFormatter.formatTitle(_maxOpensValue),
      difficulty: _hardMode ? RuleDifficulty.deepFocus : RuleDifficulty.strict,
      apps: _selectedApps,
      isEnabled: widget.initial?.isEnabled ?? true,
      createdAt: widget.initial?.createdAt ?? now,
      maxOpens: _maxOpensValue,
      sessionLengthMinutes: _sessionMinutes,
      repeatDays: _activeDays.toList()
        ..sort((a, b) => a.index.compareTo(b.index)),
      unblocksUsed: widget.initial?.unblocksUsed ?? 0,
      unblocksQuotaDay:
          widget.initial?.unblocksQuotaDay ?? OpenLimitRule.quotaDayKey(now),
    );
  }

  void _emitChange() => widget.onChanged?.call(_buildDraft());

  void _commit() => widget.onCommit(_buildDraft());

  void _adjustOpens(int delta) {
    final next = (_maxOpensValue + delta).clamp(_minOpens, _maxOpens);
    if (next == _maxOpensValue) return;
    setState(() => _maxOpensValue = next);
    _emitChange();
  }

  void _adjustSession(int delta) {
    final next =
        (_sessionMinutes + delta).clamp(_minSessionMinutes, _maxSessionMinutes);
    if (next == _sessionMinutes) return;
    setState(() => _sessionMinutes = next);
    _emitChange();
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
              _buildLimitDayCard(),
              const SizedBox(height: 14),
              _buildRestrictionCard(),
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

  Widget _buildLimitDayCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: AppTheme.screenTimerControllerRuleCardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.lock_outline_rounded,
            iconColor: AppTheme.textPrimary,
            label: 'Open limit',
            outline: true,
          ),
          const SizedBox(height: 16),
          _buildStepperRow(
            title: 'App opens',
            subtitle: 'Per day',
            valueLabel: '$_maxOpensValue',
            onDecrement: () => _adjustOpens(-1),
            onIncrement: () => _adjustOpens(1),
            canDecrement: _maxOpensValue > _minOpens,
            canIncrement: _maxOpensValue < _maxOpens,
          ),
          const SizedBox(height: 14),
          _buildDivider(),
          const SizedBox(height: 14),
          _buildStepperRow(
            title: 'For this long',
            subtitle: 'Daily',
            valueLabel: OpenLimitFormatter.formatSessionLength(_sessionMinutes),
            onDecrement: () => _adjustSession(-1),
            onIncrement: () => _adjustSession(1),
            canDecrement: _sessionMinutes > _minSessionMinutes,
            canIncrement: _sessionMinutes < _maxSessionMinutes,
          ),
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

  Widget _buildSectionHeader({
    required IconData icon,
    required Color iconColor,
    required String label,
    bool outline = false,
  }) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: outline
                ? Border.all(color: iconColor, width: 1.6)
                : null,
            color: outline ? null : iconColor.withValues(alpha: 0.15),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Text(
          label,
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

  Widget _buildStepperRow({
    required String title,
    required String subtitle,
    required String valueLabel,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
    required bool canDecrement,
    required bool canIncrement,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
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
        _NumericStepper(
          valueLabel: valueLabel,
          onDecrement: onDecrement,
          onIncrement: onIncrement,
          canDecrement: canDecrement,
          canIncrement: canIncrement,
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

  Widget _buildRestrictionCard() {
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
          _buildSelectedAppsRow(),
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
            color: AppTheme.textSecondary.withValues(alpha: 0.25),
          ),
          child: const Icon(
            Icons.shield,
            size: 16,
            color: AppTheme.textSecondary,
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
                text: 'Then block app ',
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
}

class _NumericStepper extends StatelessWidget {
  final String valueLabel;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final bool canDecrement;
  final bool canIncrement;

  const _NumericStepper({
    required this.valueLabel,
    required this.onDecrement,
    required this.onIncrement,
    required this.canDecrement,
    required this.canIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepperButton(
          icon: Icons.remove,
          onTap: canDecrement ? onDecrement : null,
        ),
        const SizedBox(width: 10),
        Container(
          width: 44,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            valueLabel,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.black,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        const SizedBox(width: 10),
        _StepperButton(
          icon: Icons.add,
          onTap: canIncrement ? onIncrement : null,
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _StepperButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: onTap == null ? 0.35 : 1.0,
        child: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: AppTheme.textPrimary),
        ),
      ),
    );
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
