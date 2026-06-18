import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/app_rule.dart';
import '../../theme/app_theme.dart';
import '../../utils/cjk_time_formatter.dart';
import 'hold_to_commit_button.dart';

/// Editing surface for a Schedule-type rule. Composed of:
/// 1. Header (handle / back / title / edit)
/// 2. Card Group 1 — Time & Day scheduling
/// 3. Card Group 2 — App & restriction rules
/// 4. Bottom action bar with Hold-to-Commit (add mode) or Save/Disable
///    buttons (edit mode).
class ScheduleRuleEditor extends StatefulWidget {
  /// When non-null, overrides the time-range header title with a custom name.
  final String? customName;
  final VoidCallback onBack;
  final VoidCallback onRename;

  /// Opens the selected-apps management sheet. Receives the current selection
  /// and returns the updated list (or `null` if the user dismissed it).
  final Future<List<AppRuleItem>?> Function(List<AppRuleItem> currentApps)
      onSelectApps;
  final ValueChanged<SessionRule> onCommit;

  /// Optional live callback fired whenever the in-editor draft changes (time,
  /// days, apps, hard mode). Lets the host persist the draft across view
  /// switches so navigating away and back does not lose edits.
  final ValueChanged<SessionRule>? onChanged;

  /// Optional seed values when editing an existing rule.
  final SessionRule? initial;

  /// When `true` the bottom action bar renders two stacked buttons
  /// ("Save" + "Disable rule") instead of the Hold-to-Commit button.
  /// Used when editing an existing rule from the detail sheet.
  final bool editMode;

  /// Called when the user taps "Disable rule". Only relevant in [editMode].
  final VoidCallback? onDisable;

  /// Pre-selected apps when creating a new rule (not used when [initial] is set).
  final List<AppRuleItem>? defaultApps;

  const ScheduleRuleEditor({
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
  State<ScheduleRuleEditor> createState() => _ScheduleRuleEditorState();
}

class _ScheduleRuleEditorState extends State<ScheduleRuleEditor> {
  late TimeOfDay _start;
  late TimeOfDay _end;
  late final Set<RepeatDay> _activeDays;
  late bool _hardMode;
  late final List<AppRuleItem> _selectedApps;

  @override
  void initState() {
    super.initState();
    final rule = widget.initial;
    _start = rule?.startTime ?? const TimeOfDay(hour: 9, minute: 0);
    _end = rule?.endTime ?? const TimeOfDay(hour: 17, minute: 0);
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

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
      builder: (context, child) => Theme(
        data: AppTheme.darkTheme,
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _start = picked;
        } else {
          _end = picked;
        }
      });
      _emitChange();
    }
  }

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

  /// Builds the current draft as a [SessionRule] without committing it.
  /// Used both by [_commit] and [_emitChange] so the host can persist edits
  /// across view switches.
  SessionRule _buildDraft() {
    final fallbackName = CjkTimeFormatter.formatRange(_start, _end);
    return SessionRule(
      id: widget.initial?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: widget.customName ?? fallbackName,
      difficulty: _hardMode ? RuleDifficulty.deepFocus : RuleDifficulty.strict,
      apps: _selectedApps,
      isEnabled: widget.initial?.isEnabled ?? true,
      createdAt: widget.initial?.createdAt ?? DateTime.now(),
      startTime: _start,
      endTime: _end,
      repeatDays: _activeDays.toList()..sort((a, b) => a.index.compareTo(b.index)),
    );
  }

  void _emitChange() {
    widget.onChanged?.call(_buildDraft());
  }

  void _commit() {
    widget.onCommit(_buildDraft());
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
              _buildTimeDayCard(),
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

  // ───────────────────── Edit-mode action buttons ────────────────────

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
    // Mirrors the "Disable rule" link style used in rule_detail_sheet:
    // red text with a trash-bin icon on the left, centered, full-width tap target.
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

  // ───────────────────────── Header ─────────────────────────

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
              _buildHeaderButton(
                icon: Icons.arrow_back,
                onTap: widget.onBack,
              ),
              Expanded(
                child: Center(
                  child: Text(
                    widget.customName ??
                        CjkTimeFormatter.formatRange(_start, _end),
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

  Widget _buildHeaderButton({required IconData icon, required VoidCallback onTap}) {
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

  // ─────────────────── Card Group 1: Time & Day ───────────────────

  Widget _buildTimeDayCard() {
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
            icon: Icons.event_available_outlined,
            iconColor: AppTheme.screenTimerControllerMint,
            label: 'During this time',
          ),
          const SizedBox(height: 12),
          _buildTimeRangeRows(),
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
  }) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: iconColor, width: 1.6),
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

  Widget _buildTimeRangeRows() {
    return IntrinsicHeight(
      child: Row(
        children: [
          // Dotted timeline connecting From ↔ To
          SizedBox(
            width: 24,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _timelineDot(),
                const Expanded(child: _DottedVLine()),
                _timelineDot(),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              children: [
                _buildTimeRow(label: 'From', time: _start, isStart: true),
                const SizedBox(height: 10),
                _buildTimeRow(label: 'To', time: _end, isStart: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineDot() {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.surfaceLight, width: 1.5),
      ),
    );
  }

  Widget _buildTimeRow({
    required String label,
    required TimeOfDay time,
    required bool isStart,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
            decoration: TextDecoration.none,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => _pickTime(isStart),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppTheme.screenTimerControllerPillBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.surfaceLight.withValues(alpha: 0.6),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  CjkTimeFormatter.format(time),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
          ),
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

  // ─────────────── Card Group 2: App & Restriction ───────────────

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
            border: Border.all(color: AppTheme.screenTimerControllerMint, width: 1.6),
          ),
          child: const Icon(
            Icons.verified_user_outlined,
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
                text: 'Apps are ',
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
          const Icon(
            Icons.bolt,
            size: 10,
            color: AppTheme.screenTimerControllerMint,
          ),
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

// ───────────────────────── Custom painters ─────────────────────────

class _DottedVLine extends StatelessWidget {
  const _DottedVLine();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DottedVLinePainter(),
      child: const SizedBox(width: 1.5),
    );
  }
}

/// Paints a vertical dotted line that fills whatever height its parent
/// (typically an [Expanded] inside an [IntrinsicHeight]) assigns to it.
class _DottedVLinePainter extends CustomPainter {
  static const double _dashHeight = 3.0;
  static const double _gap = 3.0;
  static const double _total = _dashHeight + _gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.surfaceLight
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final midX = size.width / 2;
    var y = 0.0;
    // Center the dashed run vertically.
    final usable = size.height;
    final count = (usable / _total).floor();
    final extra = usable - count * _total;
    y += extra / 2;
    while (y + _dashHeight <= size.height) {
      canvas.drawLine(
        Offset(midX, y),
        Offset(midX, y + _dashHeight),
        paint,
      );
      y += _total;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
