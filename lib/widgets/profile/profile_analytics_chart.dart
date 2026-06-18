import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/screen_time_data.dart';
import '../../theme/app_theme.dart';

/// Analytics section: 7-day screen time trend with weekday labels on the X axis.
class ProfileAnalyticsSection extends StatelessWidget {
  final List<double> dailyHours;
  final List<String> dayLabels;
  final double averageHours;
  final int measuredDayCount;
  final bool isEstimated;
  final bool isLoading;

  const ProfileAnalyticsSection({
    super.key,
    this.dailyHours = const [],
    this.dayLabels = const [],
    this.averageHours = 0,
    this.measuredDayCount = 0,
    this.isEstimated = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WEEK SCREEN TIME',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textHint,
            letterSpacing: 1.2,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatusCallout(
                averageHours: averageHours,
                measuredDayCount: measuredDayCount,
                isEstimated: isEstimated,
                isLoading: isLoading,
              ),
            ),
            if (isEstimated && !isLoading) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.screenTimerControllerPillBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.surfaceLight.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  'Estimated',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textHint,
                    letterSpacing: 0.3,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 200,
          child: isLoading
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.screenTimerControllerMint,
                    ),
                  ),
                )
              : _TrendChart(
                  dailyHours: dailyHours,
                  dayLabels: dayLabels,
                ),
        ),
      ],
    );
  }
}

class _StatusCallout extends StatelessWidget {
  final double averageHours;
  final int measuredDayCount;
  final bool isEstimated;
  final bool isLoading;

  const _StatusCallout({
    required this.averageHours,
    required this.measuredDayCount,
    required this.isEstimated,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Text(
        'Loading your last 7 days…',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: AppTheme.textSecondary,
          height: 1.5,
          decoration: TextDecoration.none,
        ),
      );
    }

    final formatted = ScreenTimeData.formatDuration(
      Duration(minutes: (averageHours * 60).round()),
    );

    final dayWord = measuredDayCount == 1 ? 'day' : 'days';
    final prefix = measuredDayCount > 0 && !isEstimated
        ? 'Your average across $measuredDayCount measured $dayWord is '
        : 'Your estimated daily average is ';

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: AppTheme.textSecondary,
          height: 1.5,
          decoration: TextDecoration.none,
        ),
        children: [
          TextSpan(text: prefix),
          TextSpan(
            text: formatted,
            style: const TextStyle(
              color: AppTheme.screenTimerControllerMint,
              fontWeight: FontWeight.w600,
            ),
          ),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  final List<double> dailyHours;
  final List<String> dayLabels;

  const _TrendChart({
    required this.dailyHours,
    required this.dayLabels,
  });

  @override
  Widget build(BuildContext context) {
    if (dailyHours.isEmpty || dayLabels.isEmpty) {
      return Center(
        child: Text(
          'No screen time data yet',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: AppTheme.textHint,
            decoration: TextDecoration.none,
          ),
        ),
      );
    }

    final maxValue = dailyHours.reduce((a, b) => a > b ? a : b);
    final maxY = _chartMaxY(maxValue);
    final yTicks = _yTicksFor(maxY);

    final spots = [
      for (var i = 0; i < dailyHours.length; i++)
        FlSpot(i.toDouble(), dailyHours[i].clamp(0, maxY)),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 8, right: 40, bottom: 4),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY,
          minX: 0,
          maxX: (dayLabels.length - 1).toDouble(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: null,
            checkToShowHorizontalLine: (v) => yTicks.contains(v),
            getDrawingHorizontalLine: (v) => FlLine(
              color: AppTheme.cardBorder.withValues(alpha: 0.4),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: null,
                getTitlesWidget: (value, _) {
                  final label = _yLabelFor(value, yTicks);
                  if (label == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textHint,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: 1,
                getTitlesWidget: (value, _) {
                  final i = value.round();
                  if (i < 0 || i >= dayLabels.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      dayLabels[i],
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.35,
              color: AppTheme.textPrimary,
              barWidth: 2,
              dashArray: [5, 4],
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.surfaceLight.withValues(alpha: 0.7),
                    AppTheme.surface.withValues(alpha: 0.2),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ],
          lineTouchData: const LineTouchData(enabled: false),
        ),
      ),
    );
  }

  static double _chartMaxY(double maxValue) {
    if (maxValue <= 0) return 2;
    if (maxValue <= 2) return 2;
    if (maxValue <= 5) return 5;
    if (maxValue <= 8) return 8;
    if (maxValue <= 12) return 12;
    return (maxValue * 1.15).ceilToDouble();
  }

  static List<double> _yTicksFor(double maxY) {
    if (maxY <= 2) return const [0, 1, 2];
    if (maxY <= 5) return const [0, 2, 5];
    if (maxY <= 8) return const [0, 2, 5, 8];
    if (maxY <= 12) return const [0, 3, 6, 9, 12];
    final step = (maxY / 4).ceilToDouble().clamp(2.0, 4.0);
    final ticks = <double>[0];
    var v = step;
    while (v < maxY) {
      ticks.add(v);
      v += step;
    }
    ticks.add(maxY);
    return ticks;
  }

  String? _yLabelFor(double value, List<double> ticks) {
    if (!ticks.any((tick) => (tick - value).abs() < 0.01)) return null;
    if ((value * 2).roundToDouble() == value * 2) {
      return value == value.roundToDouble()
          ? '${value.round()}h'
          : '${value.toStringAsFixed(1)}h';
    }
    return null;
  }
}
