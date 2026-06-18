import 'screen_time_service.dart';

/// Resolves the last 7 calendar days of screen time for the profile chart.
///
/// All totals come from the phone (Usage Events). No local daily storage.
/// Days the phone cannot report use [fallbackHoursPerDay] from onboarding.
class DailyUsageHistoryService {
  DailyUsageHistoryService({
    ScreenTimeService? screenTimeService,
  }) : _screenTimeService = screenTimeService ?? ScreenTimeService();

  static const dayCount = 7;

  /// Upper bound for a plausible single-day total (20 h).
  static const maxMsPerDay = 20 * 60 * 60 * 1000;

  final ScreenTimeService _screenTimeService;

  static bool isValidTotalMs(int ms) => ms >= 0 && ms <= maxMsPerDay;

  static String dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// Oldest day first. [dailyHours] is `null` when no phone data exists.
  Future<DailyUsageHistory> loadLast7Days({
    required double fallbackHoursPerDay,
    DateTime? now,
    int? todayTotalMs,
  }) async {
    final moment = now ?? DateTime.now();
    final today = DateTime(moment.year, moment.month, moment.day);
    final hours = <double>[];
    final labels = <String>[];
    final measuredHours = <double>[];

    for (var offset = dayCount - 1; offset >= 0; offset--) {
      final day = today.subtract(Duration(days: offset));
      final isToday = _isToday(day, today);
      labels.add(_weekdayLabel(day));

      final resolvedMs = await _fetchDayMsFromPhone(
        day: day,
        isToday: isToday,
        todayTotalMs: isToday ? todayTotalMs : null,
      );

      if (resolvedMs != null) {
        final dayHours = resolvedMs / 3600000.0;
        hours.add(dayHours);
        measuredHours.add(dayHours);
      } else {
        hours.add(fallbackHoursPerDay);
      }
    }

    final averageHours = measuredHours.isEmpty
        ? fallbackHoursPerDay
        : measuredHours.reduce((a, b) => a + b) / measuredHours.length;

    return DailyUsageHistory(
      dailyHours: hours,
      dayLabels: labels,
      averageHours: averageHours,
      measuredDayCount: measuredHours.length,
      isEstimated: measuredHours.length < dayCount,
    );
  }

  Future<int?> _fetchDayMsFromPhone({
    required DateTime day,
    required bool isToday,
    int? todayTotalMs,
  }) async {
    if (isToday &&
        todayTotalMs != null &&
        isValidTotalMs(todayTotalMs)) {
      return todayTotalMs;
    }

    final fromPhone = await _screenTimeService.fetchDayTotalMs(day);
    if (fromPhone == null || !isValidTotalMs(fromPhone)) {
      return null;
    }
    if (fromPhone > 0 || isToday) {
      return fromPhone;
    }
    return null;
  }

  static bool _isToday(DateTime day, DateTime today) =>
      day.year == today.year && day.month == today.month && day.day == today.day;

  static String _weekdayLabel(DateTime day) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[day.weekday - 1];
  }
}

class DailyUsageHistory {
  /// Chart values: phone totals where available, otherwise onboarding estimate.
  final List<double> dailyHours;
  final List<String> dayLabels;
  final double averageHours;
  final int measuredDayCount;
  /// `true` when one or more chart days use the onboarding fallback estimate.
  final bool isEstimated;

  const DailyUsageHistory({
    required this.dailyHours,
    required this.dayLabels,
    required this.averageHours,
    required this.measuredDayCount,
    this.isEstimated = false,
  });
}
