import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Result of the waiting screen flow.
enum WaitingResult {
  /// User completed the full countdown — the action may proceed.
  completed,
  /// User cancelled via "Nevermind" or the back button.
  cancelled,
}

/// Shows the full-screen breathing / waiting overlay.
///
/// Returns [WaitingResult.completed] when the countdown reaches zero (the user
/// "waited it out"), or [WaitingResult.cancelled] when dismissed.
///
/// The overlay is presented as a route so it can cover the entire viewport
/// including any open bottom sheets, and so the caller can simply `await` it.
Future<WaitingResult> showWaitingScreen(
  BuildContext context, {
  Duration countdown = const Duration(seconds: 5),
}) async {
  final result = await Navigator.of(context, rootNavigator: true).push<WaitingResult>(
    PageRouteBuilder<WaitingResult>(
      opaque: false,
      barrierDismissible: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) =>
          WaitingScreen(countdown: countdown),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
  return result ?? WaitingResult.cancelled;
}

// ─────────────────────────── Screen ───────────────────────────

class WaitingScreen extends StatefulWidget {
  final Duration countdown;

  const WaitingScreen({
    super.key,
    this.countdown = const Duration(seconds: 5),
  });

  @override
  State<WaitingScreen> createState() => _WaitingScreenState();
}

class _WaitingScreenState extends State<WaitingScreen>
    with TickerProviderStateMixin {
  static const Duration _breathCycle = Duration(seconds: 8);

  late final AnimationController _breathController;
  late final AnimationController _rippleController;
  late final AnimationController _countdownController;
  late final Animation<double> _breathScale;

  bool _completed = false;

  int get _totalSeconds => widget.countdown.inSeconds;

  int get _secondsLeft {
    if (_completed) return 0;
    final remaining = (_totalSeconds * (1 - _countdownController.value)).ceil();
    return remaining.clamp(0, _totalSeconds);
  }

  double get _countdownProgress =>
      _completed ? 1.0 : _countdownController.value;

  @override
  void initState() {
    super.initState();

    _breathController = AnimationController(
      vsync: this,
      duration: _breathCycle,
    )..repeat();

    _breathScale = Tween<double>(begin: 0.82, end: 1.16)
        .animate(CurvedAnimation(
      parent: _breathController,
      curve: Curves.easeInOutSine,
    ));

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    _countdownController = AnimationController(
      vsync: this,
      duration: widget.countdown,
    )
      ..addStatusListener(_onCountdownStatus)
      ..forward();
  }

  void _onCountdownStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    HapticFeedback.mediumImpact();
    setState(() => _completed = true);
  }

  void _continue() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(WaitingResult.completed);
  }

  void _cancel() {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop(WaitingResult.cancelled);
  }

  @override
  void dispose() {
    _breathController.dispose();
    _rippleController.dispose();
    _countdownController.dispose();
    super.dispose();
  }

  /// Label shown beneath the ring, synced to the breathing phase.
  String get _breathLabel {
    // 0.0–0.5 → expanding (breathe in), 0.5–1.0 → contracting (breathe out).
    final phase = _breathController.value;
    return phase < 0.5 ? 'Breathe In' : 'Breathe Out';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _breathController,
          _rippleController,
          _countdownController,
        ]),
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              _WaterBackground(progress: _rippleController.value),
              _SafeColumn(
                onCancel: _cancel,
                onContinue: _continue,
                breathScale: _breathScale,
                breathLabel: _breathLabel,
                secondsLeft: _secondsLeft,
                countdownProgress: _countdownProgress,
                completed: _completed,
              ),
            ],
          );
        },
      ),
    );
  }
}

// ───────────────────────── Foreground layout ─────────────────────────

class _SafeColumn extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onContinue;
  final Animation<double> breathScale;
  final String breathLabel;
  final int secondsLeft;
  final double countdownProgress;
  final bool completed;

  const _SafeColumn({
    required this.onCancel,
    required this.onContinue,
    required this.breathScale,
    required this.breathLabel,
    required this.secondsLeft,
    required this.countdownProgress,
    required this.completed,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: _BackButton(onTap: onCancel),
            ),
          ),
          const Spacer(),
          _BreathingFocus(
            scale: breathScale,
            label: breathLabel,
          ),
          const Spacer(),
          _BottomFooter(
            secondsLeft: secondsLeft,
            countdownProgress: countdownProgress,
            completed: completed,
            onCancel: onCancel,
            onContinue: onContinue,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.arrow_back,
          size: 20,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ─────────────────────────── Breathing ring ───────────────────────────

class _BreathingFocus extends StatelessWidget {
  final Animation<double> scale;
  final String label;

  const _BreathingFocus({required this.scale, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 260,
          height: 260,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer ambient glow (static bloom).
              _glowRing(size: 260, opacity: 0.05, blur: 60),
              _glowRing(size: 220, opacity: 0.08, blur: 40),
              // Animated core ring.
              ScaleTransition(
                scale: scale,
                child: const _CoreRing(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 36),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 600),
          child: Text(
            label,
            key: ValueKey(label),
            style: GoogleFonts.inter(
              fontSize: 19,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              letterSpacing: 0.3,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _glowRing({
    required double size,
    required double opacity,
    required double blur,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: opacity * 1.6),
            blurRadius: blur,
            spreadRadius: 4,
          ),
        ],
      ),
    );
  }
}

class _CoreRing extends StatelessWidget {
  const _CoreRing();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.45),
            Colors.white.withValues(alpha: 0.18),
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.7, 1.0],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66FFFFFF),
            blurRadius: 48,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Color(0x33FFFFFF),
            blurRadius: 24,
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────── Bottom footer ────────────────────────────

class _BottomFooter extends StatelessWidget {
  final int secondsLeft;
  final double countdownProgress;
  final bool completed;
  final VoidCallback onCancel;
  final VoidCallback onContinue;

  const _BottomFooter({
    required this.secondsLeft,
    required this.countdownProgress,
    required this.completed,
    required this.onCancel,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (completed)
            _ContinueButton(onTap: onContinue)
          else
            _StatusPill(
              secondsLeft: secondsLeft,
              countdownProgress: countdownProgress,
            ),
          const SizedBox(height: 22),
          GestureDetector(
            onTap: onCancel,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Nevermind',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ContinueButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        height: 58,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(29),
        ),
        child: Center(
          child: Text(
            'Continue',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black,
              letterSpacing: 0.2,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final int secondsLeft;
  final double countdownProgress;

  const _StatusPill({
    required this.secondsLeft,
    required this.countdownProgress,
  });

  @override
  Widget build(BuildContext context) {
    final label = 'Wait for ${secondsLeft}s';
    return Container(
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(29),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Progress fill grows left → right as the countdown elapses.
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: countdownProgress.clamp(0.0, 1.0),
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.18),
                      Colors.white.withValues(alpha: 0.10),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.85),
                letterSpacing: 0.2,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Water background ───────────────────────────

/// Dynamic water-ripple background built with a [CustomPainter].
///
/// Layers multiple sine-wave fills tinted with deep ocean blues and dark
/// greys, and scatters metallic white / gold specular highlights along the
/// wave crests to evoke the moving-water theme described in the brief.
class _WaterBackground extends StatelessWidget {
  final double progress;

  const _WaterBackground({required this.progress});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WaterPainter(progress: progress),
      size: Size.infinite,
    );
  }
}

class _WaterPainter extends CustomPainter {
  final double progress;

  _WaterPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Base vertical gradient: deep ocean blue → near black at the bottom.
    final basePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0xFF0A2540),
          Color(0xFF071A2E),
          Color(0xFF020812),
          Color(0xFF000000),
        ],
        stops: const [0.0, 0.35, 0.75, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, basePaint);

    // Layered sine waves. Each entry defines amplitude, base height,
    // wavelength, speed factor and color.
    final layers = <_WaveLayer>[
      _WaveLayer(
        amplitude: 26,
        baseHeight: 0.30,
        wavelength: 1.2,
        speed: 0.6,
        color: const Color(0xFF12355B).withValues(alpha: 0.55),
      ),
      _WaveLayer(
        amplitude: 34,
        baseHeight: 0.45,
        wavelength: 1.0,
        speed: 0.9,
        color: const Color(0xFF0B2A4A).withValues(alpha: 0.65),
      ),
      _WaveLayer(
        amplitude: 22,
        baseHeight: 0.58,
        wavelength: 1.5,
        speed: 0.4,
        color: const Color(0xFF082238).withValues(alpha: 0.7),
      ),
      _WaveLayer(
        amplitude: 40,
        baseHeight: 0.72,
        wavelength: 0.9,
        speed: 1.15,
        color: const Color(0xFF04121F).withValues(alpha: 0.85),
      ),
    ];

    for (final layer in layers) {
      _drawWave(canvas, size, layer);
    }

    // Metallic highlights along the upper wave crests.
    _drawHighlights(canvas, size);
  }

  void _drawWave(Canvas canvas, Size size, _WaveLayer layer) {
    final w = size.width;
    final h = size.height;
    final phase = progress * 2 * math.pi * layer.speed;
    final baseY = h * layer.baseHeight;

    final path = Path();
    path.moveTo(0, h);
    for (double x = 0; x <= w; x += 4) {
      final normalized = x / w;
      // Two superimposed sines give a richer ripple shape.
      final y = baseY +
          layer.amplitude *
              (math.sin(normalized * 2 * math.pi * layer.wavelength + phase) +
                  0.5 *
                      math.sin(normalized * 4 * math.pi * layer.wavelength -
                          phase * 1.3));
      path.lineTo(x, y);
    }
    path.lineTo(w, h);
    path.close();

    canvas.drawPath(path, Paint()..color = layer.color);
  }

  void _drawHighlights(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final phase = progress * 2 * math.pi * 0.9;

    // Scatter specular points along the second wave (the one near mid-screen).
    final baseY = h * 0.45;
    final amplitude = 34.0;
    final wavelength = 1.0;

    final gold = Paint()..color = const Color(0xFFE8C77A).withValues(alpha: 0.5);
    final white = Paint()..color = Colors.white.withValues(alpha: 0.45);

    for (int i = 0; i < 14; i++) {
      final t = i / 13;
      final x = t * w;
      final y = baseY +
          amplitude *
              (math.sin(t * 2 * math.pi * wavelength + phase) +
                  0.5 *
                      math.sin(t * 4 * math.pi * wavelength - phase * 1.3));
      // Twinkle by modulating radius with the phase.
      final twinkle = 0.5 + 0.5 * math.sin(phase * 2 + i);
      final radius = (0.8 + twinkle * 1.6).clamp(0.4, 2.4);
      final isGold = i % 4 == 0;
      canvas.drawCircle(
        Offset(x, y - 6),
        radius.toDouble(),
        isGold ? gold : white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaterPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _WaveLayer {
  final double amplitude;
  final double baseHeight;
  final double wavelength;
  final double speed;
  final Color color;

  const _WaveLayer({
    required this.amplitude,
    required this.baseHeight,
    required this.wavelength,
    required this.speed,
    required this.color,
  });
}
