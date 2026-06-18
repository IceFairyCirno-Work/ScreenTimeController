import '../models/screen_timer_controller_metrics.dart';
import '../models/screen_time_data.dart';

/// ScreenTimerController wellness metrics derived from real screen-time data.
///
/// Score = average of sleepScore, focus, and rest (each 0–100).
/// Sleep pill displays night minutes (22:00–06:00); sleepScore feeds the average.
/// Raw usage figures that power the score-breakdown progress bars.
class ScoreUsageBreakdown {
  final int distractionMinutes;
  final int top3Minutes;

  const ScoreUsageBreakdown({
    required this.distractionMinutes,
    required this.top3Minutes,
  });

  static const zero = ScoreUsageBreakdown(
    distractionMinutes: 0,
    top3Minutes: 0,
  );
}

class ScreenTimerControllerScoreCalculator {
  static const nightBudgetMinutes = 120;
  /// Length of the sleep window (22:00–06:00) used in breakdown bars.
  static const nightWindowMinutes = 8 * 60;
  static const restTop3Penalty = 0.75;
  /// Reference for the daily screen-time bar (8 h).
  static const dailyScreenTimeReferenceMinutes = 8 * 60;

  static const _distractingPackages = {
    'com.instagram.android',
    'com.facebook.katana',
    'com.facebook.orca',
    'com.twitter.android',
    'com.zhiliaoapp.musically',
    'com.snapchat.android',
    'com.google.android.youtube',
    'com.netflix.mediaclient',
    'com.spotify.music',
    'com.discord',
    'com.reddit.frontpage',
  };

  ScreenTimerControllerMetrics calculate({
    required ScreenTimeData data,
    String? distractingHabit,
    Set<String> distractingFolderPackages = const {},
    Set<String> alwaysAllowedPackages = const {},
    double? dailyHoursEstimate,
  }) {
    if (!data.hasPermission) {
      if (dailyHoursEstimate != null) {
        return calculateEstimated(dailyHoursEstimate: dailyHoursEstimate);
      }
      return ScreenTimerControllerMetrics.zero;
    }

    if (data.todayTotal == Duration.zero) {
      return const ScreenTimerControllerMetrics(
        score: 100,
        sleep: 0,
        sleepScore: 100,
        focus: 100,
        rest: 100,
      );
    }

    final todayMinutes = data.todayTotal.inMinutes;
    final sleepMinutes = data.nightUsageMinutes;
    final sleepScore = _sleepScore(sleepMinutes);

    final distractionMinutes = _distractionMinutes(
      data,
      distractingHabit,
      distractingFolderPackages,
      alwaysAllowedPackages,
    );
    final distractionRatio =
        todayMinutes > 0 ? distractionMinutes / todayMinutes : 0.0;
    final focus = (100 * (1 - distractionRatio)).round().clamp(0, 100);

    final top3Minutes = _top3Minutes(data);
    final concentration =
        todayMinutes > 0 ? top3Minutes / todayMinutes : 0.0;
    final rest =
        (100 * (1 - concentration * restTop3Penalty)).round().clamp(0, 100);

    final score =
        ((sleepScore + focus + rest) / 3).round().clamp(0, 100);

    return ScreenTimerControllerMetrics(
      score: score,
      sleep: sleepMinutes,
      sleepScore: sleepScore,
      focus: focus,
      rest: rest,
    );
  }

  /// Approximate wellness metrics from onboarding daily-hours estimate (iOS).
  ScreenTimerControllerMetrics calculateEstimated({
    required double dailyHoursEstimate,
  }) {
    final todayMinutes = (dailyHoursEstimate * 60).round();
    final nightMinutes =
        (todayMinutes * 0.12).round().clamp(0, nightBudgetMinutes);
    final sleepScore = _sleepScore(nightMinutes);

    final screenTimeRatio =
        (todayMinutes / dailyScreenTimeReferenceMinutes).clamp(0.0, 1.0);
    final focus =
        (100 * (1 - screenTimeRatio * 0.5)).round().clamp(0, 100);
    final rest =
        (100 * (1 - screenTimeRatio * 0.4)).round().clamp(0, 100);

    final score =
        ((sleepScore + focus + rest) / 3).round().clamp(0, 100);

    return ScreenTimerControllerMetrics(
      score: score,
      sleep: nightMinutes,
      sleepScore: sleepScore,
      focus: focus,
      rest: rest,
    );
  }

  ScoreUsageBreakdown usageBreakdown({
    required ScreenTimeData data,
    String? distractingHabit,
    Set<String> distractingFolderPackages = const {},
    Set<String> alwaysAllowedPackages = const {},
  }) {
    if (!data.hasPermission || data.todayTotal == Duration.zero) {
      return ScoreUsageBreakdown.zero;
    }

    return ScoreUsageBreakdown(
      distractionMinutes: _distractionMinutes(
        data,
        distractingHabit,
        distractingFolderPackages,
        alwaysAllowedPackages,
      ),
      top3Minutes: _top3Minutes(data),
    );
  }

  int _sleepScore(int sleepMinutes) =>
      (100 * (1 - (sleepMinutes / nightBudgetMinutes).clamp(0.0, 1.0)))
          .round()
          .clamp(0, 100);

  int _distractionMinutes(
    ScreenTimeData data,
    String? habit,
    Set<String> distractingFolderPackages,
    Set<String> alwaysAllowedPackages,
  ) {
    var minutes = 0;
    for (final app in data.topApps) {
      if (_isDistracting(
        app.packageName,
        app.appName,
        habit,
        distractingFolderPackages,
        alwaysAllowedPackages,
      )) {
        minutes += app.usage.inMinutes;
      }
    }
    return minutes;
  }

  int _top3Minutes(ScreenTimeData data) {
    final sorted = List<AppUsageItem>.from(data.topApps)
      ..sort((a, b) => b.usage.compareTo(a.usage));
    return sorted
        .take(3)
        .fold<int>(0, (sum, app) => sum + app.usage.inMinutes);
  }

  bool _isDistracting(
    String package,
    String name,
    String? habit,
    Set<String> distractingFolderPackages,
    Set<String> alwaysAllowedPackages,
  ) {
    if (alwaysAllowedPackages.contains(package)) return false;
    if (distractingFolderPackages.contains(package)) return true;
    if (_distractingPackages.contains(package)) return true;

    final lower = name.toLowerCase();
    if (habit != null &&
        lower.contains(habit.toLowerCase().split(' ').first)) {
      return true;
    }

    const keywords = [
      'instagram',
      'facebook',
      'tiktok',
      'youtube',
      'twitter',
      'snapchat',
      'game',
      'chrome',
      'browser',
    ];
    return keywords.any(lower.contains);
  }
}
