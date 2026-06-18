import 'package:flutter/material.dart';

class HomeHero extends StatelessWidget {
  /// Asset path for the achievement gem shown in the hero.
  final String imageAsset;

  /// Vertical pixel offset that mirrors the scroll position. Positive when the
  /// user scrolls down — the hero image drifts upward to follow the content.
  final double parallaxOffset;

  /// Resting downward shift for the hero artwork (top bar stays fixed above).
  final double contentOffset;

  const HomeHero({
    super.key,
    this.imageAsset = 'assets/images/first_gem.png',
    this.parallaxOffset = 0,
    this.contentOffset = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Transform.translate(
            // Drift the image downward at rest; scroll pushes it back up.
            offset: Offset(0, contentOffset - parallaxOffset),
            child: Transform.scale(
              // Extra vertical headroom so translation never reveals gaps.
              scale: 1.18,
              child: Image.asset(
                imageAsset,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
