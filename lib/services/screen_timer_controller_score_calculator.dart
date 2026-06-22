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

/// Week-average baselines for score-breakdown progress bars (Mon–today).
class ScoreBreakdownBaselines {
  static const defaultFirstPickupMinutes = 8 * 60.0;
  static const defaultLastPickupMinutes = 22 * 60.0;

  final double avgScreenMinutes;
  final double avgSleepMinutes;
  final double avgDistractionMinutes;
  final double avgTop3Minutes;
  final double avgFirstPickupMinutes;
  final double avgLastPickupMinutes;

  const ScoreBreakdownBaselines({
    required this.avgScreenMinutes,
    required this.avgSleepMinutes,
    required this.avgDistractionMinutes,
    required this.avgTop3Minutes,
    this.avgFirstPickupMinutes = defaultFirstPickupMinutes,
    this.avgLastPickupMinutes = defaultLastPickupMinutes,
  });

  static const zero = ScoreBreakdownBaselines(
    avgScreenMinutes: 0,
    avgSleepMinutes: 0,
    avgDistractionMinutes: 0,
    avgTop3Minutes: 0,
    avgFirstPickupMinutes: defaultFirstPickupMinutes,
    avgLastPickupMinutes: defaultLastPickupMinutes,
  );
}

/// One prior calendar day of usage used for rolling breakdown baselines.
class PriorDayUsageSnapshot {
  final double screenMinutes;
  final double nightMinutes;
  final List<AppUsageItem> apps;

  const PriorDayUsageSnapshot({
    required this.screenMinutes,
    required this.nightMinutes,
    required this.apps,
  });
}

class ScreenTimerControllerScoreCalculator {
  static const nightBudgetMinutes = 120;
  static const restTop3Penalty = 0.75;
  /// Reference for onboarding estimate when real usage is unavailable (iOS).
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
      data.topApps,
      distractingHabit,
      distractingFolderPackages,
      alwaysAllowedPackages,
    );
    final distractionRatio =
        todayMinutes > 0 ? distractionMinutes / todayMinutes : 0.0;
    final focus = (100 * (1 - distractionRatio)).round().clamp(0, 100);

    final top3Minutes = _top3Minutes(data.topApps);
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
        data.topApps,
        distractingHabit,
        distractingFolderPackages,
        alwaysAllowedPackages,
      ),
      top3Minutes: _top3Minutes(data.topApps),
    );
  }

  /// Daily averages from prior days this week (today excluded) for breakdown bars.
  ScoreBreakdownBaselines weekBaselines({
    required ScreenTimeData data,
    String? distractingHabit,
    Set<String> distractingFolderPackages = const {},
    Set<String> alwaysAllowedPackages = const {},
    DateTime? now,
  }) {
    if (!data.hasPermission) return ScoreBreakdownBaselines.zero;

    final days = _daysInCurrentWeek(now);
    if (days <= 0) return ScoreBreakdownBaselines.zero;

    final todayMinutes = data.todayTotal.inMinutes.toDouble();
    final todaySleep = data.nightUsageMinutes.toDouble();
    final todayDistraction = _distractionMinutes(
      data.topApps,
      distractingHabit,
      distractingFolderPackages,
      alwaysAllowedPackages,
    ).toDouble();
    final todayTop3 = _top3Minutes(data.topApps).toDouble();

    final weekDistraction = _distractionMinutes(
      data.weekTopApps,
      distractingHabit,
      distractingFolderPackages,
      alwaysAllowedPackages,
    ).toDouble();
    final weekTop3 = _top3Minutes(data.weekTopApps).toDouble();

    final avgScreen = _dailyAvgExcludingToday(
      weekTotal: data.weekTotal.inMinutes.toDouble(),
      today: todayMinutes,
      weekday: days,
    );
    final avgSleep = _dailyAvgExcludingToday(
      weekTotal: data.weekNightUsageMinutes.toDouble(),
      today: todaySleep,
      weekday: days,
    );
    final avgDistraction = _dailyAvgExcludingToday(
      weekTotal: weekDistraction,
      today: todayDistraction,
      weekday: days,
    );
    final avgTop3 = _dailyAvgExcludingToday(
      weekTotal: weekTop3,
      today: todayTop3,
      weekday: days,
    );

    return ScoreBreakdownBaselines(
      avgScreenMinutes: avgScreen,
      avgSleepMinutes: avgSleep,
      avgDistractionMinutes: avgDistraction,
      avgTop3Minutes: avgTop3,
    );
  }

  /// Averages from prior calendar days (today excluded) for rolling baselines.
  ScoreBreakdownBaselines rollingBaselines({
    required List<PriorDayUsageSnapshot> priorDays,
    String? distractingHabit,
    Set<String> distractingFolderPackages = const {},
    Set<String> alwaysAllowedPackages = const {},
  }) {
    if (priorDays.isEmpty) return ScoreBreakdownBaselines.zero;

    final screens = <double>[];
    final nights = <double>[];
    final distractions = <double>[];
    final top3s = <double>[];

    for (final day in priorDays) {
      if (day.screenMinutes <= 0) continue;
      screens.add(day.screenMinutes);
      nights.add(day.nightMinutes);
      distractions.add(
        _distractionMinutes(
          day.apps,
          distractingHabit,
          distractingFolderPackages,
          alwaysAllowedPackages,
        ).toDouble(),
      );
      top3s.add(_top3Minutes(day.apps).toDouble());
    }

    return ScoreBreakdownBaselines(
      avgScreenMinutes: _mean(screens),
      avgSleepMinutes: _mean(nights),
      avgDistractionMinutes: _mean(distractions),
      avgTop3Minutes: _mean(top3s),
    );
  }

  static double _mean(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  /// Merges [rolling] averages into [primary] wherever primary is zero.
  ScoreBreakdownBaselines mergeBaselines({
    required ScoreBreakdownBaselines primary,
    required ScoreBreakdownBaselines rolling,
  }) {
    return ScoreBreakdownBaselines(
      avgScreenMinutes:
          _preferNonZero(primary.avgScreenMinutes, rolling.avgScreenMinutes),
      avgSleepMinutes:
          _preferNonZero(primary.avgSleepMinutes, rolling.avgSleepMinutes),
      avgDistractionMinutes: _preferNonZero(
        primary.avgDistractionMinutes,
        rolling.avgDistractionMinutes,
      ),
      avgTop3Minutes:
          _preferNonZero(primary.avgTop3Minutes, rolling.avgTop3Minutes),
      avgFirstPickupMinutes: _preferNonZero(
        primary.avgFirstPickupMinutes,
        rolling.avgFirstPickupMinutes,
      ),
      avgLastPickupMinutes: _preferNonZero(
        primary.avgLastPickupMinutes,
        rolling.avgLastPickupMinutes,
      ),
    );
  }

  static double _preferNonZero(double primary, double fallback) {
    if (primary > 0) return primary;
    if (fallback > 0) return fallback;
    return 0;
  }

  static double _dailyAvgExcludingToday({
    required double weekTotal,
    required double today,
    required int weekday,
  }) {
    final priorDays = weekday - 1;
    if (priorDays <= 0) return 0;
    final prior = weekTotal - today;
    if (prior <= 0) return 0;
    return prior / priorDays;
  }

  static int _daysInCurrentWeek(DateTime? now) {
    final moment = now ?? DateTime.now();
    return moment.weekday.clamp(1, 7);
  }

  int _sleepScore(int sleepMinutes) =>
      (100 * (1 - (sleepMinutes / nightBudgetMinutes).clamp(0.0, 1.0)))
          .round()
          .clamp(0, 100);

  int _distractionMinutes(
    List<AppUsageItem> apps,
    String? habit,
    Set<String> distractingFolderPackages,
    Set<String> alwaysAllowedPackages,
  ) {
    var minutes = 0;
    for (final app in apps) {
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

  int _top3Minutes(List<AppUsageItem> apps) {
    final sorted = List<AppUsageItem>.from(apps)
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
