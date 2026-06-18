import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/focus_template.dart';
import '../../theme/app_theme.dart';
import '../shared/app_bottom_sheet.dart';
import '../shared/block_apps_badge.dart';
import 'focus_template_painters.dart';

/// Shows a bottom-up sheet with the template details and a hold-to-start
/// button. Calls [onStart] after the user holds for 3 seconds.
///
/// [blockedCount] and [onBlockAppsTap] reflect the timer tab's shared blocked
/// apps list — the same list used by the main timer setup badge.
class FocusTemplateSheet extends StatefulWidget {
  final FocusTemplate template;
  final VoidCallback onStart;
  final int blockedCount;
  final Future<int> Function()? onBlockAppsTap;

  const FocusTemplateSheet({
    super.key,
    required this.template,
    required this.onStart,
    required this.blockedCount,
    this.onBlockAppsTap,
  });

  /// Convenience method to show the sheet as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required FocusTemplate template,
    required VoidCallback onStart,
    required int blockedCount,
    Future<int> Function()? onBlockAppsTap,
  }) {
    return showAppBottomSheet<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => FocusTemplateSheet(
        template: template,
        onStart: onStart,
        blockedCount: blockedCount,
        onBlockAppsTap: onBlockAppsTap,
      ),
    );
  }

  @override
  State<FocusTemplateSheet> createState() => _FocusTemplateSheetState();
}

class _FocusTemplateSheetState extends State<FocusTemplateSheet> {
  late int _blockedCount;

  @override
  void initState() {
    super.initState();
    _blockedCount = widget.blockedCount;
  }

  @override
  void didUpdateWidget(covariant FocusTemplateSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.blockedCount != oldWidget.blockedCount) {
      _blockedCount = widget.blockedCount;
    }
  }

  Future<void> _handleBlockAppsTap() async {
    final onTap = widget.onBlockAppsTap;
    if (onTap == null) return;
    final count = await onTap();
    if (!mounted) return;
    setState(() => _blockedCount = count);
  }

  @override
  Widget build(BuildContext context) {
    final template = widget.template;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: SingleChildScrollView(
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 12, 24, 32 + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Template preview thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: double.infinity,
                height: 140,
                child: CustomPaint(painter: painterForArt(template.art)),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              template.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 8),

            // Duration
            Text(
              template.durationLabel,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.screenTimerControllerMint,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 28),

            BlockAppsBadge(
              blockedCount: _blockedCount,
              onTap: widget.onBlockAppsTap == null ? null : _handleBlockAppsTap,
            ),
            const SizedBox(height: 28),

            // Hold to start button
            _HoldToStartButton(onComplete: () {
              Navigator.of(context).pop();
              widget.onStart();
            }),
            const SizedBox(height: 14),

            // Cancel
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// HOLD-TO-START — requires sustained 3s press with progress + haptics
// ═══════════════════════════════════════════════════════════════════
class _HoldToStartButton extends StatefulWidget {
  final VoidCallback onComplete;

  const _HoldToStartButton({required this.onComplete});

  @override
  State<_HoldToStartButton> createState() => _HoldToStartButtonState();
}

class _HoldToStartButtonState extends State<_HoldToStartButton>
    with SingleTickerProviderStateMixin {
  static const _holdDuration = Duration(seconds: 3);
  static const _vibrateInterval = Duration(milliseconds: 200);

  late final AnimationController _progressController;
  Timer? _vibrateTimer;
  int _vibrateStep = 0;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: _holdDuration,
    );

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _stopHolding();
        HapticFeedback.heavyImpact();
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _vibrateTimer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  void _startHolding() {
    _vibrateStep = 0;
    _progressController.forward();

    _vibrateTimer = Timer.periodic(_vibrateInterval, (_) {
      _vibrateStep++;
      if (_vibrateStep <= 5) {
        HapticFeedback.lightImpact();
      } else if (_vibrateStep <= 10) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.heavyImpact();
      }
    });
  }

  void _stopHolding() {
    _vibrateTimer?.cancel();
    _vibrateTimer = null;
    _progressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _startHolding(),
      onLongPressEnd: (_) {
        if (_progressController.status != AnimationStatus.completed) {
          _stopHolding();
        }
      },
      child: ListenableBuilder(
        listenable: _progressController,
        builder: (context, child) {
          final progress = _progressController.value;
          return LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                width: double.infinity,
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  color: Colors.white.withValues(alpha: 0.1),
                  border: Border.all(
                    color: AppTheme.screenTimerControllerMint
                        .withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(50),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          width: constraints.maxWidth * progress,
                          height: 58,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.screenTimerControllerMint
                                    .withValues(alpha: 0.4),
                                AppTheme.screenTimerControllerMintGlow
                                    .withValues(alpha: 0.5),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 16,
                            color: progress > 0.4
                                ? AppTheme.textOnAccent
                                : AppTheme.screenTimerControllerMint,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            progress > 0 ? 'Keep holding...' : 'Hold to start',
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: progress > 0.4
                                  ? AppTheme.textOnAccent
                                  : AppTheme.screenTimerControllerMint,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
