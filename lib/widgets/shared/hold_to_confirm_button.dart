import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Red hold-to-confirm button matching the timer "Hold to leave" design.
class HoldToConfirmButton extends StatefulWidget {
  final String label;
  final String holdingLabel;
  final Duration holdDuration;
  final VoidCallback onComplete;

  const HoldToConfirmButton({
    super.key,
    required this.label,
    this.holdingLabel = 'Keep holding...',
    this.holdDuration = const Duration(seconds: 3),
    required this.onComplete,
  });

  @override
  State<HoldToConfirmButton> createState() => _HoldToConfirmButtonState();
}

class _HoldToConfirmButtonState extends State<HoldToConfirmButton>
    with SingleTickerProviderStateMixin {
  static const _vibrateInterval = Duration(milliseconds: 200);
  static const _accent = Color(0xFFFF3B30);

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
      if (_vibrateStep <= 8) {
        HapticFeedback.lightImpact();
      } else if (_vibrateStep <= 16) {
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
                  color: _accent.withValues(alpha: 0.15),
                  border: Border.all(
                    color: _accent.withValues(alpha: 0.4),
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
                          color: _accent.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        progress > 0 ? widget.holdingLabel : widget.label,
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: _accent,
                          decoration: TextDecoration.none,
                        ),
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
