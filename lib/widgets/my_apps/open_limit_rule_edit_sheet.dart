import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/app_rule.dart';
import '../../theme/app_theme.dart';
import '../../utils/open_limit_formatter.dart';
import '../../utils/responsive.dart';
import '../shared/app_bottom_sheet.dart';
import 'open_limit_rule_editor.dart';
import 'rule_edit_sheet.dart';
import 'rule_name_editor.dart';
import 'selected_apps_sheet.dart';

class OpenLimitEditOutcome {
  final RuleEditResult result;
  final OpenLimitRule? rule;
  final String ruleId;
  final DisableDuration? disableDuration;

  const OpenLimitEditOutcome._({
    required this.result,
    required this.ruleId,
    this.rule,
    this.disableDuration,
  });

  const OpenLimitEditOutcome.cancelled(String ruleId)
      : this._(result: RuleEditResult.cancelled, ruleId: ruleId);

  OpenLimitEditOutcome.saved(OpenLimitRule rule)
      : this._(
          result: RuleEditResult.saved,
          ruleId: rule.id,
          rule: rule,
        );

  const OpenLimitEditOutcome.disabled({
    required String ruleId,
    required DisableDuration duration,
  }) : this._(
          result: RuleEditResult.disabled,
          ruleId: ruleId,
          disableDuration: duration,
        );

  const OpenLimitEditOutcome.removed(String ruleId)
      : this._(result: RuleEditResult.removed, ruleId: ruleId);
}

Future<OpenLimitEditOutcome> showEditOpenLimitRuleSheet(
  BuildContext context,
  OpenLimitRule rule, {
  String? customName,
  RuleEditInitialView initialView = RuleEditInitialView.editor,
}) {
  return showAppBottomSheet<OpenLimitEditOutcome>(
    context: context,
    useViewInsets: true,
    builder: (ctx) => _EditOpenLimitRuleSheet(
      rule: rule,
      initialCustomName: customName,
      initialView: initialView,
    ),
  ).then(
    (outcome) => outcome ?? OpenLimitEditOutcome.cancelled(rule.id),
  );
}

Future<OpenLimitEditOutcome> showDisableOpenLimitRuleSheet(
  BuildContext context,
  OpenLimitRule rule,
) =>
    showEditOpenLimitRuleSheet(
      context,
      rule,
      initialView: RuleEditInitialView.disable,
    );

enum _EditView { editor, name, disable }

class _EditOpenLimitRuleSheet extends StatefulWidget {
  final OpenLimitRule rule;
  final String? initialCustomName;
  final RuleEditInitialView initialView;

  const _EditOpenLimitRuleSheet({
    required this.rule,
    this.initialCustomName,
    this.initialView = RuleEditInitialView.editor,
  });

  @override
  State<_EditOpenLimitRuleSheet> createState() =>
      _EditOpenLimitRuleSheetState();
}

class _EditOpenLimitRuleSheetState extends State<_EditOpenLimitRuleSheet> {
  late _EditView _view;
  late _EditView _previousView;
  String? _customName;
  OpenLimitRule? _draftRule;

  @override
  void initState() {
    super.initState();
    _view = widget.initialView == RuleEditInitialView.disable
        ? _EditView.disable
        : _EditView.editor;
    _previousView = _view;
    final name = widget.initialCustomName ?? widget.rule.name;
    final rule = widget.rule;
    _customName = OpenLimitFormatter.isDefaultOpenLimitName(name, rule.maxOpens)
        ? null
        : (name.trim().isNotEmpty ? name.trim() : null);
  }

  void _goTo(_EditView next) {
    setState(() {
      _previousView = _view;
      _view = next;
    });
  }

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
                  child: FadeTransition(opacity: animation, child: child),
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
        return _OpenLimitDisableRuleView(
          key: const ValueKey('disable'),
          onBack: () {
            if (widget.initialView == RuleEditInitialView.disable) {
              Navigator.of(context)
                  .pop(OpenLimitEditOutcome.cancelled(widget.rule.id));
            } else {
              _goTo(_EditView.editor);
            }
          },
          onConfirm: (duration) {
            Navigator.of(context).pop(OpenLimitEditOutcome.disabled(
              ruleId: widget.rule.id,
              duration: duration,
            ));
          },
          onRemove: () {
            HapticFeedback.heavyImpact();
            Navigator.of(context)
                .pop(OpenLimitEditOutcome.removed(widget.rule.id));
          },
        );
      case _EditView.editor:
        return OpenLimitRuleEditor(
          key: const ValueKey('editor'),
          initial: _draftRule ?? widget.rule,
          customName: _customName,
          editMode: true,
          onBack: () => Navigator.of(context)
              .pop(OpenLimitEditOutcome.cancelled(widget.rule.id)),
          onRename: () => _goTo(_EditView.name),
          onSelectApps: (currentApps) =>
              showSelectedAppsSheet(context, currentApps: currentApps),
          onDisable: () => _goTo(_EditView.disable),
          onChanged: (draft) => _draftRule = draft,
          onCommit: (updated) =>
              Navigator.of(context).pop(OpenLimitEditOutcome.saved(updated)),
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

class _OpenLimitDisableRuleView extends StatefulWidget {
  final VoidCallback onBack;
  final ValueChanged<DisableDuration> onConfirm;
  final VoidCallback onRemove;

  const _OpenLimitDisableRuleView({
    super.key,
    required this.onBack,
    required this.onConfirm,
    required this.onRemove,
  });

  @override
  State<_OpenLimitDisableRuleView> createState() =>
      _OpenLimitDisableRuleViewState();
}

class _OpenLimitDisableRuleViewState extends State<_OpenLimitDisableRuleView> {
  static const _options = DisableDuration.values;
  static const _initialItem = DisableDuration.forToday;
  static const _itemExtent = 44.0;
  static const _visibleItems = 5;

  late final FixedExtentScrollController _controller;
  int _selectedIndex = _options.indexOf(_initialItem);

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(initialItem: _selectedIndex);
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

  double _opacityForDistance(int distance) {
    return switch (distance) {
      0 => 1.0,
      1 => 0.55,
      2 => 0.3,
      _ => 0.15,
    };
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
          Text(
            'Disable this rule?',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 24),
          _buildWheelSelector(),
          const SizedBox(height: 28),
          SizedBox(
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
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: widget.onRemove,
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
        ],
      ),
    );
  }

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
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: widget.onBack,
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
        ),
      ],
    );
  }

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
          ListWheelScrollView.useDelegate(
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
                return Opacity(
                  opacity: _opacityForDistance(distance),
                  child: Center(
                    child: Text(
                      _options[index].label,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: index == _selectedIndex
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: index == _selectedIndex
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
