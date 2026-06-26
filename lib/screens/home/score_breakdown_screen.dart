import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/device_pickup_times.dart';
import '../../models/screen_time_data.dart';
import '../../models/screen_timer_controller_metrics.dart';
import '../../services/screen_time_service.dart';
import '../../services/screen_timer_controller_score_calculator.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../widgets/home/metrics_row.dart';
import '../../widgets/shared/circle_icon_button.dart';
import '../../widgets/shared/relative_progress_bar.dart';

/// Full-screen score breakdown with radial gauge, sub-metric pills, and bars.
///
/// Rendered as an overlay inside [HomeScreen] so the bottom navigation bar
/// remains visible.
class ScoreBreakdownScreen extends StatefulWidget {
  final VoidCallback onClose;
  final ScreenTimerControllerMetrics metrics;
  final ScoreUsageBreakdown usage;
  final ScoreBreakdownBaselines baselines;
  final ScreenTimeData screenData;
  final String? distractingHabit;
  final Set<String> distractingFolderPackages;
  final Set<String> alwaysAllowedPackages;

  const ScoreBreakdownScreen({
    super.key,
    required this.onClose,
    required this.metrics,
    required this.usage,
    required this.baselines,
    required this.screenData,
    this.distractingHabit,
    this.distractingFolderPackages = const {},
    this.alwaysAllowedPackages = const {},
  });

  @override
  State<ScoreBreakdownScreen> createState() => _ScoreBreakdownScreenState();
}

class _ScoreBreakdownScreenState extends State<ScoreBreakdownScreen>
    with SingleTickerProviderStateMixin {
  static const _maxDayOffset = 6;
  static const _scrollHorizontalPadding = 24.0;

  final _screenTimeService = ScreenTimeService();
  late final AnimationController _barsController;
  late final Animation<double> _barsAnimation;
  int _dayOffset = 0;
  int? _historicalTotalMs;
  bool _loadingHistorical = false;
  DevicePickupTimes? _pickupTimes;
  bool _loadingPickups = false;
  double _avgFirstPickupMinutes = 0;
  double _avgLastPickupMinutes = 0;
  ScoreBreakdownBaselines? _rollingBaselines;
  final _calculator = ScreenTimerControllerScoreCalculator();

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
    _loadWeekPickupBaselines();
    _loadRollingBaselines();
    _loadSelectedDayData();
  }

  ScoreBreakdownBaselines get _effectiveBaselines {
    final merged = _rollingBaselines == null
        ? widget.baselines
        : _calculator.mergeBaselines(
            primary: widget.baselines,
            rolling: _rollingBaselines!,
          );
    return ScoreBreakdownBaselines(
      avgScreenMinutes: merged.avgScreenMinutes,
      avgSleepMinutes: merged.avgSleepMinutes,
      avgDistractionMinutes: merged.avgDistractionMinutes,
      avgTop3Minutes: merged.avgTop3Minutes,
      avgFirstPickupMinutes: _avgFirstPickupMinutes > 0
          ? _avgFirstPickupMinutes
          : merged.avgFirstPickupMinutes,
      avgLastPickupMinutes: _avgLastPickupMinutes > 0
          ? _avgLastPickupMinutes
          : merged.avgLastPickupMinutes,
    );
  }

  Future<void> _loadRollingBaselines() async {
    final screenData = widget.screenData;
    if (!screenData.hasPermission) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final priorDayResults = await Future.wait(
      List.generate(6, (offset) async {
        final day = today.subtract(Duration(days: offset + 1));
        final results = await Future.wait([
          _screenTimeService.fetchDayTotalMs(day),
          _screenTimeService.fetchDayNightUsageMinutes(day),
          _screenTimeService.fetchDayApps(day),
        ]);

        final totalMs = results[0] as int?;
        if (totalMs == null || totalMs <= 0) return null;

        return PriorDayUsageSnapshot(
          screenMinutes: totalMs / 60000.0,
          nightMinutes: (results[1] as int?)?.toDouble() ?? 0,
          apps: results[2] as List<AppUsageItem>,
        );
      }),
    );

    final priorDays = priorDayResults.whereType<PriorDayUsageSnapshot>().toList();

    if (!mounted) return;
    if (priorDays.isEmpty) return;

    final rolling = _calculator.rollingBaselines(
      priorDays: priorDays,
      distractingHabit: widget.distractingHabit,
      distractingFolderPackages: widget.distractingFolderPackages,
      alwaysAllowedPackages: widget.alwaysAllowedPackages,
    );

    setState(() => _rollingBaselines = rolling);
    _barsController.forward(from: 0);
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

  Future<void> _loadSelectedDayData() async {
    final loadingHistorical = _dayOffset > 0;
    setState(() {
      if (loadingHistorical) _loadingHistorical = true;
      _loadingPickups = true;
      if (loadingHistorical) _historicalTotalMs = null;
      _pickupTimes = null;
    });

    final day = _selectedDay;
    final msFuture = loadingHistorical
        ? _screenTimeService.fetchDayTotalMs(day)
        : Future<int?>.value(null);
    final results = await Future.wait([
      msFuture,
      _screenTimeService.fetchDayPickupTimes(day),
    ]);

    if (!mounted) return;
    setState(() {
      if (loadingHistorical) {
        _historicalTotalMs = results[0] as int?;
        _loadingHistorical = false;
      }
      _pickupTimes = results[1] as DevicePickupTimes;
      _loadingPickups = false;
    });
  }

  Future<void> _loadWeekPickupBaselines() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - DateTime.monday));

    final firsts = <double>[];
    final lasts = <double>[];
    // Prior days only — today is the reading, not the baseline.
    for (var i = 0; i < today.weekday - 1; i++) {
      final day = monday.add(Duration(days: i));
      final pickups = await _screenTimeService.fetchDayPickupTimes(day);
      final first = pickups.firstPickup;
      final last = pickups.lastPickup;
      if (first != null) {
        firsts.add(RelativeProgressBar.minutesSinceMidnight(first));
      }
      if (last != null) {
        lasts.add(RelativeProgressBar.minutesSinceMidnight(last));
      }
    }

    // Monday (or no prior-week pickups): fall back to the last 6 days.
    if (firsts.isEmpty || lasts.isEmpty) {
      for (var offset = 1; offset <= 6; offset++) {
        final day = today.subtract(Duration(days: offset));
        final pickups = await _screenTimeService.fetchDayPickupTimes(day);
        final first = pickups.firstPickup;
        final last = pickups.lastPickup;
        if (first != null) {
          firsts.add(RelativeProgressBar.minutesSinceMidnight(first));
        }
        if (last != null) {
          lasts.add(RelativeProgressBar.minutesSinceMidnight(last));
        }
      }
    }

    if (!mounted) return;
    setState(() {
      if (firsts.isNotEmpty) {
        _avgFirstPickupMinutes =
            firsts.reduce((a, b) => a + b) / firsts.length;
      }
      if (lasts.isNotEmpty) {
        _avgLastPickupMinutes = lasts.reduce((a, b) => a + b) / lasts.length;
      }
    });
  }

  void _shiftDay(int delta) {
    final next = (_dayOffset + delta).clamp(0, _maxDayOffset);
    if (next == _dayOffset) return;
    setState(() => _dayOffset = next);
    _barsController.forward(from: 0);
    _loadSelectedDayData();
  }

  Duration get _displayedScreenTime {
    if (_isToday) return widget.screenData.todayTotal;
    final ms = _historicalTotalMs;
    if (ms == null) return Duration.zero;
    return Duration(milliseconds: ms);
  }

  /// Inset for score/insight content above the progress bars.
  Widget _contentInset(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _scrollHorizontalPadding),
      child: child,
    );
  }

  /// Wider horizontal inset so progress tracks span more of the screen.
  Widget _wideProgressBars(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: RelativeProgressBar.trackScreenInset,
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final metrics = widget.metrics;
    final usage = widget.usage;
    final baselines = _effectiveBaselines;
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
                    padding: EdgeInsets.only(
                      top: 8,
                      bottom: 8 + bottomInset + 72,
                    ),
                    child: Responsive.centeredContent(
                      context: context,
                      child: Column(
                      children: [
                        if (_isToday) ...[
                          _contentInset(
                            _SemiCircularScoreGauge(
                              score: metrics.score,
                              animationProgress: _barsAnimation.value,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _contentInset(
                            MetricsRow(
                              sleepScore: metrics.sleepScore,
                              focus: metrics.focus,
                              rest: metrics.rest,
                              showBracket: false,
                              animationProgress: _barsAnimation.value,
                            ),
                          ),
                          const SizedBox(height: 28),
                          _wideProgressBars(const _InsightBlock()),
                          const SizedBox(height: 28),
                          _wideProgressBars(
                            _AnalyticalBarsSection(
                              screenTime: _displayedScreenTime,
                              metrics: metrics,
                              usage: usage,
                              baselines: baselines,
                              avgFirstPickupMinutes: _avgFirstPickupMinutes,
                              avgLastPickupMinutes: _avgLastPickupMinutes,
                              pickupTimes: _pickupTimes,
                              loadingPickups: _loadingPickups,
                              isLoading: false,
                              showSubCategoryBars: true,
                              animationProgress: _barsAnimation.value,
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 12),
                          _contentInset(
                            Text(
                              'Daily screen time',
                              style: AppTheme.headingMedium.copyWith(fontSize: 18),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _contentInset(
                            Text(
                              'Detailed score breakdown is available for today.',
                              style: AppTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _wideProgressBars(
                            _AnalyticalBarsSection(
                              screenTime: _displayedScreenTime,
                              metrics: metrics,
                              usage: usage,
                              baselines: baselines,
                              avgFirstPickupMinutes: _avgFirstPickupMinutes,
                              avgLastPickupMinutes: _avgLastPickupMinutes,
                              pickupTimes: _pickupTimes,
                              loadingPickups: _loadingPickups,
                              isLoading: _loadingHistorical,
                              showSubCategoryBars: false,
                              animationProgress: _barsAnimation.value,
                            ),
                          ),
                        ],
                      ],
                    ),
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
    final gaugeWidth = math.min(
      280.0,
      math.min(screenWidth - 48, Responsive.contentMaxWidth(context)),
    );
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
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$score',
                    textAlign: TextAlign.center,
                    style: AppTheme.statNumber.copyWith(
                      fontSize: 52,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                    ),
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
  final ScoreBreakdownBaselines baselines;
  final double avgFirstPickupMinutes;
  final double avgLastPickupMinutes;
  final DevicePickupTimes? pickupTimes;
  final bool loadingPickups;
  final bool isLoading;
  final bool showSubCategoryBars;
  final double animationProgress;

  const _AnalyticalBarsSection({
    required this.screenTime,
    required this.metrics,
    required this.usage,
    required this.baselines,
    required this.avgFirstPickupMinutes,
    required this.avgLastPickupMinutes,
    required this.pickupTimes,
    required this.loadingPickups,
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
    final baselines = this.baselines;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RelativeProgressBar(
          title: 'Screen Time',
          todayLabel: todayMinutes > 0
              ? RelativeProgressBar.formatMinutes(todayMinutes)
              : '0m',
          currentValue: todayMinutes.toDouble(),
          averageValue: baselines.avgScreenMinutes,
          isLowerBetter: true,
          minimumAverageWhenEmpty: RelativeProgressBar.durationMinimumBaseline,
          animationProgress: animationProgress,
        ),
        const SizedBox(height: RelativeProgressBar.titleToBarSpacing),
        _buildPickupProgressBar(
          title: 'First Pickup',
          pickup: pickupTimes?.firstPickup,
          avgMinutes: avgFirstPickupMinutes,
          isLowerBetter: false,
        ),
        const SizedBox(height: RelativeProgressBar.titleToBarSpacing),
        _buildPickupProgressBar(
          title: 'Last Pickup',
          pickup: pickupTimes?.lastPickup,
          avgMinutes: avgLastPickupMinutes,
          isLowerBetter: true,
        ),
        if (showSubCategoryBars) ...[
          const SizedBox(height: RelativeProgressBar.titleToBarSpacing),
          RelativeProgressBar(
            title: 'Sleep',
            todayLabel: RelativeProgressBar.formatMinutes(metrics.sleep),
            currentValue: metrics.sleep.toDouble(),
            averageValue: baselines.avgSleepMinutes,
            isLowerBetter: true,
            minimumAverageWhenEmpty: RelativeProgressBar.durationMinimumBaseline,
            animationProgress: animationProgress,
          ),
          const SizedBox(height: RelativeProgressBar.titleToBarSpacing),
          RelativeProgressBar(
            title: 'Focus',
            todayLabel: todayMinutes > 0
                ? RelativeProgressBar.formatMinutes(usage.distractionMinutes)
                : '0m',
            currentValue: usage.distractionMinutes.toDouble(),
            averageValue: baselines.avgDistractionMinutes,
            isLowerBetter: true,
            minimumAverageWhenEmpty: RelativeProgressBar.durationMinimumBaseline,
            animationProgress: animationProgress,
          ),
          const SizedBox(height: RelativeProgressBar.titleToBarSpacing),
          RelativeProgressBar(
            title: 'Rest',
            todayLabel: todayMinutes > 0
                ? RelativeProgressBar.formatMinutes(usage.top3Minutes)
                : '0m',
            currentValue: usage.top3Minutes.toDouble(),
            averageValue: baselines.avgTop3Minutes,
            isLowerBetter: true,
            minimumAverageWhenEmpty: RelativeProgressBar.durationMinimumBaseline,
            animationProgress: animationProgress,
          ),
        ],
      ],
    );
  }

  Widget _buildPickupProgressBar({
    required String title,
    required DateTime? pickup,
    required double avgMinutes,
    required bool isLowerBetter,
  }) {
    if (loadingPickups) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              color: AppTheme.screenTimerControllerMint,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    if (pickup == null || avgMinutes <= 0) {
      return Row(
        children: [
          Text(
            title,
            style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          Text(
            '—',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textHint,
              fontSize: 12,
            ),
          ),
        ],
      );
    }

    return RelativeProgressBar(
      title: title,
      todayLabel: RelativeProgressBar.formatTime24(pickup),
      currentValue: RelativeProgressBar.minutesSinceMidnight(pickup),
      averageValue: avgMinutes,
      isLowerBetter: isLowerBetter,
      animationProgress: animationProgress,
    );
  }
}
