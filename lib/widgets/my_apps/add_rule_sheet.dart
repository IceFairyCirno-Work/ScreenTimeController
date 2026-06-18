import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/app_rule.dart';
import '../../providers/folder_apps_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/cjk_time_formatter.dart';
import '../../utils/open_limit_formatter.dart';
import '../../utils/time_limit_formatter.dart';
import '../shared/app_bottom_sheet.dart';
import 'open_limit_rule_editor.dart';
import 'rule_name_editor.dart';
import 'schedule_rule_editor.dart';
import 'selected_apps_sheet.dart';
import 'time_limit_rule_editor.dart';

/// Public entry point — shows the add-rule bottom sheet.
/// Returns the created/edited [AppRule] via [Navigator.pop], if any.
Future<AppRule?> showAddRuleSheet(
  BuildContext context, {
  AppRule? existing,
  List<AppRuleItem>? defaultApps,
  bool startOnSchedule = false,
}) {
  return showAppBottomSheet<AppRule>(
    context: context,
    useViewInsets: true,
    builder: (ctx) => _AddRuleSheet(
      existing: existing,
      defaultApps: defaultApps,
      startOnSchedule: startOnSchedule,
    ),
  );
}

class _AddRuleSheet extends StatefulWidget {
  final AppRule? existing;
  final List<AppRuleItem>? defaultApps;
  final bool startOnSchedule;

  const _AddRuleSheet({
    this.existing,
    this.defaultApps,
    this.startOnSchedule = false,
  });

  @override
  State<_AddRuleSheet> createState() => _AddRuleSheetState();
}

enum _SheetView { picker, schedule, timeLimit, openLimit, name }

class _AddRuleSheetState extends State<_AddRuleSheet> {
  late _SheetView _view;
  /// When `null`, the schedule header falls back to the time range.
  String? _customName;

  /// Live snapshot of the editor draft, kept across view switches so that
  /// navigating schedule → name → schedule preserves unsaved edits.
  SessionRule? _draftSessionRule;
  OpenLimitRule? _draftOpenLimitRule;
  TimeLimitRule? _draftTimeLimitRule;
  _SheetView _nameBackView = _SheetView.schedule;

  @override
  void initState() {
    super.initState();
    _view = widget.startOnSchedule ? _SheetView.schedule : _SheetView.picker;
    final existing = widget.existing;
    if (existing is SessionRule) {
      final name = existing.name;
      _customName = CjkTimeFormatter.isDefaultRangeName(
        name,
        existing.startTime,
        existing.endTime,
      )
          ? null
          : (name.trim().isNotEmpty ? name.trim() : null);
    } else if (existing is OpenLimitRule) {
      final name = existing.name;
      _customName = OpenLimitFormatter.isDefaultOpenLimitName(
        name,
        existing.maxOpens,
      )
          ? null
          : (name.trim().isNotEmpty ? name.trim() : null);
    } else if (existing is TimeLimitRule) {
      final name = existing.name;
      _customName = TimeLimitFormatter.isDefaultTimeLimitName(
        name,
        existing.allowedTime,
      )
          ? null
          : (name.trim().isNotEmpty ? name.trim() : null);
    }
  }

  /// Centralised view navigation.
  void _goTo(_SheetView next) {
    setState(() => _view = next);
  }

  @override
  Widget build(BuildContext context) {
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
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 120),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
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
                return FadeTransition(
                  opacity: animation,
                  child: child,
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
      case _SheetView.schedule:
        final isNewRule = widget.existing == null;
        return ScheduleRuleEditor(
          key: const ValueKey('schedule-editor'),
          initial: _draftSessionRule ??
              (widget.existing is SessionRule
                  ? widget.existing as SessionRule
                  : null),
          defaultApps: isNewRule
              ? (widget.defaultApps ??
                  context
                      .read<FolderAppsProvider>()
                      .distractingAppsAsRuleItems)
              : null,
          customName: _customName,
          onBack: () {
            setState(() {
              _customName = null;
              _draftSessionRule = null;
            });
            _goTo(_SheetView.picker);
          },
          onRename: () {
            _nameBackView = _SheetView.schedule;
            _goTo(_SheetView.name);
          },
          onSelectApps: (currentApps) =>
              showSelectedAppsSheet(context, currentApps: currentApps),
          onChanged: (draft) => _draftSessionRule = draft,
          onCommit: (rule) => Navigator.of(context).pop(rule),
        );
      case _SheetView.openLimit:
        final isNewOpenRule = widget.existing == null;
        return OpenLimitRuleEditor(
          key: const ValueKey('open-limit-editor'),
          initial: _draftOpenLimitRule ??
              (widget.existing is OpenLimitRule
                  ? widget.existing as OpenLimitRule
                  : null),
          defaultApps: isNewOpenRule
              ? (widget.defaultApps ??
                  context
                      .read<FolderAppsProvider>()
                      .distractingAppsAsRuleItems)
              : null,
          customName: _customName,
          onBack: () {
            setState(() {
              _customName = null;
              _draftOpenLimitRule = null;
            });
            _goTo(_SheetView.picker);
          },
          onRename: () {
            _nameBackView = _SheetView.openLimit;
            _goTo(_SheetView.name);
          },
          onSelectApps: (currentApps) =>
              showSelectedAppsSheet(context, currentApps: currentApps),
          onChanged: (draft) => _draftOpenLimitRule = draft,
          onCommit: (rule) => Navigator.of(context).pop(rule),
        );
      case _SheetView.timeLimit:
        final isNewTimeRule = widget.existing == null;
        return TimeLimitRuleEditor(
          key: const ValueKey('time-limit-editor'),
          initial: _draftTimeLimitRule ??
              (widget.existing is TimeLimitRule
                  ? widget.existing as TimeLimitRule
                  : null),
          defaultApps: isNewTimeRule
              ? (widget.defaultApps ??
                  context
                      .read<FolderAppsProvider>()
                      .distractingAppsAsRuleItems)
              : null,
          customName: _customName,
          onBack: () {
            setState(() {
              _customName = null;
              _draftTimeLimitRule = null;
            });
            _goTo(_SheetView.picker);
          },
          onRename: () {
            _nameBackView = _SheetView.timeLimit;
            _goTo(_SheetView.name);
          },
          onSelectApps: (currentApps) =>
              showSelectedAppsSheet(context, currentApps: currentApps),
          onChanged: (draft) => _draftTimeLimitRule = draft,
          onCommit: (rule) => Navigator.of(context).pop(rule),
        );
      case _SheetView.name:
        return RuleNameEditorView(
          key: const ValueKey('name-editor'),
          initialName: _customName,
          onBack: () => _goTo(_nameBackView),
          onConfirm: (newName) {
            setState(() => _customName = newName);
            _goTo(_nameBackView);
          },
        );
      case _SheetView.picker:
        return _PickerView(
          key: const ValueKey('picker'),
          onClose: () => Navigator.of(context).pop(),
          onSelectSchedule: () => _goTo(_SheetView.schedule),
          onSelectTimeLimit: () => _goTo(_SheetView.timeLimit),
          onSelectOpenLimit: () => _goTo(_SheetView.openLimit),
        );
    }
  }
}

// ───────────────────────── Picker View ─────────────────────────

class _PickerView extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onSelectSchedule;
  final VoidCallback onSelectTimeLimit;
  final VoidCallback onSelectOpenLimit;

  const _PickerView({
    super.key,
    required this.onClose,
    required this.onSelectSchedule,
    required this.onSelectTimeLimit,
    required this.onSelectOpenLimit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHandle(),
        _buildTopBar(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            children: [
              _RuleOptionCard(
                icon: Icons.event_available_outlined,
                title: 'Schedule',
                subtitle: 'Block apps during a time window',
                available: true,
                onTap: onSelectSchedule,
              ),
              const SizedBox(height: 12),
              _RuleOptionCard(
                icon: Icons.hourglass_bottom_rounded,
                title: 'Time limit',
                subtitle: 'Block after a daily usage cap',
                available: true,
                onTap: onSelectTimeLimit,
              ),
              const SizedBox(height: 12),
              _RuleOptionCard(
                icon: Icons.lock_outline_rounded,
                title: 'Open limit',
                subtitle: 'Block after N app opens',
                available: true,
                onTap: onSelectOpenLimit,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Row(
        children: [
          const Spacer(),
          Text(
            'New rule',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              decoration: TextDecoration.none,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onClose,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 16,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool available;
  final VoidCallback? onTap;

  const _RuleOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.available = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor =
        available ? AppTheme.screenTimerControllerMint : AppTheme.textSecondary;
    return Opacity(
      opacity: available ? 1.0 : 0.45,
      child: GestureDetector(
        onTap: available ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.screenTimerControllerRuleCardBg,
            borderRadius: BorderRadius.circular(20),
            border: available
                ? Border.all(
                    color: AppTheme.screenTimerControllerMint.withValues(alpha: 0.18),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: accentColor, width: 1.6),
                ),
                child: Icon(icon, size: 22, color: accentColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        if (!available) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Soon',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textHint,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
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
              Icon(
                Icons.arrow_forward,
                color:
                    available ? AppTheme.screenTimerControllerMint : AppTheme.textHint,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
