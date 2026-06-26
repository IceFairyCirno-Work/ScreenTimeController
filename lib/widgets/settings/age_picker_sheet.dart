import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../shared/app_bottom_sheet.dart';

final accountAgeOptions = List<int>.generate(100, (index) => index + 1);

Future<int?> showAgePickerSheet(
  BuildContext context, {
  required int? currentAge,
}) {
  final initialAge = currentAge ?? 30;

  return showAppBottomSheet<int>(
    context: context,
    builder: (ctx) => _AgePickerSheet(initialAge: initialAge),
  );
}

class _AgePickerSheet extends StatefulWidget {
  final int initialAge;

  const _AgePickerSheet({required this.initialAge});

  @override
  State<_AgePickerSheet> createState() => _AgePickerSheetState();
}

class _AgePickerSheetState extends State<_AgePickerSheet> {
  static const _itemExtent = 44.0;
  static const _visibleItems = 5;

  late final FixedExtentScrollController _controller;
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = accountAgeOptions.indexOf(widget.initialAge);
    if (_selectedIndex < 0) _selectedIndex = 29;
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

  void _confirm() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(accountAgeOptions[_selectedIndex]);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 10, 20, 24 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'My age',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w600,
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
                onTap: _confirm,
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
          ],
        ),
      ),
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
              childCount: accountAgeOptions.length,
              builder: (context, index) {
                final distance = (index - _selectedIndex).abs();
                return Opacity(
                  opacity: _opacityForDistance(distance),
                  child: Center(
                    child: Text(
                      accountAgeOptions[index].toString(),
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
