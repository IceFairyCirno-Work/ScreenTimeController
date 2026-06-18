import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';

/// Pill-shaped dropdown trigger used in rule editors.
class DurationPillPicker extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const DurationPillPicker({
    super.key,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
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
              label,
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
    );
  }
}

/// Centered dialog with a scrollable wheel picker (matches disable-rule UX).
Future<T?> showDurationWheelDialog<T>({
  required BuildContext context,
  required String title,
  required List<T> options,
  required String Function(T) labelFor,
  required T selected,
}) {
  return showDialog<T>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) => _DurationWheelDialog<T>(
      title: title,
      options: options,
      labelFor: labelFor,
      selected: selected,
    ),
  );
}

class _DurationWheelDialog<T> extends StatefulWidget {
  final String title;
  final List<T> options;
  final String Function(T) labelFor;
  final T selected;

  const _DurationWheelDialog({
    required this.title,
    required this.options,
    required this.labelFor,
    required this.selected,
  });

  @override
  State<_DurationWheelDialog<T>> createState() => _DurationWheelDialogState<T>();
}

class _DurationWheelDialogState<T> extends State<_DurationWheelDialog<T>> {
  static const _itemExtent = 44.0;
  static const _visibleItems = 5;

  late final FixedExtentScrollController _controller;
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.options.indexOf(widget.selected);
    if (_selectedIndex < 0) _selectedIndex = 0;
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
    return Dialog(
      backgroundColor: AppTheme.background,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 20),
            _buildWheelSelector(),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.of(context).pop(widget.options[_selectedIndex]);
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(25),
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
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWheelSelector() {
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
                width: 220,
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
              childCount: widget.options.length,
              builder: (context, index) {
                final distance = (index - _selectedIndex).abs();
                return Opacity(
                  opacity: _opacityForDistance(distance),
                  child: Center(
                    child: Text(
                      widget.labelFor(widget.options[index]),
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
