import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Vertical slot-style counter for lifetime years on the onboarding result page.
class LifetimeYearsWheel extends StatefulWidget {
  final int targetYears;
  final bool animate;
  final TextStyle numberStyle;
  final Gradient gradient;
  final String suffix;

  const LifetimeYearsWheel({
    super.key,
    required this.targetYears,
    required this.animate,
    required this.numberStyle,
    required this.gradient,
    this.suffix = ' years',
  });

  @override
  State<LifetimeYearsWheel> createState() => _LifetimeYearsWheelState();
}

class _LifetimeYearsWheelState extends State<LifetimeYearsWheel>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 2400);

  late final AnimationController _controller;
  late final Animation<double> _animation;
  double? _numberWidth;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    if (widget.animate) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(LifetimeYearsWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.targetYears != oldWidget.targetYears) {
      _numberWidth = null;
    }
    if (widget.animate && !oldWidget.animate) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _measureNumberWidth(TextStyle style) {
    var maxWidth = 0.0;
    for (var i = 0; i <= widget.targetYears; i++) {
      final painter = TextPainter(
        text: TextSpan(text: '$i', style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      maxWidth = math.max(maxWidth, painter.width);
    }
    // Avoid sub-pixel clipping on the widest multi-digit values.
    return maxWidth.ceilToDouble() + 4;
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.numberStyle.copyWith(color: Colors.white);
    final itemHeight = style.fontSize! * (style.height ?? 1.0);
    _numberWidth ??= _measureNumberWidth(style);

    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => widget.gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          final scrollIndex = _animation.value * widget.targetYears;

          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              ClipRect(
                child: SizedBox(
                  width: _numberWidth,
                  height: itemHeight,
                  child: Transform.translate(
                    offset: Offset(0, -scrollIndex * itemHeight),
                    child: Column(
                      children: List.generate(
                        widget.targetYears + 1,
                        (index) => SizedBox(
                          height: itemHeight,
                          width: _numberWidth,
                          child: Center(
                            child: Text(
                              '$index',
                              style: style,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              softWrap: false,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Text(widget.suffix, style: style),
            ],
          );
        },
      ),
    );
  }
}

/// Pre-built styling for the onboarding lifetime years wheel.
class OnboardingLifetimeYearsWheel extends StatelessWidget {
  final double lifetimeYears;
  final bool animate;
  final String suffix;

  const OnboardingLifetimeYearsWheel({
    super.key,
    required this.lifetimeYears,
    required this.animate,
    this.suffix = ' years',
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: LifetimeYearsWheel(
        targetYears: lifetimeYears.round().clamp(0, 999),
        animate: animate,
        suffix: suffix,
        numberStyle: AppTheme.statNumber.copyWith(
          fontSize: 56,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
        gradient: AppTheme.purpleBlueGradient,
      ),
    );
  }
}
