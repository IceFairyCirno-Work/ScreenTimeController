import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserData extends ChangeNotifier {
  static const _keyOnboardingComplete = 'onboarding_complete';
  static const _keyDisplayName = 'user_display_name';
  static const _keyDailyScreenTime = 'user_daily_screen_time';
  static const _keyHabitToChange = 'user_habit_to_change';
  static const _keyAgeRange = 'user_age_range';
  static const _keyAge = 'user_age';
  static const _keyOccupation = 'user_occupation';

  static const int maxDisplayNameLength = 10;
  static const String defaultDisplayName = 'User';

  String? _dailyScreenTime;
  String? _habitToChange;
  String? _ageRange;
  int? _age;
  String? _occupation;
  String _displayName = defaultDisplayName;
  bool _onboardingComplete = false;
  bool _initialized = false;
  int _resetVersion = 0;

  String? get dailyScreenTime => _dailyScreenTime;
  String? get habitToChange => _habitToChange;
  String? get ageRange => _ageRange;
  int? get age => _age;
  String? get occupation => _occupation;
  String get displayName => _displayName;
  bool get isOnboardingComplete => _onboardingComplete;
  bool get initialized => _initialized;
  int get resetVersion => _resetVersion;

  double get dailyHoursEstimate {
    switch (_dailyScreenTime) {
      case 'Under 1 hour':
        return 0.75;
      case '1-3 hours':
        return 2.0;
      case '3-4 hours':
        return 3.5;
      case '4-5 hours':
        return 4.5;
      case '5-7 hours':
        return 6.0;
      case 'More than 7 hours':
        return 8.0;
      default:
        return 0.0;
    }
  }

  double get ageMidpoint {
    if (_age != null) return _age!.toDouble();
    switch (_ageRange) {
      case 'Under 18':
        return 15;
      case '18-24':
        return 21;
      case '25-34':
        return 29.5;
      case '35-44':
        return 39.5;
      case '45-54':
        return 49.5;
      case '55+':
        return 62;
      default:
        return 30;
    }
  }

  static const double wakingHoursPerDay = 16;
  static const double lifeExpectancyYears = 80;

  double get daysSpentThisYear {
    final now = DateTime.now();
    final startOfYear = DateTime(now.year, 1, 1);
    final daysElapsed = now.difference(startOfYear).inDays;
    final dailyHours = dailyHoursEstimate;
    return (dailyHours * daysElapsed) / wakingHoursPerDay;
  }

  double get lifetimeYearsOnScreen {
    final dailyHours = dailyHoursEstimate;
    return (dailyHours / wakingHoursPerDay) * lifeExpectancyYears;
  }

  /// Years Silo estimates you can reclaim by cutting screen time toward a
  /// healthier ~2 h/day average, assuming ~60% of the gap is recoverable.
  double get reclaimableLifetimeYears {
    const targetDailyHours = 2.0;
    const programEfficacy = 0.6;

    final currentDaily = dailyHoursEstimate;
    if (currentDaily <= targetDailyHours) return 3.0;

    final targetLifetime =
        (targetDailyHours / wakingHoursPerDay) * lifeExpectancyYears;
    final theoreticalGap = lifetimeYearsOnScreen - targetLifetime;

    return (theoreticalGap * programEfficacy).clamp(3.0, 45.0);
  }

  String get daysSpentThisYearText {
    final days = daysSpentThisYear;
    return '${days.toStringAsFixed(1)} days';
  }

  String get lifetimeYearsText {
    final years = lifetimeYearsOnScreen;
    return '${years.toStringAsFixed(1)} years';
  }

  String get funComparison {
    final hours = lifetimeYearsOnScreen * 365.25 * 24;
    final movies = (hours / 2).round();
    return 'That\'s equivalent to watching ${movies.toLocaleString()} movies';
  }

  Future<void> loadFromPrefs() async {
    final versionAtStart = _resetVersion;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (versionAtStart != _resetVersion) return;

      _dailyScreenTime = prefs.getString(_keyDailyScreenTime);
      _habitToChange = prefs.getString(_keyHabitToChange);
      _ageRange = prefs.getString(_keyAgeRange);
      _age = prefs.getInt(_keyAge);
      _occupation = prefs.getString(_keyOccupation);
      _displayName = prefs.getString(_keyDisplayName) ?? defaultDisplayName;
      if (versionAtStart != _resetVersion) return;
      _onboardingComplete = prefs.getBool(_keyOnboardingComplete) ?? false;
    } catch (e, stack) {
      debugPrint('Failed to load user data: $e\n$stack');
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> setDailyScreenTime(String value) async {
    _dailyScreenTime = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDailyScreenTime, value);
    notifyListeners();
  }

  Future<void> setHabitToChange(String value) async {
    _habitToChange = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyHabitToChange, value);
    notifyListeners();
  }

  Future<void> setAgeRange(String value) async {
    _ageRange = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAgeRange, value);
    notifyListeners();
  }

  Future<void> setAge(int value) async {
    _age = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAge, value);
    notifyListeners();
  }

  Future<void> setOccupation(String value) async {
    _occupation = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyOccupation, value);
    notifyListeners();
  }

  Future<void> setDisplayName(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.length > maxDisplayNameLength) return;
    _displayName = trimmed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDisplayName, trimmed);
    notifyListeners();
  }

  Future<void> markOnboardingComplete() async {
    _onboardingComplete = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboardingComplete, true);
    notifyListeners();
  }

  /// Clears profile and onboarding progress in memory after [SharedPreferences.clear].
  void resetAccount() {
    _dailyScreenTime = null;
    _habitToChange = null;
    _ageRange = null;
    _age = null;
    _occupation = null;
    _displayName = defaultDisplayName;
    _onboardingComplete = false;
    _resetVersion++;
    notifyListeners();
  }
}

extension on int {
  String toLocaleString() {
    final str = toString();
    final buffer = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}
