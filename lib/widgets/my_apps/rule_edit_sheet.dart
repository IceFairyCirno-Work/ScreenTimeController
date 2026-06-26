import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/app_rule.dart';
import '../../theme/app_theme.dart';
import '../../utils/cjk_time_formatter.dart';
import '../../utils/responsive.dart';
import '../shared/app_bottom_sheet.dart';
import 'rule_name_editor.dart';
import 'schedule_rule_editor.dart';
import 'selected_apps_sheet.dart';

/// Result of the edit-rule flow.
enum RuleEditResult {
  /// User dismissed the sheet without any change.
  cancelled,

  /// User saved edits to the rule. The updated rule is available via
  /// [RuleEditOutcome.rule].
  saved,

  /// User disabled the rule for a chosen duration. The duration is available
  /// via [RuleEditOutcome.disableDuration].
  disabled,

  /// User permanently removed the rule.
  removed,
}

/// Concrete outcome returned by [showEditRuleSheet].
class RuleEditOutcome {
  final RuleEditResult result;
  final SessionRule? rule;

  /// The id of the rule this outcome refers to. Always populated so callers
  /// can act on disable/remove without needing a rule instance.
  final String ruleId;

  /// The chosen disable duration when [result] is [RuleEditResult.disabled].
  final DisableDuration? disableDuration;

  const RuleEditOutcome._({
    required this.result,
    required this.ruleId,
    this.rule,
    this.disableDuration,
  });

  const RuleEditOutcome.cancelled(String ruleId)
      : this._(result: RuleEditResult.cancelled, ruleId: ruleId);

  RuleEditOutcome.saved(SessionRule rule)
      : this._(result: RuleEditResult.saved, ruleId: rule.id, rule: rule);

  const RuleEditOutcome.disabled({
    required String ruleId,
    required DisableDuration duration,
  }) : this._(
          result: RuleEditResult.disabled,
          ruleId: ruleId,
          disableDuration: duration,
        );

  const RuleEditOutcome.removed(String ruleId)
      : this._(result: RuleEditResult.removed, ruleId: ruleId);
}

/// Predefined options for how long a rule can be disabled.
enum DisableDuration {
  indefinitely('Indefinitely'),
  for24Hours('For 24 hours'),
  forToday('For today'),
  for3Days('For 3 days'),
  for7Days('For 7 days');

  final String label;
  const DisableDuration(this.label);

  Duration? get duration => switch (this) {
        DisableDuration.indefinitely => null,
        DisableDuration.for24Hours => const Duration(hours: 24),
        DisableDuration.forToday => null, // use [resolveUntil] instead
        DisableDuration.for3Days => const Duration(days: 3),
        DisableDuration.for7Days => const Duration(days: 7),
      };

  /// Absolute moment the disable ends. Prefer this over [duration] for
  /// presets whose end time is calendar-based (e.g. "For today" → midnight).
  DateTime resolveUntil([DateTime? from]) {
    final now = from ?? DateTime.now();
    return switch (this) {
      DisableDuration.indefinitely => SessionRule.indefiniteDisableUntil,
      DisableDuration.for24Hours => now.add(const Duration(hours: 24)),
      DisableDuration.forToday =>
        DateTime(now.year, now.month, now.day + 1), // 00:00 next calendar day
      DisableDuration.for3Days => now.add(const Duration(days: 3)),
      DisableDuration.for7Days => now.add(const Duration(days: 7)),
    };
  }
}

/// Which view the edit-rule sheet opens on.
enum RuleEditInitialView { editor, disable }

/// Public entry point — shows the edit-rule bottom sheet for a [SessionRule].
///
/// The sheet hosts the editor form and, if the user chooses to disable, a
/// dedicated disable-confirmation view with a wheel selector.
Future<RuleEditOutcome> showEditRuleSheet(
  BuildContext context,
  SessionRule rule, {
  String? customName,
  RuleEditInitialView initialView = RuleEditInitialView.editor,
}) {
  return showAppBottomSheet<RuleEditOutcome>(
    context: context,
    useViewInsets: true,
    builder: (ctx) => _EditRuleSheet(
      rule: rule,
      initialCustomName: customName,
      initialView: initialView,
    ),
  ).then(
    (outcome) => outcome ?? RuleEditOutcome.cancelled(rule.id),
  );
}

/// Opens the disable-rule flow directly (wheel selector + confirm).
Future<RuleEditOutcome> showDisableRuleSheet(
  BuildContext context,
  SessionRule rule,
) =>
    showEditRuleSheet(context, rule, initialView: RuleEditInitialView.disable);

enum _EditView { editor, name, disable }

class _EditRuleSheet extends StatefulWidget {
  final SessionRule rule;
  final String? initialCustomName;
  final RuleEditInitialView initialView;

  const _EditRuleSheet({
    required this.rule,
    this.initialCustomName,
    this.initialView = RuleEditInitialView.editor,
  });

  @override
  State<_EditRuleSheet> createState() => _EditRuleSheetState();
}

class _EditRuleSheetState extends State<_EditRuleSheet> {
  late _EditView _view;
  late _EditView _previousView;
  String? _customName;

  /// Live snapshot of the editor draft. Kept across view switches so that
  /// navigating editor → name → editor (or editor → disable → editor) does
  /// not discard unsaved edits such as start/end time or selected apps.
  SessionRule? _draftRule;

  @override
  void initState() {
    super.initState();
    _view = widget.initialView == RuleEditInitialView.disable
        ? _EditView.disable
        : _EditView.editor;
    _previousView = _view;
    final name = widget.initialCustomName ?? widget.rule.name;
    final rule = widget.rule;
    _customName = CjkTimeFormatter.isDefaultRangeName(
      name,
      rule.startTime,
      rule.endTime,
    )
        ? null
        : (name.trim().isNotEmpty ? name.trim() : null);
  }

  void _goTo(_EditView next) {
    setState(() {
      _previousView = _view;
      _view = next;
    });
  }

  /// Forward navigation = going deeper (editor → disable).
  bool get _isForward => _view.index > _previousView.index;

  Key get _currentKey => switch (_view) {
        _EditView.editor => const ValueKey('editor'),
        _EditView.name => const ValueKey('name'),
        _EditView.disable => const ValueKey('disable'),
      };

  @override
  Widget build(BuildContext context) {
    final forward = _isForward;
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
        child: SingleChildScrollView(
          primary: true,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  alignment: Alignment.topCenter,
                  children: <Widget>[
                    ...previousChildren,
                    ?currentChild,
                  ],
                );
              },
              transitionBuilder: (child, animation) {
                final isIncoming = child.key == _currentKey;
                final enterOffset = forward
                    ? const Offset(1.0, 0.0)
                    : const Offset(-1.0, 0.0);
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: isIncoming ? enterOffset : Offset.zero,
                    end: isIncoming ? Offset.zero : -enterOffset,
                  ).animate(animation),
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              },
              child: _buildCurrentView(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_view) {
      case _EditView.disable:
        return _DisableRuleView(
          key: const ValueKey('disable'),
          onBack: () {
            if (widget.initialView == RuleEditInitialView.disable) {
              Navigator.of(context)
                  .pop(RuleEditOutcome.cancelled(widget.rule.id));
            } else {
              _goTo(_EditView.editor);
            }
          },
          onConfirm: (duration) {
            Navigator.of(context).pop(RuleEditOutcome.disabled(
              ruleId: widget.rule.id,
              duration: duration,
            ));
          },
          onRemove: () {
            HapticFeedback.heavyImpact();
            Navigator.of(context)
                .pop(RuleEditOutcome.removed(widget.rule.id));
          },
        );
      case _EditView.editor:
        return ScheduleRuleEditor(
          key: const ValueKey('editor'),
          initial: _draftRule ?? widget.rule,
          customName: _customName,
          editMode: true,
          onBack: () => Navigator.of(context)
              .pop(RuleEditOutcome.cancelled(widget.rule.id)),
          onRename: () => _goTo(_EditView.name),
          onSelectApps: (currentApps) =>
              showSelectedAppsSheet(context, currentApps: currentApps),
          onDisable: () => _goTo(_EditView.disable),
          onChanged: (draft) => _draftRule = draft,
          onCommit: (updated) =>
              Navigator.of(context).pop(RuleEditOutcome.saved(updated)),
        );
      case _EditView.name:
        return RuleNameEditorView(
          key: const ValueKey('name'),
          initialName: _customName,
          onBack: () => _goTo(_EditView.editor),
          onConfirm: (newName) {
            setState(() => _customName = newName);
            _goTo(_EditView.editor);
          },
        );
    }
  }
}

// ───────────────────────── Disable Rule View ─────────────────────────

class _DisableRuleView extends StatefulWidget {
  final VoidCallback onBack;
  final ValueChanged<DisableDuration> onConfirm;
  final VoidCallback onRemove;

  const _DisableRuleView({
    super.key,
    required this.onBack,
    required this.onConfirm,
    required this.onRemove,
  });

  @override
  State<_DisableRuleView> createState() => _DisableRuleViewState();
}

class _DisableRuleViewState extends State<_DisableRuleView> {
  static const _options = DisableDuration.values;
  static const _initialItem = DisableDuration.forToday;
  static const _itemExtent = 44.0;
  static const _visibleItems = 5;

  late final FixedExtentScrollController _controller;
  int _selectedIndex = _options.indexOf(_initialItem);

  @override
  void initState() {
    super.initState();
    _controller =
        FixedExtentScrollController(initialItem: _selectedIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onItemChanged(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const SizedBox(height: 28),
          _buildPromptSection(),
          const SizedBox(height: 24),
          _buildWheelSelector(),
          const SizedBox(height: 28),
          _buildPrimaryButton(),
          const SizedBox(height: 12),
          _buildRemoveLink(),
        ],
      ),
    );
  }

  // ─────────────────────────── Header ───────────────────────────

  Widget _buildHeader() {
    return Column(
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
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onBack();
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: AppTheme.surface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  size: 18,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
      ],
    );
  }

  // ─────────────────────── Notification & Prompt ────────────────

  Widget _buildPromptSection() {
    return Column(
      children: [
        _buildStatusIcon(),
        const SizedBox(height: 18),
        Text(
          'Disable this rule?',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            decoration: TextDecoration.none,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'If you disable this rule you may lose your streak.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppTheme.textSecondary,
            decoration: TextDecoration.none,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  /// Large circular dark-red badge enclosing a solid red trash icon.
  Widget _buildStatusIcon() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF3A1518),
        border: Border.all(
          color: const Color(0xFFFF3B30).withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: const Icon(
        Icons.delete_rounded,
        size: 34,
        color: Color(0xFFFF453A),
      ),
    );
  }

  // ─────────────────────── Wheel Selector ───────────────────────

  Widget _buildWheelSelector() {
    final wheelWidth = Responsive.wheelPickerWidth(context);
    return Container(
      height: _itemExtent * _visibleItems,
      decoration: BoxDecoration(
        color: AppTheme.screenTimerControllerRuleCardBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Central selection capsule
          Positioned(
            top: (_visibleItems - 1) / 2 * _itemExtent,
            child: IgnorePointer(
              child: Container(
                width: wheelWidth,
                height: _itemExtent,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(_itemExtent / 2),
                ),
              ),
            ),
          ),
          // Wheel
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification) {
                ScrollConfiguration.of(context);
              }
              return false;
            },
            child: ListWheelScrollView.useDelegate(
              controller: _controller,
              itemExtent: _itemExtent,
              perspective: 0.003,
              diameterRatio: 2.2,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: _onItemChanged,
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: _options.length,
                builder: (context, index) {
                  final distance = (index - _selectedIndex).abs();
                  return _WheelItem(
                    label: _options[index].label,
                    isActive: index == _selectedIndex,
                    opacity: _opacityForDistance(distance),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Returns an opacity value (0.0 – 1.0) based on the distance from the
  /// selected item, producing the 3D fading effect described in the design.
  double _opacityForDistance(int distance) {
    return switch (distance) {
      0 => 1.0,
      1 => 0.55,
      2 => 0.3,
      _ => 0.15,
    };
  }

  // ─────────────────────── Bottom Action Footer ─────────────────

  Widget _buildPrimaryButton() {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          widget.onConfirm(_options[_selectedIndex]);
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
              'Confirm',
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

  Widget _buildRemoveLink() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.heavyImpact();
        widget.onRemove();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          'Remove rule',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFFFF6B6B),
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Helpers ───────────────────────────

class _WheelItem extends StatelessWidget {
  final String label;
  final bool isActive;
  final double opacity;

  const _WheelItem({
    required this.label,
    required this.isActive,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Center(
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: isActive ? AppTheme.textPrimary : AppTheme.textSecondary,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}
