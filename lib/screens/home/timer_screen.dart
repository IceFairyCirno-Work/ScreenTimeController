import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/focus_template.dart';
import '../../providers/timer_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/home/focus_template_painters.dart';
import '../../widgets/home/focus_template_sheet.dart';
import '../../widgets/my_apps/selected_apps_sheet.dart';
import '../../widgets/shared/app_bottom_sheet.dart';
import '../../widgets/shared/block_apps_badge.dart';

const _kTimerBgAsset = 'assets/timerbg/image-clean.png';

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> with TickerProviderStateMixin {
  static const _enterTotalDuration = Duration(milliseconds: 800);
  static const _enterMoveDuration = Duration(milliseconds: 700);
  static const _enterBgDelay = Duration(milliseconds: 100);

  Duration _selectedDuration = const Duration(minutes: 30);
  bool _isInfiniteMode = false;
  /// 1 = increment (slide up / in from below), -1 = decrement (slide down / in from above).
  int _durationChangeDirection = 1;
  bool _pendingEnterAnimation = false;

  late final AnimationController _enterController;
  late final Animation<double> _timerEnterProgress;
  late final Animation<double> _bgEnterProgress;

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: _enterTotalDuration,
    );
    final timerEnd = _enterMoveDuration.inMilliseconds /
        _enterTotalDuration.inMilliseconds;
    final bgStart = _enterBgDelay.inMilliseconds /
        _enterTotalDuration.inMilliseconds;
    _timerEnterProgress = CurvedAnimation(
      parent: _enterController,
      curve: Interval(0, timerEnd, curve: Curves.easeOutCubic),
    );
    _bgEnterProgress = CurvedAnimation(
      parent: _enterController,
      curve: Interval(bgStart, 1, curve: Curves.easeOutCubic),
    );

    if (context.read<TimerProvider>().isRunning) {
      _pendingEnterAnimation =
          context.read<TimerProvider>().consumePlayEnterAnimation();
      if (!_pendingEnterAnimation) {
        _enterController.value = 1;
      }
    }
  }

  @override
  void dispose() {
    _enterController.dispose();
    super.dispose();
  }

  void _kickEnterAnimationIfPending() {
    if (!_pendingEnterAnimation) return;
    _pendingEnterAnimation = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _enterController.forward(from: 0);
    });
  }

  void _decrement() {
    setState(() {
      _durationChangeDirection = -1;
      if (_isInfiniteMode) return;
      if (_selectedDuration.inMinutes <= 5) {
        _isInfiniteMode = true;
      } else {
        final minutes = _selectedDuration.inMinutes - 5;
        _selectedDuration = Duration(minutes: minutes);
      }
    });
  }

  void _increment() {
    setState(() {
      _durationChangeDirection = 1;
      if (_isInfiniteMode) {
        _isInfiniteMode = false;
        _selectedDuration = const Duration(minutes: 5);
        return;
      }
      final minutes = (_selectedDuration.inMinutes + 5).clamp(5, 180);
      _selectedDuration = Duration(minutes: minutes);
    });
  }

  void _startTimer() {
    final timer = context.read<TimerProvider>();
    timer.startTimer(
      duration: _selectedDuration,
      infiniteMode: _isInfiniteMode,
    );
  }

  /// Starts the timer using a focus template's predefined duration.
  void _startFromTemplate(FocusTemplate template) {
    setState(() {
      _isInfiniteMode = false;
      _selectedDuration = template.duration;
    });
    context.read<TimerProvider>().startFromTemplate(template.duration);
  }

  void _showTemplateSheet(FocusTemplate template) {
    final timer = context.read<TimerProvider>();
    FocusTemplateSheet.show(
      context,
      template: template,
      blockedCount: timer.blockedApps.length,
      onBlockAppsTap: _openBlockAppsSheet,
      onStart: () => _startFromTemplate(template),
    );
  }

  Future<int> _openBlockAppsSheet() async {
    final timer = context.read<TimerProvider>();
    final updated = await showSelectedAppsSheet(
      context,
      currentApps: timer.blockedApps,
    );
    if (updated != null && mounted) {
      timer.setBlockedApps(updated);
      return updated.length;
    }
    return timer.blockedApps.length;
  }

  void _stopTimer() {
    _enterController.reset();
    context.read<TimerProvider>().stopTimer();
  }

  void _showLeaveDialog() {
    showAppBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _LeaveDialog(
        onLeave: () {
          Navigator.pop(context);
          _stopTimer();
        },
      ),
    );
  }

  String _formatTime(Duration duration) {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:00';
  }

  String _formatRemaining(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatLabel(Duration duration) {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60);
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final timer = context.watch<TimerProvider>();

    if (timer.isRunning) {
      _kickEnterAnimationIfPending();
      return _buildCountdownMode(context, timer);
    }
    return _buildSetupMode(context, timer);
  }

  // ── Setup mode (normal timer page) ──
  Widget _buildSetupMode(BuildContext context, TimerProvider timer) {
    final topPadding = MediaQuery.of(context).padding.top;

    return ColoredBox(
      color: AppTheme.background,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── A. Hero background + header + timer display ──
            _HeroSection(
              topPadding: topPadding,
              formattedTime:
                  _isInfiniteMode ? '00:00' : _formatTime(_selectedDuration),
            ),
            const SizedBox(height: 28),

            // ── B. Time adjuster controls ──
            _TimeAdjuster(
              label: _formatLabel(_selectedDuration),
              isInfiniteMode: _isInfiniteMode,
              changeDirection: _durationChangeDirection,
              onDecrement: _decrement,
              onIncrement: _increment,
            ),
            const SizedBox(height: 28),

            // ── B. Start button ──
            _StartButton(onTap: _startTimer),
            const SizedBox(height: 16),

            // ── B. Block apps badge ──
            BlockAppsBadge(
              blockedCount: timer.blockedApps.length,
              onTap: _openBlockAppsSheet,
            ),
            const SizedBox(height: 32),

            // ── C. For you gallery ──
            _ForYouSection(onTemplateTap: _showTemplateSheet),
            const SizedBox(height: 120), // bottom nav space
          ],
        ),
      ),
    );
  }

  // ── Countdown mode (full-screen timer running) ──
  Widget _buildCountdownMode(BuildContext context, TimerProvider timer) {
    final topPadding = MediaQuery.of(context).padding.top;
    final size = MediaQuery.sizeOf(context);
    final heroHeight = 280 + topPadding;
    final setupClockHeight =
        ((size.width - 48).clamp(200.0, 260.0)) * 120 / 260;
    final heroTimerCenterY = topPadding + 112 + setupClockHeight / 2;
    final screenCenterY = size.height / 2;
    final timerTravelY = heroTimerCenterY - screenCenterY;
    final bgTravelY = -(size.height - heroHeight) * 0.42;

    return ColoredBox(
      color: AppTheme.background,
      child: SizedBox.expand(
        child: AnimatedBuilder(
          animation: _enterController,
          builder: (context, child) {
            final timerT = _timerEnterProgress.value;
            final bgT = _bgEnterProgress.value;
            final timerDy = timerTravelY * (1 - timerT);
            final bgDy = bgTravelY * (1 - bgT);
            final bgAlignment = Alignment.lerp(
              const Alignment(0, -0.15),
              Alignment.center,
              bgT,
            )!;

            return Stack(
              fit: StackFit.expand,
              children: [
                Transform.translate(
                  offset: Offset(0, bgDy),
                  child: _TimerBackgroundImage(alignment: bgAlignment),
                ),
                Center(
                  child: Transform.translate(
                    offset: Offset(0, timerDy),
                    child: _RunningClockDisplay(
                      timeText: _formatRemaining(timer.remainingSeconds),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  top: topPadding + 8,
                  child: Opacity(
                    opacity: bgT.clamp(0.0, 1.0),
                    child: GestureDetector(
                      onTap: _showLeaveDialog,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.close,
                          color: Colors.white.withValues(alpha: 0.7),
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// A. HERO SECTION — dark abstract texture background + "Timer" title
// ═══════════════════════════════════════════════════════════════════

class _HeroSection extends StatelessWidget {
  final double topPadding;
  final String formattedTime;

  const _HeroSection({required this.topPadding, required this.formattedTime});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280 + topPadding,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _TimerBackgroundImage(alignment: Alignment(0, -0.15)),
          // Gradient fade into true black at bottom
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Color(0xFF000000),
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),
          // Title
          Positioned(
            left: 24,
            top: topPadding + 16,
            child: Text(
              'Timer',
              style: GoogleFonts.inter(
                fontSize: 34,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.2,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          // Timer display — vertically centered between title and adjuster row
          Positioned(
            left: 0,
            right: 0,
            top: topPadding + 112,
            child: _CountdownDisplay(formattedTime: formattedTime),
          ),
        ],
      ),
    );
  }
}

/// Cave texture from [assets/timerbg]; cropped with [BoxFit.cover].
class _TimerBackgroundImage extends StatelessWidget {
  final Alignment alignment;

  const _TimerBackgroundImage({this.alignment = Alignment.center});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _kTimerBgAsset,
      fit: BoxFit.cover,
      alignment: alignment,
      width: double.infinity,
      height: double.infinity,
      filterQuality: FilterQuality.medium,
    );
  }
}

/// Active countdown clock — larger digits, lighter color.
class _RunningClockDisplay extends StatelessWidget {
  final String timeText;

  const _RunningClockDisplay({required this.timeText});

  @override
  Widget build(BuildContext context) {
    final clockWidth =
        (MediaQuery.sizeOf(context).width - 48).clamp(200.0, 300.0);
    final clockHeight = clockWidth * 140 / 300;

    return SizedBox(
      width: clockWidth,
      height: clockHeight,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3A3A3E), Color(0xFF1E1E22)],
          ),
          border: Border.all(color: const Color(0xFF4A4A4E), width: 2.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.04),
              blurRadius: 0,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF2A3440), Color(0xFF1A2028)],
            ),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                timeText,
                style: GoogleFonts.orbitron(
                  fontSize: 56,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFE0E0E0),
                  letterSpacing: 4,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// B. COUNTDOWN DISPLAY — skeuomorphic glass clock frame
// ═══════════════════════════════════════════════════════════════════

class _CountdownDisplay extends StatelessWidget {
  final String formattedTime;

  const _CountdownDisplay({required this.formattedTime});

  @override
  Widget build(BuildContext context) {
    final clockWidth =
        (MediaQuery.sizeOf(context).width - 48).clamp(200.0, 260.0);
    final clockHeight = clockWidth * 120 / 260;

    return Center(
      child: SizedBox(
        width: clockWidth,
        height: clockHeight,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF3A3A3E), Color(0xFF1E1E22)],
            ),
            border: Border.all(color: const Color(0xFF4A4A4E), width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.04),
                blurRadius: 0,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: const Color(0xFF1A2028),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF2A3440), Color(0xFF1A2028)],
              ),
            ),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  formattedTime,
                  style: GoogleFonts.orbitron(
                    fontSize: 52,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF3A3E44),
                    letterSpacing: 4,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Vertical slide + fast fade when a timer value changes (adjuster pill only).
class _AnimatedSlide extends StatelessWidget {
  final Key childKey;
  final int direction;
  final Widget child;

  const _AnimatedSlide({
    required this.childKey,
    required this.direction,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final verticalOffset = direction >= 0 ? 0.45 : -0.45;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 110),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.hardEdge,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (child, animation) {
        final slideTween = Tween<Offset>(
          begin: Offset(0, verticalOffset),
          end: Offset.zero,
        );
        return ClipRect(
          child: SlideTransition(
            position: slideTween.animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          ),
        );
      },
      child: KeyedSubtree(
        key: childKey,
        child: child,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// B. TIME ADJUSTER — [-] pill(XXm) [+]
// ═══════════════════════════════════════════════════════════════════

class _TimeAdjuster extends StatelessWidget {
  final String label;
  final bool isInfiniteMode;
  final int changeDirection;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _TimeAdjuster({
    required this.label,
    this.isInfiniteMode = false,
    required this.changeDirection,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        children: [
          _CircleButton(icon: Icons.remove, onTap: onDecrement),
          const SizedBox(width: 14),
          Expanded(
            child: _TimePill(
              label: label,
              isInfiniteMode: isInfiniteMode,
              changeDirection: changeDirection,
            ),
          ),
          const SizedBox(width: 14),
          _CircleButton(icon: Icons.add, onTap: onIncrement),
        ],
      ),
    );
  }
}

class _TimePill extends StatelessWidget {
  final String label;
  final bool isInfiniteMode;
  final int changeDirection;

  const _TimePill({
    required this.label,
    this.isInfiniteMode = false,
    required this.changeDirection,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        color: const Color(0xFF1A1A1A).withValues(alpha: 0.8),
        border: Border.all(color: const Color(0xFF2A2A2A), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(50),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Center(
            child: _AnimatedSlide(
              childKey: ValueKey<String>(
                isInfiniteMode ? 'infinite' : label,
              ),
              direction: changeDirection,
              child: isInfiniteMode
                  ? const Icon(
                      Icons.all_inclusive,
                      size: 26,
                      color: Colors.white,
                    )
                  : Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        decoration: TextDecoration.none,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF161616),
          border: Border.all(color: const Color(0xFF2A2A2A), width: 1),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// B. START BUTTON — full-width white pill
// ═══════════════════════════════════════════════════════════════════

class _StartButton extends StatelessWidget {
  final VoidCallback onTap;

  const _StartButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.play_arrow, color: Colors.black, size: 28),
              const SizedBox(width: 8),
              Text(
                'Start',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// C. FOR YOU — gallery carousel of focus templates (portrait cards)
// ═══════════════════════════════════════════════════════════════════

class _ForYouSection extends StatelessWidget {
  final ValueChanged<FocusTemplate> onTemplateTap;

  const _ForYouSection({required this.onTemplateTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'For you',
            style: AppTheme.sectionTitle,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 280,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: kFocusTemplates.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final template = kFocusTemplates[index];
              return _CarouselCard(
                template: template,
                onTap: () => onTemplateTap(template),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CarouselCard extends StatelessWidget {
  final FocusTemplate template;
  final VoidCallback onTap;

  const _CarouselCard({required this.template, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: SizedBox(
          width: 200,
          height: 280,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Procedural art background
              CustomPaint(painter: painterForArt(template.art)),

              // Bottom gradient scrim for text legibility
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black54,
                      Colors.black87,
                    ],
                    stops: [0.0, 0.4, 0.7, 1.0],
                  ),
                ),
              ),

              // Bottom-aligned content: Title → Duration → Start button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Title
                    Text(
                      template.title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        decoration: TextDecoration.none,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Duration
                    Text(
                      template.durationLabel,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.85),
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Start button (transparent white)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Start',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// LEAVE DIALOG — bottom sheet with hold-to-leave
// ═══════════════════════════════════════════════════════════════════

class _LeaveDialog extends StatelessWidget {
  final VoidCallback onLeave;

  const _LeaveDialog({required this.onLeave});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: 28,
            right: 28,
            top: 32,
            bottom: 32 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFFF3B30),
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.door_front_door_outlined,
              color: Color(0xFFFF3B30),
              size: 28,
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            'Leaving early?',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 10),

          // Subtitle
          Text(
            "Don't give up, there's a reason you started this",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: const Color(0xFFAEAEB2),
              height: 1.5,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 28),

          // Hold to leave button
          _HoldToLeaveButton(onComplete: onLeave),
          const SizedBox(height: 14),

          // Cancel button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFAEAEB2),
                decoration: TextDecoration.none,
              ),
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HoldToLeaveButton extends StatefulWidget {
  final VoidCallback onComplete;

  const _HoldToLeaveButton({required this.onComplete});

  @override
  State<_HoldToLeaveButton> createState() => _HoldToLeaveButtonState();
}

class _HoldToLeaveButtonState extends State<_HoldToLeaveButton>
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
                  color: const Color(0xFFFF3B30).withValues(alpha: 0.15),
                  border: Border.all(
                    color: const Color(0xFFFF3B30).withValues(alpha: 0.4),
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
                          color: const Color(0xFFFF3B30).withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        progress > 0 ? 'Keep holding...' : 'Hold to leave',
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFFF3B30),
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
