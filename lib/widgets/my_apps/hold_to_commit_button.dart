import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';

/// A wide capsule button that requires a sustained long-press to commit.
///
/// Mirrors the look & feel of the existing `_HoldToStartButton` used in the
/// focus-template sheet: progress fill, escalating haptics, and a label that
/// swaps from "Hold to Commit" → "Keep holding..." while pressed.
class HoldToCommitButton extends StatefulWidget {
  final String label;
  final String holdingLabel;
  final Duration holdDuration;
  final VoidCallback onCommit;

  /// When `false`, the button ignores gestures and renders dimmed.
  final bool enabled;

  const HoldToCommitButton({
    super.key,
    this.label = 'Hold to Commit',
    this.holdingLabel = 'Keep holding...',
    this.holdDuration = const Duration(seconds: 2),
    required this.onCommit,
    this.enabled = true,
  });

  @override
  State<HoldToCommitButton> createState() => _HoldToCommitButtonState();
}

class _HoldToCommitButtonState extends State<HoldToCommitButton>
    with SingleTickerProviderStateMixin {
  static const _vibrateInterval = Duration(milliseconds: 200);

  late final AnimationController _progressController;
  Timer? _vibrateTimer;
  int _vibrateStep = 0;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: widget.holdDuration,
    );

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _stopHolding();
        HapticFeedback.heavyImpact();
        widget.onCommit();
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
      // Escalating feedback: light → medium → heavy as the hold progresses.
      if (_vibrateStep <= 4) {
        HapticFeedback.lightImpact();
      } else if (_vibrateStep <= 8) {
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
    return IgnorePointer(
      ignoring: !widget.enabled,
      child: Opacity(
        opacity: widget.enabled ? 1.0 : 0.4,
        child: GestureDetector(
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
              return Container(
                width: double.infinity,
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  color: Colors.white.withValues(alpha: 0.1),
                  border: Border.all(
                    color: AppTheme.screenTimerControllerMint.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Stack(
                  children: [
                    // Progress fill (left → right)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(50),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        heightFactor: 1,
                        child: FractionallySizedBox(
                          widthFactor: progress,
                          heightFactor: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.screenTimerControllerMint.withValues(alpha: 0.4),
                                  AppTheme.screenTimerControllerMintGlow.withValues(alpha: 0.5),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Label
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
                            progress > 0 ? widget.holdingLabel : widget.label,
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
          ),
        ),
      ),
    );
  }
}
