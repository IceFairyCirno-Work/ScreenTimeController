import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/screen_time_data.dart';
import '../../models/screen_timer_controller_metrics.dart';
import '../../services/screen_time_service.dart';
import '../../services/screen_timer_controller_score_calculator.dart';
import '../../theme/app_theme.dart';
import '../../widgets/home/metrics_row.dart';
import '../../widgets/shared/circle_icon_button.dart';

/// Full-screen score breakdown with radial gauge, sub-metric pills, and bars.
///
/// Rendered as an overlay inside [HomeScreen] so the bottom navigation bar
/// remains visible.
class ScoreBreakdownScreen extends StatefulWidget {
  final VoidCallback onClose;
  final ScreenTimerControllerMetrics metrics;
  final ScoreUsageBreakdown usage;
  final ScreenTimeData screenData;

  const ScoreBreakdownScreen({
    super.key,
    required this.onClose,
    required this.metrics,
    required this.usage,
    required this.screenData,
  });

  @override
  State<ScoreBreakdownScreen> createState() => _ScoreBreakdownScreenState();
}

class _ScoreBreakdownScreenState extends State<ScoreBreakdownScreen>
    with SingleTickerProviderStateMixin {
  static const _maxDayOffset = 6;

  final _screenTimeService = ScreenTimeService();
  late final AnimationController _barsController;
  late final Animation<double> _barsAnimation;
  int _dayOffset = 0;
  int? _historicalTotalMs;
  bool _loadingHistorical = false;

  @override
  void initState() {
    super.initState();
    _barsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _barsAnimation = CurvedAnimation(
      parent: _barsController,
      curve: Curves.easeOutCubic,
    );
    _barsController.forward();
    if (_dayOffset > 0) _loadHistoricalTotal();
  }

  @override
  void dispose() {
    _barsController.dispose();
    super.dispose();
  }

  DateTime get _selectedDay {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.subtract(Duration(days: _dayOffset));
  }

  bool get _isToday => _dayOffset == 0;

  String get _dateLabel {
    if (_isToday) return 'Today';
    final day = _selectedDay;
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${weekdays[day.weekday - 1]}, ${months[day.month - 1]} ${day.day}';
  }

  Future<void> _loadHistoricalTotal() async {
    setState(() => _loadingHistorical = true);
    final ms = await _screenTimeService.fetchDayTotalMs(_selectedDay);
    if (!mounted) return;
    setState(() {
      _historicalTotalMs = ms;
      _loadingHistorical = false;
    });
  }

  void _shiftDay(int delta) {
    final next = (_dayOffset + delta).clamp(0, _maxDayOffset);
    if (next == _dayOffset) return;
    setState(() {
      _dayOffset = next;
      _historicalTotalMs = null;
    });
    _barsController.forward(from: 0);
    if (next > 0) _loadHistoricalTotal();
  }

  Duration get _displayedScreenTime {
    if (_isToday) return widget.screenData.todayTotal;
    final ms = _historicalTotalMs;
    if (ms == null) return Duration.zero;
    return Duration(milliseconds: ms);
  }

  @override
  Widget build(BuildContext context) {
    final metrics = widget.metrics;
    final usage = widget.usage;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Material(
      color: AppTheme.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _ScoreBreakdownHeader(
              dateLabel: _dateLabel,
              onBack: widget.onClose,
              onPreviousDay: _dayOffset < _maxDayOffset
                  ? () => _shiftDay(1)
                  : null,
              onNextDay:
                  _dayOffset > 0 ? () => _shiftDay(-1) : null,
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: _barsAnimation,
                builder: (context, _) {
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(24, 8, 24, 8 + bottomInset + 72),
                    child: Column(
                      children: [
                        if (_isToday) ...[
                          _SemiCircularScoreGauge(
                            score: metrics.score,
                            animationProgress: _barsAnimation.value,
                          ),
                          const SizedBox(height: 12),
                          MetricsRow(
                            sleepScore: metrics.sleepScore,
                            focus: metrics.focus,
                            rest: metrics.rest,
                            showBracket: false,
                            animationProgress: _barsAnimation.value,
                          ),
                          const SizedBox(height: 28),
                          const _InsightBlock(),
                          const SizedBox(height: 28),
                          _AnalyticalBarsSection(
                            screenTime: _displayedScreenTime,
                            metrics: metrics,
                            usage: usage,
                            isLoading: false,
                            showSubCategoryBars: true,
                            animationProgress: _barsAnimation.value,
                          ),
                        ] else ...[
                          const SizedBox(height: 12),
                          Text(
                            'Daily screen time',
                            style: AppTheme.headingMedium.copyWith(fontSize: 18),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Detailed score breakdown is available for today.',
                            style: AppTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          _AnalyticalBarsSection(
                            screenTime: _displayedScreenTime,
                            metrics: metrics,
                            usage: usage,
                            isLoading: _loadingHistorical,
                            showSubCategoryBars: false,
                            animationProgress: _barsAnimation.value,
                          ),
                        ],
                      ],
                    ),
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

class _ScoreBreakdownHeader extends StatelessWidget {
  final String dateLabel;
  final VoidCallback onBack;
  final VoidCallback? onPreviousDay;
  final VoidCallback? onNextDay;

  const _ScoreBreakdownHeader({
    required this.dateLabel,
    required this.onBack,
    required this.onPreviousDay,
    required this.onNextDay,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Row(
        children: [
          CircleIconButton(icon: Icons.arrow_back, onTap: onBack),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ChevronButton(
                  icon: Icons.chevron_left,
                  onTap: onPreviousDay,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    dateLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _ChevronButton(
                  icon: Icons.chevron_right,
                  onTap: onNextDay,
                ),
              ],
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _ChevronButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _ChevronButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 22,
            color: enabled ? AppTheme.textPrimary : AppTheme.textHint,
          ),
        ),
      ),
    );
  }
}

class _SemiCircularScoreGauge extends StatelessWidget {
  final int score;
  final double animationProgress;

  const _SemiCircularScoreGauge({
    required this.score,
    required this.animationProgress,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final gaugeWidth = math.min(280.0, screenWidth - 48);
    const gaugeHeight = 150.0;
    final targetProgress = (score / 100).clamp(0.0, 1.0);
    final animatedProgress =
        (targetProgress * animationProgress).clamp(0.0, 1.0);

    return SizedBox(
      width: gaugeWidth,
      height: gaugeHeight + 52,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          CustomPaint(
            size: Size(gaugeWidth, gaugeHeight),
            painter: _SemiCircularGaugePainter(progress: animatedProgress),
          ),
          Positioned(
            top: gaugeHeight * 0.56,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '$score',
                  textAlign: TextAlign.center,
                  style: AppTheme.statNumber.copyWith(
                    fontSize: 52,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Score',
                  textAlign: TextAlign.center,
                  style: AppTheme.screenTimerControllerScoreLabel.copyWith(
                    fontSize: 14,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SemiCircularGaugePainter extends CustomPainter {
  final double progress;

  _SemiCircularGaugePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 14;
    const strokeWidth = 14.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = AppTheme.cardBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Semi-circle from left (π) through top to right (0).
    canvas.drawArc(rect, math.pi, math.pi, false, trackPaint);

    if (progress <= 0) return;

    final sweep = math.pi * progress;
    final progressPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          AppTheme.screenTimerControllerMintDim,
          AppTheme.screenTimerControllerMintGlow,
        ],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, math.pi, sweep, false, progressPaint);

    final glowPaint = Paint()
      ..color = AppTheme.screenTimerControllerMintGlow.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 4
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    canvas.drawArc(rect, math.pi, sweep, false, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _SemiCircularGaugePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _InsightBlock extends StatelessWidget {
  const _InsightBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What is your Score?',
          style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'Your Score combines signals from your sleep, focus, and rest into '
          'a single measure of how technology aligns with your wellbeing.',
          style: AppTheme.bodyMedium.copyWith(
            color: AppTheme.textSecondary,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

class _AnalyticalBarsSection extends StatelessWidget {
  final Duration screenTime;
  final ScreenTimerControllerMetrics metrics;
  final ScoreUsageBreakdown usage;
  final bool isLoading;
  final bool showSubCategoryBars;
  final double animationProgress;

  const _AnalyticalBarsSection({
    required this.screenTime,
    required this.metrics,
    required this.usage,
    required this.isLoading,
    required this.showSubCategoryBars,
    required this.animationProgress,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: CircularProgressIndicator(
            color: AppTheme.screenTimerControllerMint,
            strokeWidth: 2,
          ),
        ),
      );
    }

    final todayMinutes = screenTime.inMinutes;
    final screenRef =
        ScreenTimerControllerScoreCalculator.dailyScreenTimeReferenceMinutes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProgressBarBlock(
          title: 'Screen Time',
          subtitle: todayMinutes > 0
              ? '${_formatMinutes(todayMinutes)} today'
              : 'No screen time recorded',
          valueLabel: todayMinutes > 0
              ? '${_formatMinutes(todayMinutes)} / ${_formatMinutes(screenRef)}'
              : '0m',
          progress: todayMinutes > 0
              ? (todayMinutes / screenRef).clamp(0.0, 1.0)
              : 0,
          animationProgress: animationProgress,
          accentColor: AppTheme.screenTimerControllerMint,
        ),
        if (showSubCategoryBars) ...[
          const SizedBox(height: 20),
          _ProgressBarBlock(
            title: 'Sleep',
            subtitle:
                '${_formatMinutes(metrics.sleep)} phone use during 10pm–6am',
            valueLabel:
                '${_formatMinutes(metrics.sleep)} / ${_formatMinutes(ScreenTimerControllerScoreCalculator.nightWindowMinutes)}',
            progress: metrics.sleep > 0
                ? (metrics.sleep /
                        ScreenTimerControllerScoreCalculator.nightWindowMinutes)
                    .clamp(0.0, 1.0)
                : 0,
            animationProgress: animationProgress,
            accentColor: AppTheme.screenTimerControllerMintGlow,
            invertFill: true,
          ),
          const SizedBox(height: 20),
          _ProgressBarBlock(
            title: 'Focus',
            subtitle: todayMinutes > 0
                ? '${_formatMinutes(usage.distractionMinutes)} in distracting apps'
                : 'No distracting usage',
            valueLabel: todayMinutes > 0
                ? '${_formatMinutes(usage.distractionMinutes)} / ${_formatMinutes(todayMinutes)}'
                : '0m',
            progress: todayMinutes > 0
                ? (usage.distractionMinutes / todayMinutes).clamp(0.0, 1.0)
                : 0,
            animationProgress: animationProgress,
            accentColor: AppTheme.highlightBlue,
          ),
          const SizedBox(height: 20),
          _ProgressBarBlock(
            title: 'Rest',
            subtitle: todayMinutes > 0
                ? '${_formatMinutes(usage.top3Minutes)} in your top 3 apps'
                : 'Usage spread across apps',
            valueLabel: todayMinutes > 0
                ? '${_formatMinutes(usage.top3Minutes)} / ${_formatMinutes(todayMinutes)}'
                : '0m',
            progress: todayMinutes > 0
                ? (usage.top3Minutes / todayMinutes).clamp(0.0, 1.0)
                : 0,
            animationProgress: animationProgress,
            accentColor: AppTheme.screenTimerControllerMintDim,
          ),
        ],
      ],
    );
  }

  static String _formatMinutes(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final rem = minutes % 60;
    if (rem == 0) return '${hours}h';
    return '${hours}h ${rem}m';
  }
}

class _ProgressBarBlock extends StatelessWidget {
  final String title;
  final String subtitle;
  final String valueLabel;
  final double progress;
  final double animationProgress;
  final Color accentColor;
  final bool invertFill;

  const _ProgressBarBlock({
    required this.title,
    required this.subtitle,
    required this.valueLabel,
    required this.progress,
    required this.animationProgress,
    required this.accentColor,
    this.invertFill = false,
  });

  @override
  Widget build(BuildContext context) {
    final target = invertFill ? (1 - progress).clamp(0.0, 1.0) : progress;
    final fill = (target * animationProgress).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              valueLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: AppTheme.bodySmall),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 8,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: AppTheme.surfaceLight),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: fill.clamp(0.0, 1.0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accentColor.withValues(alpha: 0.7),
                          accentColor,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
