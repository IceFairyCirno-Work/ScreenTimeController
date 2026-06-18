class ScreenTimerControllerMetrics {
  final int score;
  /// Night usage minutes (22:00–06:00) for display.
  final int sleep;
  /// Internal 0–100 score used in the overall average.
  final int sleepScore;
  final int focus;
  final int rest;

  const ScreenTimerControllerMetrics({
    required this.score,
    required this.sleep,
    this.sleepScore = 0,
    required this.focus,
    required this.rest,
  });

  static const zero = ScreenTimerControllerMetrics(
    score: 0,
    sleep: 0,
    sleepScore: 0,
    focus: 0,
    rest: 0,
  );
}
