import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_rule.dart';

class StreakService {
  static const _keyQualifiedDays = 'streak_qualified_days';

  /// When [rules] include at least one activating rule today, or a focus timer
  /// was started today ([recordTimerStart]), records the day and returns the
  /// current consecutive-day streak.
  Future<int> recordAndGetStreak(List<AppRule> rules, [DateTime? now]) async {
    final moment = now ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final qualified = _loadQualifiedDays(prefs);

    if (hasAnyActivatingRule(rules, moment)) {
      qualified.add(_dateKey(moment));
    }

    final streak = calculateStreak(qualified, moment);
    await _saveQualifiedDays(prefs, qualified);
    return streak;
  }

  /// Marks [now] as a streak day because the user started a focus timer.
  Future<void> recordTimerStart([DateTime? now]) async {
    final moment = now ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final qualified = _loadQualifiedDays(prefs);
    qualified.add(_dateKey(moment));
    await _saveQualifiedDays(prefs, qualified);
  }

  /// Whether any rule is actively enforcing right now.
  static bool hasAnyActivatingRule(List<AppRule> rules, [DateTime? at]) {
    final moment = at ?? DateTime.now();
    return rules.any((rule) => isRuleActivating(rule, moment));
  }

  static bool isRuleActivating(AppRule rule, DateTime at) {
    if (rule is SessionRule) return rule.isScheduleActive(at);
    if (rule is TimeLimitRule) return rule.isRuleActive(at);
    if (rule is OpenLimitRule) return rule.isRuleActive(at);
    return false;
  }

  /// Consecutive qualified days ending at [now] (today if qualified, otherwise
  /// yesterday while the current day is still in progress).
  static int calculateStreak(Set<String> qualifiedDays, DateTime now) {
    final todayKey = _dateKey(now);
    final yesterdayKey =
        _dateKey(now.subtract(const Duration(days: 1)));

    final DateTime startDay;
    if (qualifiedDays.contains(todayKey)) {
      startDay = DateTime(now.year, now.month, now.day);
    } else if (qualifiedDays.contains(yesterdayKey)) {
      startDay =
          DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    } else {
      return 0;
    }

    var count = 0;
    var cursor = startDay;
    while (qualifiedDays.contains(_dateKey(cursor))) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  static Set<String> _loadQualifiedDays(SharedPreferences prefs) {
    final raw = prefs.getString(_keyQualifiedDays);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().toSet();
      }
    } catch (_) {}
    return {};
  }

  static Future<void> _saveQualifiedDays(
    SharedPreferences prefs,
    Set<String> days,
  ) async {
    final sorted = days.toList()..sort();
    await prefs.setString(_keyQualifiedDays, jsonEncode(sorted));
  }

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
