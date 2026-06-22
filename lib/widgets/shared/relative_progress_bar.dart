import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Dual-sided progress bar anchored at the center AVG tick (50% width).
///
/// The fill represents **change relative to average** — not absolute value.
/// Center = on average (zero delta). Increase extends right; decrease extends
/// left. Brand mint = large change; orange = small change.
class RelativeProgressBar extends StatelessWidget {
  static const _trackHeight = 8.0;
  static const _trackRadius = 4.0;
  static const _centerTickWidth = 2.0;
  static const _centerTickHeight = 10.0;

  final String title;
  final String todayLabel;
  final double currentValue;
  final double averageValue;
  final bool isLowerBetter;
  final String centerLabel;
  final Color largeChangeColor;
  final Color smallChangeColor;
  final double animationProgress;
  /// Relative change that maps to ~half of one bar side (soft-saturated).
  final double referenceChangeRatio;
  /// When [averageValue] is 0 but [currentValue] > 0, compare against this floor.
  final double minimumAverageWhenEmpty;
  /// Visual delta magnitude at or above this uses [largeChangeColor].
  final double largeChangeThreshold;

  const RelativeProgressBar({
    super.key,
    required this.title,
    required this.todayLabel,
    required this.currentValue,
    required this.averageValue,
    required this.isLowerBetter,
    this.centerLabel = 'AVG',
    this.largeChangeColor = AppTheme.screenTimerControllerMint,
    this.smallChangeColor = AppTheme.screenTimerControllerFlame,
    this.animationProgress = 1.0,
    this.referenceChangeRatio = 0.32,
    this.minimumAverageWhenEmpty = 0,
    this.largeChangeThreshold = 0.4,
  });

  static const titleToBarSpacing = 20.0;
  static const barAreaHeight = 24.0;
  /// Horizontal inset from the screen edge for the progress track.
  static const trackScreenInset = 8.0;
  /// Baseline floor for minute-based metrics when no history exists yet.
  static const durationMinimumBaseline = 1.0;
  static const _minVisibleExtentRatio = 0.18;
  /// Portion of each fill (from the outer tip inward) kept at full opacity.
  static const _solidTipFraction = 0.72;

  static String formatMinutes(num minutes) {
    final total = minutes.abs().round();
    if (total < 60) return '${total}m';
    final hours = total ~/ 60;
    final rem = total % 60;
    if (rem == 0) return '${hours}h';
    return '${hours}h ${rem}m';
  }

  /// 24-hour clock label, e.g. `00:12`, `14:05`.
  static String formatTime24(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Minutes elapsed since local midnight (for time-of-day bar values).
  static double minutesSinceMidnight(DateTime time) =>
      time.hour * 60 + time.minute.toDouble();

  /// Normalized deviation from average. 0 = at avg, -1 = zero, +1 = 2× avg.
  /// Maps relative change to [-1, 1] with soft saturation so magnitudes stay distinct.
  @visibleForTesting
  static double visualDeltaRatio(
    double deltaRatio, {
    double referenceChangeRatio = 0.5,
  }) {
    if (deltaRatio.isNaN || deltaRatio.isInfinite) return 0;
    if (referenceChangeRatio <= 0) return 0;
    final scaled = deltaRatio / referenceChangeRatio;
    return scaled / (1 + scaled.abs());
  }

  double get _effectiveAverage => effectiveAverage(
        averageValue: averageValue,
        currentValue: currentValue,
        minimumAverageWhenEmpty: minimumAverageWhenEmpty,
      );

  @visibleForTesting
  static double effectiveAverage({
    required double averageValue,
    required double currentValue,
    required double minimumAverageWhenEmpty,
  }) {
    if (averageValue > 0) return averageValue;
    if (minimumAverageWhenEmpty > 0 && currentValue > 0) {
      return minimumAverageWhenEmpty;
    }
    return 0;
  }

  double get _deltaRatio {
    final avg = _effectiveAverage;
    if (avg <= 0) return 0.0;
    if (currentValue.isNaN) return 0.0;
    return (currentValue - avg) / avg;
  }

  double get _visualDeltaRatio =>
      visualDeltaRatio(_deltaRatio, referenceChangeRatio: referenceChangeRatio);

  double get _animatedDeltaRatio {
    var ratio = _visualDeltaRatio * animationProgress.clamp(0.0, 1.0);
    if (_delta.abs() >= 0.5 && ratio != 0 && ratio.abs() < _minVisibleExtentRatio) {
      ratio = _minVisibleExtentRatio * (ratio > 0 ? 1 : -1);
    }
    return ratio;
  }

  double get _delta => currentValue - _effectiveAverage;

  Color _colorForMagnitude(double visualMagnitude) {
    return changeColorForMagnitude(
      visualMagnitude: visualMagnitude,
      threshold: largeChangeThreshold,
      largeChangeColor: largeChangeColor,
      smallChangeColor: smallChangeColor,
    );
  }

  @visibleForTesting
  static Color changeColorForMagnitude({
    required double visualMagnitude,
    required double threshold,
    required Color largeChangeColor,
    required Color smallChangeColor,
  }) {
    if (visualMagnitude >= threshold) return largeChangeColor;
    return smallChangeColor;
  }

  @override
  Widget build(BuildContext context) {
    final statStyle = AppTheme.bodySmall.copyWith(
      color: AppTheme.textSecondary,
      fontSize: 12,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              title,
              style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                todayLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: statStyle,
              ),
            ),
            _DeltaBadge(
              delta: _delta,
              changeColor: _colorForMagnitude(_visualDeltaRatio.abs()),
              style: statStyle,
            ),
          ],
        ),
        const SizedBox(height: titleToBarSpacing),
        SizedBox(
          height: barAreaHeight,
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final trackWidth = constraints.maxWidth;
              final centerX = trackWidth * 0.5;
              final fills = _buildFillSpecs(
                centerX: centerX,
                deltaRatio: _animatedDeltaRatio,
              );

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: _trackHeight,
                    child: _DualSidedTrack(
                      trackWidth: trackWidth,
                      fills: fills,
                    ),
                  ),
                  Positioned(
                    top: -2,
                    left: 0,
                    right: 0,
                    child: Center(child: _CenterTick(label: centerLabel)),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  List<_FillSpec> _buildFillSpecs({
    required double centerX,
    required double deltaRatio,
  }) {
    return _directionalFills(centerX: centerX, deltaRatio: deltaRatio);
  }

  /// Increase (delta > 0) always fills right; decrease fills left.
  /// Colour reflects change magnitude (mint = large, orange = small).
  List<_FillSpec> _directionalFills({
    required double centerX,
    required double deltaRatio,
  }) {
    if (deltaRatio.abs() < 0.0001) return const [];

    final extent = deltaRatio.abs().clamp(0.0, 1.0) * centerX;
    if (extent <= 0) return const [];

    final color = _colorForMagnitude(deltaRatio.abs());
    final isIncrease = deltaRatio > 0;

    if (isIncrease) {
      return [
        _FillSpec(
          left: centerX,
          width: extent,
          color: color,
          fadeFromCenter: true,
          extendsLeft: false,
        ),
      ];
    }

    return [
      _FillSpec(
        left: centerX - extent,
        width: extent,
        color: color,
        fadeFromCenter: true,
        extendsLeft: true,
      ),
    ];
  }
}

class _DeltaBadge extends StatelessWidget {
  final double delta;
  final Color changeColor;
  final TextStyle style;

  const _DeltaBadge({
    required this.delta,
    required this.changeColor,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    if (delta.abs() < 0.5) {
      return Text(
        '—',
        style: style.copyWith(color: AppTheme.textHint),
      );
    }

    final arrow = delta < 0 ? '▼' : '▲';

    return Text(
      '$arrow ${RelativeProgressBar.formatMinutes(delta)}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style.copyWith(color: changeColor),
    );
  }
}

class _FillSpec {
  final double left;
  final double width;
  final Color color;
  final bool fadeFromCenter;
  final bool extendsLeft;

  const _FillSpec({
    required this.left,
    required this.width,
    required this.color,
    required this.fadeFromCenter,
    required this.extendsLeft,
  });
}

class _DualSidedTrack extends StatelessWidget {
  final double trackWidth;
  final List<_FillSpec> fills;

  const _DualSidedTrack({
    required this.trackWidth,
    required this.fills,
  });

  @override
  Widget build(BuildContext context) {
    final halfWidth = trackWidth * 0.5;

    return ClipRRect(
      borderRadius: BorderRadius.circular(RelativeProgressBar._trackRadius),
      child: SizedBox(
        height: RelativeProgressBar._trackHeight,
        width: trackWidth,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Row(
              children: [
                SizedBox(
                  width: halfWidth,
                  child: const ColoredBox(color: AppTheme.surfaceLight),
                ),
                SizedBox(
                  width: halfWidth,
                  child: const ColoredBox(color: AppTheme.surface),
                ),
              ],
            ),
            for (final fill in fills)
              if (fill.width > 0)
                Positioned(
                  left: fill.left,
                  top: 0,
                  bottom: 0,
                  width: fill.width,
                  child: _GradientFill(spec: fill),
                ),
          ],
        ),
      ),
    );
  }
}

class _GradientFill extends StatelessWidget {
  final _FillSpec spec;

  const _GradientFill({required this.spec});

  BorderRadius get _tipRadius {
    final r = Radius.circular(RelativeProgressBar._trackRadius);
    if (spec.extendsLeft) {
      return BorderRadius.horizontal(left: r);
    }
    return BorderRadius.horizontal(right: r);
  }

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      borderRadius: _tipRadius,
      gradient: spec.fadeFromCenter ? _fillGradient(spec) : null,
      color: spec.fadeFromCenter ? null : spec.color,
    );

    return ClipRRect(
      borderRadius: _tipRadius,
      child: DecoratedBox(decoration: decoration),
    );
  }

  /// Keeps a long solid cap at the outer tip; fades only near the AVG anchor.
  LinearGradient _fillGradient(_FillSpec spec) {
    final fadeStop =
        (1 - RelativeProgressBar._solidTipFraction).clamp(0.0, 0.95);
    if (spec.extendsLeft) {
      return LinearGradient(
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
        stops: [0, fadeStop, 1],
        colors: [
          spec.color.withValues(alpha: 0),
          spec.color.withValues(alpha: 0.2),
          spec.color,
        ],
      );
    }
    return LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      stops: [0, fadeStop, 1],
      colors: [
        spec.color.withValues(alpha: 0),
        spec.color.withValues(alpha: 0.2),
        spec.color,
      ],
    );
  }
}

class _CenterTick extends StatelessWidget {
  final String label;

  const _CenterTick({required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: RelativeProgressBar._centerTickWidth,
          height: RelativeProgressBar._centerTickHeight,
          decoration: BoxDecoration(
            color: AppTheme.accent,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          textAlign: TextAlign.center,
          style: AppTheme.bodySmall.copyWith(
            letterSpacing: 0.5,
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: AppTheme.textHint,
          ),
        ),
      ],
    );
  }
}
