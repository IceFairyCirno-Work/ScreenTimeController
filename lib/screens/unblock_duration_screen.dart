import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import 'waiting_screen.dart';

/// Waiting screen → duration picker for unblock flows.
///
/// When [fixedMinutes] is set, skips the duration wheel and returns that value
/// after the waiting screen (used by Open limit rules).
Future<int?> showUnblockFlow(
  BuildContext context, {
  required String targetName,
  int? fixedMinutes,
}) async {
  final wait = await showWaitingScreen(context);
  if (wait != WaitingResult.completed) return null;
  if (!context.mounted) return null;
  if (fixedMinutes != null) return fixedMinutes;
  return showUnblockDurationScreen(context, targetName: targetName);
}

/// Duration picker shown after the waiting screen.
Future<int?> showUnblockDurationScreen(
  BuildContext context, {
  required String targetName,
}) {
  return Navigator.of(context, rootNavigator: true).push<int>(
    PageRouteBuilder<int>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) =>
          UnblockDurationScreen(targetName: targetName),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

class UnblockDurationScreen extends StatefulWidget {
  final String targetName;

  const UnblockDurationScreen({super.key, required this.targetName});

  @override
  State<UnblockDurationScreen> createState() => _UnblockDurationScreenState();
}

class _UnblockDurationScreenState extends State<UnblockDurationScreen> {
  static final _minutes = List<int>.generate(15, (i) => i + 1);
  static const _initialIndex = 4; // 5 minutes
  static const _itemExtent = 44.0;
  static const _visibleItems = 7;

  late final FixedExtentScrollController _controller;
  int _selectedIndex = _initialIndex;

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(initialItem: _initialIndex);
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

  void _cancel() {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
  }

  void _confirm() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(_minutes[_selectedIndex]);
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
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: _cancel,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppTheme.surface,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      size: 20,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 36),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                'Unblock ${widget.targetName} for...',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                  decoration: TextDecoration.none,
                  height: 1.3,
                ),
              ),
            ),
            const Spacer(),
            _buildWheelSelector(),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _confirm,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        color: AppTheme.accent,
                        borderRadius: BorderRadius.circular(27),
                      ),
                      child: Center(
                        child: Text(
                          'Unblock',
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
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: _cancel,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        'Nevermind',
                        style: GoogleFonts.inter(
                          fontSize: 15,
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
          ],
        ),
      ),
    );
  }

  Widget _buildWheelSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
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
                childCount: _minutes.length,
                builder: (context, index) {
                  final distance = (index - _selectedIndex).abs();
                  return _WheelItem(
                    label: '${_minutes[index]} minutes',
                    isActive: index == _selectedIndex,
                    opacity: _opacityForDistance(distance),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
