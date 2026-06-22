import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_rule.dart';
import '../services/screen_time_service.dart';
import '../services/rule_notification_service.dart';
import '../utils/website_helpers.dart';
import '../widgets/my_apps/rule_edit_sheet.dart';

class RulesProvider extends ChangeNotifier with WidgetsBindingObserver {
  static const _storageKey = 'app_rules';
  static const _reEnableCheckInterval = Duration(seconds: 1);
  static const _usageRefreshInterval = Duration(seconds: 1);

  final _screenTimeService = ScreenTimeService();

  List<AppRule> _rules = [];
  bool _isLoading = false;
  String? _error;
  Set<String> _alwaysAllowedPackages = {};
  Set<String> _neverAllowedPackages = {};
  final Map<String, int> _todayUnblocksByPackage = {};
  final Map<String, int> _todayUsageMsByPackage = {};
  DateTime? _lastUsageRefresh;
  bool _usageRefreshInFlight = false;

  /// Periodic timer that clears expired temporal flags and per-package unblock
  /// windows.
  Timer? _reEnableTimer;

  /// Fingerprint of time-sensitive rule status labels; used to avoid redundant
  /// [notifyListeners] calls while still refreshing countdown badges.
  String? _lastScheduleDisplayKey;

  /// Shared schedule fingerprint for UI badges and native blocking sync.
  String scheduleStateKey([DateTime? at]) => _scheduleDisplayKey(at ?? DateTime.now());

  List<AppRule> get rules => _rules;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<SessionRule> get sessions =>
      _rules.whereType<SessionRule>().toList();

  List<TimeLimitRule> get timeLimits =>
      _rules.whereType<TimeLimitRule>().toList();

  List<OpenLimitRule> get openLimits =>
      _rules.whereType<OpenLimitRule>().toList();

  int getTodayUnblocks(String packageName) =>
      _todayUnblocksByPackage[packageName] ?? 0;

  OpenLimitRule _openLimitForMoment(OpenLimitRule rule, DateTime moment) =>
      rule.withPrunedUnblocks(moment).withQuotaRollover(moment);

  TimeLimitRule _timeLimitForMoment(TimeLimitRule rule, DateTime moment) =>
      rule.withPrunedUnblocks(moment).withQuotaRollover(moment);

  Duration todayUsageForPackage(String packageName) =>
      Duration(milliseconds: _todayUsageMsByPackage[packageName] ?? 0);

  Duration effectiveTimeLimitUsage(TimeLimitRule rule, String packageName) =>
      rule.effectiveUsageForPackage(
        packageName,
        todayUsageForPackage(packageName),
      );

  Future<Map<String, int>> _captureUsageBaselines(
    Iterable<String> packageNames,
  ) async {
    final baselines = <String, int>{};
    for (final pkg in packageNames) {
      final stats = await _screenTimeService.fetchBlockedAppTodayStats(pkg);
      final usageMs = stats.screenTime.inMilliseconds;
      _todayUsageMsByPackage[pkg] = usageMs;
      baselines[pkg] = usageMs;
    }
    return baselines;
  }

  /// Packages in the Always allowed folder — exempt from all blocking.
  void setAlwaysAllowedPackages(Set<String> packages) {
    if (setEquals(_alwaysAllowedPackages, packages)) return;
    _alwaysAllowedPackages = Set<String>.from(packages);
    notifyListeners();
  }

  bool isAlwaysAllowedPackage(String packageName) =>
      _alwaysAllowedPackages.contains(packageName);

  /// Packages in the Never allowed folder — permanently blocked and hidden
  /// from the Blocked apps row.
  void setNeverAllowedPackages(Set<String> packages) {
    if (setEquals(_neverAllowedPackages, packages)) return;
    final newlyNeverAllowed = packages.difference(_neverAllowedPackages);
    _neverAllowedPackages = Set<String>.from(packages);
    if (newlyNeverAllowed.isNotEmpty) {
      _clearUnblocksForPackages(newlyNeverAllowed);
    }
    notifyListeners();
  }

  bool isNeverAllowedPackage(String packageName) =>
      _neverAllowedPackages.contains(packageName);

  /// Always allowed unless the package is also in Never allowed (Never wins).
  bool isEffectivelyAlwaysAllowed(String packageName) =>
      isAlwaysAllowedPackage(packageName) && !isNeverAllowedPackage(packageName);

  /// Whether [rule] has at least one app that can be temporarily unblocked.
  bool ruleHasUnblockableApps(SessionRule rule, [DateTime? at]) {
    final moment = at ?? DateTime.now();
    if (!rule.isScheduleActive(moment)) return false;
    if (rule.isHardMode) return false;
    return rule.apps.any((a) {
      if (isNeverAllowedPackage(a.packageName)) return false;
      return rule.isPackageBlocked(a.packageName, moment);
    });
  }

  /// Open limit rules with at least one unblockable app (fixed-duration break).
  bool openLimitRuleHasUnblockableApps(OpenLimitRule rule, [DateTime? at]) {
    final moment = at ?? DateTime.now();
    if (!rule.isRuleActive(moment)) return false;
    if (rule.isHardMode) return false;
    return rule.apps.any((a) {
      if (isNeverAllowedPackage(a.packageName)) return false;
      return canUnblockOpenLimitPackage(a.packageName, rule, moment);
    });
  }

  /// Time limit rules with at least one blocked app that can be unblocked.
  bool timeLimitRuleHasUnblockableApps(TimeLimitRule rule, [DateTime? at]) {
    final moment = at ?? DateTime.now();
    if (!rule.isRuleActive(moment)) return false;
    if (rule.isHardMode) return false;
    return rule.apps.any((a) {
      if (isNeverAllowedPackage(a.packageName)) return false;
      final usage = effectiveTimeLimitUsage(rule, a.packageName);
      return rule.isPackageBlocked(a.packageName, usage, moment);
    });
  }

  bool canUnblockTimeLimitPackage(
    String packageName,
    TimeLimitRule rule, [
    DateTime? at,
  ]) {
    final moment = at ?? DateTime.now();
    final r = _timeLimitForMoment(rule, moment);
    if (!r.isRuleActive(moment)) return false;
    if (r.isHardMode) return false;
    if (!r.apps.any((a) => a.packageName == packageName)) return false;
    final usage = effectiveTimeLimitUsage(rule, packageName);
    return r.isPackageBlocked(packageName, usage, moment);
  }

  bool canUnblockOpenLimitPackage(
    String packageName,
    OpenLimitRule rule, [
    DateTime? at,
  ]) {
    final moment = at ?? DateTime.now();
    final r = _openLimitForMoment(rule, moment);
    if (!r.isRuleActive(moment)) return false;
    if (r.isHardMode) return false;
    if (!r.apps.any((a) => a.packageName == packageName)) return false;
    if (!r.isPackageBlocked(packageName, moment)) return false;
    return r.hasUnblockQuota;
  }

  /// Fixed unblock duration when blocked by an open limit rule, or `null` when
  /// the schedule-style duration picker should be used.
  int? fixedUnblockMinutesForPackage(String packageName, [DateTime? at]) {
    final moment = at ?? DateTime.now();
    for (final rule in openLimitActiveRules(moment)) {
      if (!rule.apps.any((a) => a.packageName == packageName)) continue;
      if (!canUnblockOpenLimitPackage(packageName, rule, moment)) continue;
      return rule.sessionLengthMinutes;
    }
    return null;
  }

  bool packageCanUnblock(String packageName, [DateTime? at]) {
    final moment = at ?? DateTime.now();
    if (isNeverAllowedPackage(packageName)) return false;
    if (isPackageHardBlocked(packageName, moment)) return false;
    if (fixedUnblockMinutesForPackage(packageName, moment) != null) return true;
    return scheduleActiveRules.any(
      (r) =>
          !r.isHardMode &&
          r.apps.any((a) => a.packageName == packageName) &&
          r.isPackageBlocked(packageName, moment),
    ) ||
        timeLimitActiveRules(moment).any(
          (r) => canUnblockTimeLimitPackage(packageName, r, moment),
        );
  }

  bool isOpenLimitPackageBlocked(String packageName, [DateTime? at]) {
    final moment = at ?? DateTime.now();
    return openLimitActiveRules(moment).any(
      (r) => r.isPackageBlocked(packageName, moment),
    );
  }

  /// Unblock actions remaining today for [rule] ("unblock all" costs 1).
  int openLimitUnblocksRemaining(OpenLimitRule rule, [DateTime? at]) {
    final moment = at ?? DateTime.now();
    if (!rule.isRuleActive(moment)) return rule.maxOpens;
    return _openLimitForMoment(rule, moment).unblocksRemaining;
  }

  /// Rules that are both [isEnabled] and not currently inside a time-based
  /// disable window.
  List<AppRule> get enabledRules => _rules.where((r) {
        if (!r.isEnabled) return false;
        if (r is SessionRule && r.isCurrentlyDisabled()) return false;
        if (r is OpenLimitRule && r.isCurrentlyDisabled()) return false;
        if (r is TimeLimitRule && r.isCurrentlyDisabled()) return false;
        return true;
      }).toList();

  RulesProvider() {
    WidgetsBinding.instance.addObserver(this);
    _startReEnableTimer();
    Future.microtask(loadRules);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _lastScheduleDisplayKey = null;
      _cleanupExpiredDisables();
      _maybeNotifyScheduleDisplay();
    }
  }

  void _startReEnableTimer() {
    _reEnableTimer?.cancel();
    _reEnableTimer = Timer.periodic(_reEnableCheckInterval, (_) {
      _cleanupExpiredDisables();
      _maybeNotifyScheduleDisplay();
      _maybeRefreshTimeLimitUsage();
    });
  }

  /// Notifies listeners when any rule's schedule badge would change (e.g.
  /// "Starts in 4m" → active, or "45m left" countdown).
  void _maybeNotifyScheduleDisplay() {
    if (_rules.isEmpty) return;

    final now = DateTime.now();
    final key = _scheduleDisplayKey(now);
    if (key == _lastScheduleDisplayKey) return;
    _lastScheduleDisplayKey = key;
    notifyListeners();
  }

  String _scheduleDisplayKey(DateTime now) {
    final parts = <String>[];
    for (final rule in _rules) {
      if (rule is SessionRule) {
        if (rule.isCurrentlyDisabled(now)) {
          final until = rule.disabledUntil;
          parts.add(
            '${rule.id}:dis:${until?.difference(now).inMinutes ?? 0}',
          );
        } else if (!rule.isEnabled) {
          parts.add('${rule.id}:paused');
        } else if (rule.isScheduleActive(now)) {
          parts.add(
            '${rule.id}:on:${now.hour}:${now.minute}',
          );
        } else {
          parts.add(
            '${rule.id}:off:${_untilScheduleStartKey(rule, now)}',
          );
        }
      } else if (rule is OpenLimitRule) {
        if (rule.isCurrentlyDisabled(now)) {
          final until = rule.disabledUntil;
          parts.add(
            '${rule.id}:dis:${until?.difference(now).inMinutes ?? 0}',
          );
        } else if (!rule.isEnabled) {
          parts.add('${rule.id}:paused');
        } else if (rule.isRuleActive(now)) {
          parts.add('${rule.id}:on:${rule.unblocksRemaining}');
        } else {
          parts.add(
            '${rule.id}:off:${_untilActiveDayKey(rule.nextActiveAfter(now), now)}',
          );
        }
      } else if (rule is TimeLimitRule) {
        if (rule.isCurrentlyDisabled(now)) {
          final until = rule.disabledUntil;
          parts.add(
            '${rule.id}:dis:${until?.difference(now).inMinutes ?? 0}',
          );
        } else if (!rule.isEnabled) {
          parts.add('${rule.id}:paused');
        } else {
          parts.add(
            '${rule.id}:${rule.isRuleActive(now)}',
          );
        }
      }
    }
    return parts.join('|');
  }

  String _untilScheduleStartKey(SessionRule rule, DateTime now) {
    final until = rule.nextStartAfter(now).difference(now);
    if (until.inMinutes < 2) return '${until.inSeconds}s';
    return '${until.inMinutes}m';
  }

  String _untilActiveDayKey(DateTime nextActive, DateTime now) {
    final until = nextActive.difference(now);
    if (until.inMinutes < 2) return '${until.inSeconds}s';
    return '${until.inMinutes}m';
  }

  void _maybeRefreshTimeLimitUsage() {
    final now = DateTime.now();
    if (_lastUsageRefresh != null &&
        now.difference(_lastUsageRefresh!) < _usageRefreshInterval) {
      return;
    }
    if (_usageRefreshInFlight) return;
    if (_rules.whereType<TimeLimitRule>().isEmpty) return;
    _lastUsageRefresh = now;
    _usageRefreshInFlight = true;
    _refreshTimeLimitUsage().whenComplete(() {
      _usageRefreshInFlight = false;
    });
  }

  Future<void> _refreshTimeLimitUsage() async {
    final packages = <String>{};
    for (final rule in _rules.whereType<TimeLimitRule>()) {
      for (final app in rule.apps) {
        packages.add(app.packageName);
      }
    }
    if (packages.isEmpty) return;

    for (final pkg in packages) {
      final stats = await _screenTimeService.fetchBlockedAppTodayStats(pkg);
      _todayUsageMsByPackage[pkg] = stats.screenTime.inMilliseconds;
    }

    final now = DateTime.now();
    var changed = false;
    for (var i = 0; i < _rules.length; i++) {
      final rule = _rules[i];
      if (rule is! TimeLimitRule) continue;

      var updated = _timeLimitForMoment(rule, now);
      final exceeded = Map<String, DateTime>.from(
        updated.limitExceededAtByPackage,
      );

      for (final app in updated.apps) {
        final pkg = app.packageName;
        var baselines = Map<String, int>.from(updated.usageBaselineMsByPackage);
        if (!baselines.containsKey(pkg)) {
          baselines[pkg] = todayUsageForPackage(pkg).inMilliseconds;
          updated = updated.copyWith(usageBaselineMsByPackage: baselines);
        }
        final usage = updated.effectiveUsageForPackage(
          pkg,
          todayUsageForPackage(pkg),
        );
        if (usage >= updated.allowedTime && !exceeded.containsKey(pkg)) {
          exceeded[pkg] = now;
        }
      }

      if (!mapEquals(exceeded, updated.limitExceededAtByPackage)) {
        updated = updated.copyWith(limitExceededAtByPackage: exceeded);
      }

      if (updated != _rules[i]) {
        _rules[i] = updated;
        changed = true;
      }
    }

    if (changed) {
      notifyListeners();
      await _save();
    } else {
      notifyListeners();
    }
  }

  /// Clears expired temporal flags and notifies listeners when anything changed.
  void _cleanupExpiredDisables() {
    final now = DateTime.now();
    var changed = false;
    for (var i = 0; i < _rules.length; i++) {
      final rule = _rules[i];
      if (rule is SessionRule) {
        var updated = rule.withPrunedUnblocks(now);
        if (rule.disabledUntil != null &&
            !rule.isIndefinitelyDisabled() &&
            !rule.disabledUntil!.isAfter(now)) {
          updated = updated.copyWith(clearDisabledUntil: true);
          changed = true;
        } else if (updated != rule) {
          changed = true;
        }
        if (updated != _rules[i]) {
          _rules[i] = updated;
        }
      } else if (rule is OpenLimitRule) {
        var updated = _openLimitForMoment(rule, now);
        if (rule.disabledUntil != null &&
            !rule.isIndefinitelyDisabled() &&
            !rule.disabledUntil!.isAfter(now)) {
          updated = updated.copyWith(clearDisabledUntil: true);
          changed = true;
        } else if (updated != rule) {
          changed = true;
        }
        if (updated != _rules[i]) {
          _rules[i] = updated;
        }
      } else if (rule is TimeLimitRule) {
        var updated = _timeLimitForMoment(rule, now);
        if (rule.disabledUntil != null &&
            !rule.isIndefinitelyDisabled() &&
            !rule.disabledUntil!.isAfter(now)) {
          updated = updated.copyWith(clearDisabledUntil: true);
          changed = true;
        } else if (updated != rule) {
          changed = true;
        }
        if (updated != _rules[i]) {
          _rules[i] = updated;
        }
      }
    }
    if (changed) {
      notifyListeners();
      _save();
    }
  }

  Future<void> loadRules() async {
    _isLoading = true;
    _error = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);

      if (jsonStr != null) {
        final List<dynamic> jsonList = jsonDecode(jsonStr);
        _rules = jsonList.map((json) {
          final map = json as Map<String, dynamic>;
          final type = map['type'] as String?;
          if (type == 'session') {
            return SessionRule.fromJson(map);
          } else if (type == 'timeLimit') {
            return TimeLimitRule.fromJson(map);
          } else if (type == 'openLimit') {
            return OpenLimitRule.fromJson(map);
          }
          return null;
        }).whereType<AppRule>().toList();
      }
      // Lazily clean up any disables that expired while the app was closed.
      _cleanupExpiredDisables();
      _maybeRefreshTimeLimitUsage();
    } catch (e) {
      _error = e.toString();
      debugPrint('Failed to load rules: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _rules.map((r) {
        if (r is SessionRule) return r.toJson();
        if (r is TimeLimitRule) return r.toJson();
        if (r is OpenLimitRule) return r.toJson();
        return <String, dynamic>{};
      }).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e) {
      _error = e.toString();
      debugPrint('Failed to save rules: $e');
    }
  }

  void resetAfterAccountDeletion() {
    _rules = [];
    _error = null;
    notifyListeners();
  }

  Future<void> addRule(AppRule rule) async {
    if (rule is OpenLimitRule) {
      final now = DateTime.now();
      _rules.add(
        rule.copyWith(
          unblocksUsed: 0,
          unblocksQuotaDay: OpenLimitRule.quotaDayKey(now),
          unblockedUntilByPackage: const {},
          unblockedStartedAtByPackage: const {},
        ),
      );
    } else if (rule is TimeLimitRule) {
      final now = DateTime.now();
      final packages = rule.apps.map((a) => a.packageName);
      final baselines = await _captureUsageBaselines(packages);
      _rules.add(
        rule.copyWith(
          usageQuotaDay: TimeLimitRule.quotaDayKey(now),
          usageBaselineMsByPackage: baselines,
          limitExceededAtByPackage: const {},
          unblockedUntilByPackage: const {},
          unblockedStartedAtByPackage: const {},
        ),
      );
      notifyListeners();
      await _save();
      _lastUsageRefresh = null;
      _maybeRefreshTimeLimitUsage();
      return;
    } else {
      _rules.add(rule);
    }
    notifyListeners();
    await _save();
  }

  Future<void> updateRule(AppRule updated) async {
    final idx = _rules.indexWhere((r) => r.id == updated.id);
    if (idx != -1) {
      final existing = _rules[idx];
      if (existing is SessionRule && updated is SessionRule) {
        final appPackages = updated.apps.map((a) => a.packageName).toSet();
        final until = Map<String, DateTime>.from(
          existing.unblockedUntilByPackage,
        )..removeWhere((pkg, _) => !appPackages.contains(pkg));
        final started = Map<String, DateTime>.from(
          existing.unblockedStartedAtByPackage,
        )..removeWhere((pkg, _) => !appPackages.contains(pkg));

        var merged = updated.copyWith(
          unblockedUntilByPackage: until,
          unblockedStartedAtByPackage: started,
          disabledUntil: existing.disabledUntil,
        );

        if (merged.disabledUntil != null && !merged.isIndefinitelyDisabled()) {
          merged = merged.copyWith(clearDisabledUntil: true);
        }

        _rules[idx] = merged;
      } else if (existing is OpenLimitRule && updated is OpenLimitRule) {
        final appPackages = updated.apps.map((a) => a.packageName).toSet();
        final until = Map<String, DateTime>.from(
          existing.unblockedUntilByPackage,
        )..removeWhere((pkg, _) => !appPackages.contains(pkg));
        final started = Map<String, DateTime>.from(
          existing.unblockedStartedAtByPackage,
        )..removeWhere((pkg, _) => !appPackages.contains(pkg));

        final configChanged = existing.maxOpens != updated.maxOpens ||
            existing.sessionLengthMinutes != updated.sessionLengthMinutes ||
            existing.difficulty != updated.difficulty ||
            !listEquals(existing.repeatDays, updated.repeatDays) ||
            !setEquals(
              existing.apps.map((a) => a.packageName).toSet(),
              appPackages,
            );
        final now = DateTime.now();

        var merged = updated.copyWith(
          unblockedUntilByPackage: until,
          unblockedStartedAtByPackage: started,
          disabledUntil: existing.disabledUntil,
          unblocksUsed: configChanged ? 0 : existing.unblocksUsed,
          unblocksQuotaDay: configChanged
              ? OpenLimitRule.quotaDayKey(now)
              : existing.unblocksQuotaDay,
        );

        if (merged.disabledUntil != null && !merged.isIndefinitelyDisabled()) {
          merged = merged.copyWith(clearDisabledUntil: true);
        }

        _rules[idx] = merged;
      } else if (existing is TimeLimitRule && updated is TimeLimitRule) {
        final appPackages = updated.apps.map((a) => a.packageName).toSet();
        final until = Map<String, DateTime>.from(
          existing.unblockedUntilByPackage,
        )..removeWhere((pkg, _) => !appPackages.contains(pkg));
        final started = Map<String, DateTime>.from(
          existing.unblockedStartedAtByPackage,
        )..removeWhere((pkg, _) => !appPackages.contains(pkg));
        final exceeded = Map<String, DateTime>.from(
          existing.limitExceededAtByPackage,
        )..removeWhere((pkg, _) => !appPackages.contains(pkg));
        var baselines = Map<String, int>.from(
          existing.usageBaselineMsByPackage,
        )..removeWhere((pkg, _) => !appPackages.contains(pkg));

        final configChanged = existing.allowedTime != updated.allowedTime ||
            existing.blockUntil != updated.blockUntil ||
            existing.difficulty != updated.difficulty ||
            !listEquals(existing.repeatDays, updated.repeatDays) ||
            !setEquals(
              existing.apps.map((a) => a.packageName).toSet(),
              appPackages,
            );
        final now = DateTime.now();
        final newPackages = appPackages.difference(
          existing.apps.map((a) => a.packageName).toSet(),
        );

        if (configChanged) {
          baselines = await _captureUsageBaselines(appPackages);
        } else if (newPackages.isNotEmpty) {
          baselines.addAll(await _captureUsageBaselines(newPackages));
        }

        var merged = updated.copyWith(
          unblockedUntilByPackage: until,
          unblockedStartedAtByPackage: started,
          usageBaselineMsByPackage: baselines,
          limitExceededAtByPackage:
              configChanged ? const {} : exceeded,
          disabledUntil: existing.disabledUntil,
          usageQuotaDay: configChanged
              ? TimeLimitRule.quotaDayKey(now)
              : existing.usageQuotaDay,
        );

        if (merged.disabledUntil != null && !merged.isIndefinitelyDisabled()) {
          merged = merged.copyWith(clearDisabledUntil: true);
        }

        _rules[idx] = merged;
      } else {
        _rules[idx] = updated;
      }
      notifyListeners();
      await _save();
    }
  }

  Future<void> deleteRule(String ruleId) async {
    _rules.removeWhere((r) => r.id == ruleId);
    notifyListeners();
    await _save();
  }

  /// Flips the base [AppRule.isEnabled] flag — used by the detail-sheet primary
  /// "Unblock all apps" / "Block all apps" button. Does not touch the temporal
  /// [SessionRule.disabledUntil] field.
  Future<void> toggleRule(String ruleId) async {
    final idx = _rules.indexWhere((r) => r.id == ruleId);
    if (idx != -1) {
      final rule = _rules[idx];
      if (rule is OpenLimitRule) {
        final nextEnabled = !rule.isEnabled;
        _rules[idx] = rule.copyWith(
          isEnabled: nextEnabled,
          unblockedUntilByPackage:
              nextEnabled ? rule.unblockedUntilByPackage : const {},
          unblockedStartedAtByPackage:
              nextEnabled ? rule.unblockedStartedAtByPackage : const {},
        );
      } else if (rule is TimeLimitRule) {
        final nextEnabled = !rule.isEnabled;
        _rules[idx] = rule.copyWith(
          isEnabled: nextEnabled,
          unblockedUntilByPackage:
              nextEnabled ? rule.unblockedUntilByPackage : const {},
          unblockedStartedAtByPackage:
              nextEnabled ? rule.unblockedStartedAtByPackage : const {},
        );
      } else {
        _rules[idx] = rule.copyWith(isEnabled: !rule.isEnabled);
      }
      notifyListeners();
      await _save();
    }
  }

  /// Temporarily disables a [SessionRule].
  ///
  /// Pass [preset] for wheel-selected durations, [duration] for ad-hoc spans
  /// (e.g. timed unblocks), or [until] for an explicit end timestamp.
  Future<void> disableRule(
    String ruleId, {
    DisableDuration? preset,
    Duration? duration,
    DateTime? until,
  }) async {
    final idx = _rules.indexWhere((r) => r.id == ruleId);
    if (idx == -1) return;
    final rule = _rules[idx];
    DateTime disableUntil;
    if (until != null) {
      disableUntil = until;
    } else if (preset != null) {
      disableUntil = preset.resolveUntil();
    } else if (duration != null) {
      disableUntil = DateTime.now().add(duration);
    } else {
      disableUntil = SessionRule.indefiniteDisableUntil;
    }

    if (rule is SessionRule) {
      _rules[idx] = rule.copyWith(disabledUntil: disableUntil);
    } else if (rule is OpenLimitRule) {
      _rules[idx] = rule.copyWith(
        disabledUntil: disableUntil,
        unblockedUntilByPackage: const {},
        unblockedStartedAtByPackage: const {},
      );
    } else if (rule is TimeLimitRule) {
      _rules[idx] = rule.copyWith(
        disabledUntil: disableUntil,
        unblockedUntilByPackage: const {},
        unblockedStartedAtByPackage: const {},
      );
    } else {
      return;
    }
    notifyListeners();
    await _save();
  }

  /// Unblocks apps that are not already in an active per-package window.
  /// Apps unblocked earlier keep their original end time.
  ///
  /// Hard mode rules ([AppRule.isHardMode]) are skipped entirely — their apps
  /// cannot be unblocked via this flow.
  Future<void> unblockRule(String ruleId, Duration duration) async {
    final idx = _rules.indexWhere((r) => r.id == ruleId);
    if (idx == -1) return;
    final rule = _rules[idx];
    if (rule is SessionRule) {
      if (rule.isHardMode) return;
      await _applyUnblockToRule(idx, rule, duration);
    } else if (rule is OpenLimitRule) {
      if (rule.isHardMode) return;
      await _applyUnblockToOpenLimitRule(idx, rule, duration);
    } else if (rule is TimeLimitRule) {
      if (rule.isHardMode) return;
      await _applyUnblockToTimeLimitRule(idx, rule, duration);
    }
  }

  Future<void> _applyUnblockToTimeLimitRule(
    int idx,
    TimeLimitRule rule,
    Duration duration,
  ) async {
    final now = DateTime.now();
    final pruned = _timeLimitForMoment(rule, now);
    final until = Map<String, DateTime>.from(pruned.unblockedUntilByPackage);
    final started =
        Map<String, DateTime>.from(pruned.unblockedStartedAtByPackage);
    final newlyUnblocked = <String>[];

    for (final app in pruned.apps) {
      final pkg = app.packageName;
      if (isNeverAllowedPackage(pkg)) continue;
      final usage = effectiveTimeLimitUsage(pruned, pkg);
      if (!pruned.isPackageBlocked(pkg, usage, now)) continue;
      final existingUntil = until[pkg];
      if (existingUntil != null && existingUntil.isAfter(now)) continue;

      until[pkg] = now.add(duration);
      started[pkg] = now;
      newlyUnblocked.add(pkg);
    }

    if (newlyUnblocked.isEmpty) return;

    _rules[idx] = pruned.copyWith(
      unblockedUntilByPackage: until,
      unblockedStartedAtByPackage: started,
    );
    notifyListeners();
    await _save();
    for (final pkg in newlyUnblocked) {
      await _screenTimeService.recordAppUnblock(pkg);
      _todayUnblocksByPackage[pkg] = getTodayUnblocks(pkg) + 1;
    }
    await _scheduleUnblockEndedNotifications(
      ruleId: rule.id,
      untilByPackage: until,
      packages: newlyUnblocked,
    );
  }

  Future<void> _applyUnblockToRule(
    int idx,
    SessionRule rule,
    Duration duration,
  ) async {
    final now = DateTime.now();
    final pruned = rule.withPrunedUnblocks(now);
    final until = Map<String, DateTime>.from(pruned.unblockedUntilByPackage);
    final started =
        Map<String, DateTime>.from(pruned.unblockedStartedAtByPackage);
    final newlyUnblocked = <String>[];

    for (final app in pruned.apps) {
      final pkg = app.packageName;
      if (isNeverAllowedPackage(pkg)) continue;
      final existingUntil = until[pkg];
      if (existingUntil != null && existingUntil.isAfter(now)) {
        continue;
      }
      until[pkg] = now.add(duration);
      started[pkg] = now;
      newlyUnblocked.add(pkg);
    }

    _rules[idx] = pruned.copyWith(
      unblockedUntilByPackage: until,
      unblockedStartedAtByPackage: started,
    );
    notifyListeners();
    await _save();
    for (final pkg in newlyUnblocked) {
      await _screenTimeService.recordAppUnblock(pkg);
      _todayUnblocksByPackage[pkg] = getTodayUnblocks(pkg) + 1;
    }
    await _scheduleUnblockEndedNotifications(
      ruleId: rule.id,
      untilByPackage: until,
      packages: newlyUnblocked,
    );
  }

  Future<void> _applyUnblockToOpenLimitRule(
    int idx,
    OpenLimitRule rule,
    Duration duration,
  ) async {
    final now = DateTime.now();
    final pruned = _openLimitForMoment(rule, now);
    if (!pruned.hasUnblockQuota) return;

    final until = Map<String, DateTime>.from(pruned.unblockedUntilByPackage);
    final started =
        Map<String, DateTime>.from(pruned.unblockedStartedAtByPackage);
    final newlyUnblocked = <String>[];

    for (final app in pruned.apps) {
      final pkg = app.packageName;
      if (isNeverAllowedPackage(pkg)) continue;
      if (!pruned.isPackageBlocked(pkg, now)) continue;
      until[pkg] = now.add(duration);
      started[pkg] = now;
      newlyUnblocked.add(pkg);
    }

    if (newlyUnblocked.isEmpty) return;

    _rules[idx] = pruned.copyWith(
      unblockedUntilByPackage: until,
      unblockedStartedAtByPackage: started,
      unblocksUsed: pruned.unblocksUsed + 1,
    );
    notifyListeners();
    await _save();
    for (final pkg in newlyUnblocked) {
      await _screenTimeService.recordAppUnblock(pkg);
      _todayUnblocksByPackage[pkg] = getTodayUnblocks(pkg) + 1;
    }
    final updated = _rules[idx] as OpenLimitRule;
    await RuleNotificationService.instance.showOpenLimitUnblocked(
      updated.unblocksRemaining,
    );
    await _scheduleUnblockEndedNotifications(
      ruleId: rule.id,
      untilByPackage: until,
      packages: newlyUnblocked,
    );
  }

  Future<void> unblockOpenLimitRule(String ruleId) async {
    final idx = _rules.indexWhere((r) => r.id == ruleId);
    if (idx == -1) return;
    final rule = _rules[idx];
    if (rule is! OpenLimitRule || rule.isHardMode) return;
    await _applyUnblockToOpenLimitRule(
      idx,
      rule,
      Duration(minutes: rule.sessionLengthMinutes),
    );
  }

  /// Clears any active temporal disable so the rule resumes immediately.
  Future<void> enableRule(String ruleId) async {
    final idx = _rules.indexWhere((r) => r.id == ruleId);
    if (idx == -1) return;
    final rule = _rules[idx];
    if (rule is SessionRule && rule.disabledUntil != null) {
      _rules[idx] = rule.copyWith(clearDisabledUntil: true);
      notifyListeners();
      await _save();
    } else if (rule is OpenLimitRule && rule.disabledUntil != null) {
      _rules[idx] = rule.copyWith(
        clearDisabledUntil: true,
        unblockedUntilByPackage: const {},
        unblockedStartedAtByPackage: const {},
      );
      notifyListeners();
      await _save();
    } else if (rule is TimeLimitRule && rule.disabledUntil != null) {
      _rules[idx] = rule.copyWith(
        clearDisabledUntil: true,
        unblockedUntilByPackage: const {},
        unblockedStartedAtByPackage: const {},
      );
      notifyListeners();
      await _save();
    }
  }

  List<TimeLimitRule> timeLimitActiveRules([DateTime? at]) {
    final now = at ?? DateTime.now();
    return _rules
        .whereType<TimeLimitRule>()
        .where((r) => r.isRuleActive(now))
        .toList();
  }

  List<OpenLimitRule> openLimitActiveRules([DateTime? at]) {
    final now = at ?? DateTime.now();
    return _rules
        .whereType<OpenLimitRule>()
        .where((r) => r.isRuleActive(now))
        .toList();
  }

  /// Rules inside their schedule window (includes temporary unblocks).
  List<SessionRule> sessionRulesActiveAt(DateTime moment) => _rules
      .whereType<SessionRule>()
      .where((r) => r.isScheduleActive(moment))
      .toList();

  /// Rules inside their schedule window (includes temporary unblocks).
  List<SessionRule> get scheduleActiveRules =>
      sessionRulesActiveAt(DateTime.now());

  /// Rules that are currently blocking at least one app.
  List<SessionRule> get currentlyActiveRules {
    final now = DateTime.now();
    return scheduleActiveRules.where((r) => r.isCurrentlyActive(now)).toList();
  }

  /// Whether [packageName] has a running unblock window on any rule (including
  /// disabled rules — disable does not cancel the countdown).
  bool hasActivePackageUnblock(String packageName, [DateTime? at]) {
    return _packageUnblockWindow(packageName, at) != null;
  }

  /// Longest remaining per-package unblock window across all rules.
  ({DateTime until, DateTime started})? _packageUnblockWindow(
    String packageName, [
    DateTime? at,
  ]) {
    final moment = at ?? DateTime.now();
    DateTime? bestUntil;
    DateTime? bestStarted;

    for (final rule in _rules.whereType<SessionRule>()) {
      if (!rule.apps.any((a) => a.packageName == packageName)) continue;
      final until = rule.unblockedUntilByPackage[packageName];
      if (until == null || !until.isAfter(moment)) continue;
      if (bestUntil == null || until.isAfter(bestUntil)) {
        bestUntil = until;
        bestStarted = rule.unblockedStartedAtByPackage[packageName];
      }
    }

    for (final rule in _rules.whereType<OpenLimitRule>()) {
      if (!rule.isRuleActive(moment)) continue;
      if (!rule.apps.any((a) => a.packageName == packageName)) continue;
      final until = rule.unblockedUntilByPackage[packageName];
      if (until == null || !until.isAfter(moment)) continue;
      if (bestUntil == null || until.isAfter(bestUntil)) {
        bestUntil = until;
        bestStarted = rule.unblockedStartedAtByPackage[packageName];
      }
    }

    for (final rule in _rules.whereType<TimeLimitRule>()) {
      if (!rule.isRuleActive(moment)) continue;
      if (!rule.apps.any((a) => a.packageName == packageName)) continue;
      final until = rule.unblockedUntilByPackage[packageName];
      if (until == null || !until.isAfter(moment)) continue;
      if (bestUntil == null || until.isAfter(bestUntil)) {
        bestUntil = until;
        bestStarted = rule.unblockedStartedAtByPackage[packageName];
      }
    }

    if (bestUntil == null || bestStarted == null) return null;
    return (until: bestUntil, started: bestStarted);
  }

  /// Whether [packageName] is being blocked right now by at least one
  /// schedule-active **Hard mode** rule. Hard mode rules forbid any unblock,
  /// so the app stays blocked even when other rules allow a break.
  bool isPackageHardBlocked(String packageName, [DateTime? at]) {
    final moment = at ?? DateTime.now();
    if (scheduleActiveRules.any(
      (r) =>
          r.isHardMode &&
          r.apps.any((a) => a.packageName == packageName) &&
          r.isWithinWindow(moment),
    )) {
      return true;
    }
    return openLimitActiveRules(moment).any((r) {
      if (!r.isHardMode) return false;
      return r.apps.any((a) => a.packageName == packageName);
    }) ||
        timeLimitActiveRules(moment).any((r) {
          if (!r.isHardMode) return false;
          if (!r.apps.any((a) => a.packageName == packageName)) return false;
          final usage = effectiveTimeLimitUsage(r, packageName);
          return r.isPackageBlocked(packageName, usage, moment);
        });
  }

  bool _isBlockedByTimeLimitRule(String packageName, [DateTime? at]) {
    final moment = at ?? DateTime.now();
    return timeLimitActiveRules(moment).any((r) {
      final usage = effectiveTimeLimitUsage(r, packageName);
      return r.isPackageBlocked(packageName, usage, moment);
    });
  }

  bool _isBlockedByOpenLimitRule(String packageName, [DateTime? at]) {
    final moment = at ?? DateTime.now();
    return openLimitActiveRules(moment).any(
      (r) => r.isPackageBlocked(packageName, moment),
    );
  }

  /// Whether [packageName] is blocked by at least one active rule, ignoring
  /// any running unblock window.
  bool _isBlockedByActiveRule(String packageName, [DateTime? at]) {
    final moment = at ?? DateTime.now();
    if (sessionRulesActiveAt(moment).any(
      (r) =>
          r.apps.any((a) => a.packageName == packageName) &&
          r.isPackageBlocked(packageName, moment),
    )) {
      return true;
    }
    return _isBlockedByOpenLimitRule(packageName, moment) ||
        _isBlockedByTimeLimitRule(packageName, moment);
  }

  /// Whether [packageName] is currently being blocked.
  ///
  /// Never allowed folder overrides Always allowed when both apply. Hard mode
  /// rules override any active unblock window — the app stays blocked as long
  /// as a Hard mode schedule is active.
  bool isAppBlocked(String packageName, [DateTime? at]) {
    if (isNeverAllowedPackage(packageName)) return true;
    if (isEffectivelyAlwaysAllowed(packageName)) return false;
    final now = at ?? DateTime.now();
    if (isPackageHardBlocked(packageName, now)) return true;
    if (hasActivePackageUnblock(packageName, now)) return false;
    return _isBlockedByActiveRule(packageName, now);
  }

  /// Temporarily unblocks [packageName] on every schedule-active rule that
  /// contains it. Rules that already have a future window for this app are
  /// left unchanged.
  Future<void> unblockPackage(String packageName, Duration duration) async {
    if (isNeverAllowedPackage(packageName)) return;
    final now = DateTime.now();
    var changed = false;
    OpenLimitRule? openLimitAfter;
    final unblockEndedEvents = <({String ruleId, String package, DateTime until})>[];

    for (var i = 0; i < _rules.length; i++) {
      final rule = _rules[i];
      if (rule is SessionRule) {
        if (rule.isHardMode) continue;
        if (!rule.apps.any((a) => a.packageName == packageName)) continue;
        if (!rule.isScheduleActive(now)) continue;

        final pruned = rule.withPrunedUnblocks(now);
        final until =
            Map<String, DateTime>.from(pruned.unblockedUntilByPackage);
        final started =
            Map<String, DateTime>.from(pruned.unblockedStartedAtByPackage);
        final existing = until[packageName];
        if (existing != null && existing.isAfter(now)) continue;

        final endsAt = now.add(duration);
        until[packageName] = endsAt;
        started[packageName] = now;
        _rules[i] = pruned.copyWith(
          unblockedUntilByPackage: until,
          unblockedStartedAtByPackage: started,
        );
        unblockEndedEvents.add(
          (ruleId: rule.id, package: packageName, until: endsAt),
        );
        changed = true;
      } else if (rule is OpenLimitRule) {
        if (rule.isHardMode) continue;
        if (!rule.apps.any((a) => a.packageName == packageName)) continue;
        if (!canUnblockOpenLimitPackage(packageName, rule, now)) continue;

        final pruned = _openLimitForMoment(rule, now);
        final until =
            Map<String, DateTime>.from(pruned.unblockedUntilByPackage);
        final started =
            Map<String, DateTime>.from(pruned.unblockedStartedAtByPackage);

        final endsAt = now.add(duration);
        until[packageName] = endsAt;
        started[packageName] = now;
        _rules[i] = pruned.copyWith(
          unblockedUntilByPackage: until,
          unblockedStartedAtByPackage: started,
          unblocksUsed: pruned.unblocksUsed + 1,
        );
        openLimitAfter = _rules[i] as OpenLimitRule;
        unblockEndedEvents.add(
          (ruleId: rule.id, package: packageName, until: endsAt),
        );
        changed = true;
        break;
      } else if (rule is TimeLimitRule) {
        if (rule.isHardMode) continue;
        if (!rule.apps.any((a) => a.packageName == packageName)) continue;
        if (!canUnblockTimeLimitPackage(packageName, rule, now)) continue;

        final pruned = _timeLimitForMoment(rule, now);
        final until =
            Map<String, DateTime>.from(pruned.unblockedUntilByPackage);
        final started =
            Map<String, DateTime>.from(pruned.unblockedStartedAtByPackage);

        final endsAt = now.add(duration);
        until[packageName] = endsAt;
        started[packageName] = now;
        _rules[i] = pruned.copyWith(
          unblockedUntilByPackage: until,
          unblockedStartedAtByPackage: started,
        );
        unblockEndedEvents.add(
          (ruleId: rule.id, package: packageName, until: endsAt),
        );
        changed = true;
        break;
      }
    }

    if (changed) {
      notifyListeners();
      await _save();
      await _screenTimeService.recordAppUnblock(packageName);
      _todayUnblocksByPackage[packageName] =
          getTodayUnblocks(packageName) + 1;
      if (openLimitAfter != null) {
        await RuleNotificationService.instance.showOpenLimitUnblocked(
          openLimitAfter.unblocksRemaining,
        );
      }
      for (final event in unblockEndedEvents) {
        await RuleNotificationService.instance.scheduleUnblockEnded(
          dedupeKey: '${event.ruleId}|${event.package}',
          until: event.until,
        );
      }
    }
  }

  /// Clears every active unblock window for [packageName] (relock).
  Future<void> reblockPackage(String packageName) async {
    var changed = false;
    final cancelledKeys = <String>[];

    for (var i = 0; i < _rules.length; i++) {
      final rule = _rules[i];
      if (rule is SessionRule) {
        if (!rule.unblockedUntilByPackage.containsKey(packageName) &&
            !rule.unblockedStartedAtByPackage.containsKey(packageName)) {
          continue;
        }

        cancelledKeys.add('${rule.id}|$packageName');
        final until = Map<String, DateTime>.from(rule.unblockedUntilByPackage)
          ..remove(packageName);
        final started =
            Map<String, DateTime>.from(rule.unblockedStartedAtByPackage)
              ..remove(packageName);
        _rules[i] = rule.copyWith(
          unblockedUntilByPackage: until,
          unblockedStartedAtByPackage: started,
        );
        changed = true;
      } else if (rule is OpenLimitRule) {
        if (!rule.unblockedUntilByPackage.containsKey(packageName) &&
            !rule.unblockedStartedAtByPackage.containsKey(packageName)) {
          continue;
        }

        cancelledKeys.add('${rule.id}|$packageName');
        final until = Map<String, DateTime>.from(rule.unblockedUntilByPackage)
          ..remove(packageName);
        final started =
            Map<String, DateTime>.from(rule.unblockedStartedAtByPackage)
              ..remove(packageName);
        _rules[i] = rule.copyWith(
          unblockedUntilByPackage: until,
          unblockedStartedAtByPackage: started,
        );
        changed = true;
      } else if (rule is TimeLimitRule) {
        if (!rule.unblockedUntilByPackage.containsKey(packageName) &&
            !rule.unblockedStartedAtByPackage.containsKey(packageName)) {
          continue;
        }

        cancelledKeys.add('${rule.id}|$packageName');
        final until = Map<String, DateTime>.from(rule.unblockedUntilByPackage)
          ..remove(packageName);
        final started =
            Map<String, DateTime>.from(rule.unblockedStartedAtByPackage)
              ..remove(packageName);
        _rules[i] = rule.copyWith(
          unblockedUntilByPackage: until,
          unblockedStartedAtByPackage: started,
        );
        changed = true;
      }
    }

    if (changed) {
      for (final key in cancelledKeys) {
        await RuleNotificationService.instance.cancelUnblockEnded(key);
      }
      notifyListeners();
      await _save();
    }
  }

  /// Apps for the Blocked apps row — one entry per package.
  ///
  /// Shown when blocked by a schedule-active rule or while an unblock countdown
  /// is running. Duplicate packages across rules appear once. A running
  /// countdown survives rule disable and extra rules blocking the same app;
  /// only relock or deleting the owning rule clears it.
  List<BlockedAppDisplay> blockedAppsDisplay([DateTime? at]) {
    final moment = at ?? DateTime.now();
    final appsByPackage = <String, AppRuleItem>{};

    for (final rule in _rules.whereType<SessionRule>()) {
      for (final app in rule.apps) {
        final pkg = app.packageName;
        if (isEffectivelyAlwaysAllowed(pkg)) continue;
        if (isNeverAllowedPackage(pkg)) continue;
        final showForBlock = _isBlockedByActiveRule(pkg, moment);
        final showForUnblock = hasActivePackageUnblock(pkg, moment);
        if (!showForBlock && !showForUnblock) continue;
        appsByPackage.putIfAbsent(pkg, () => app);
      }
    }

    for (final rule in _rules.whereType<OpenLimitRule>()) {
      final rolled = _openLimitForMoment(rule, moment);
      if (!rolled.isRuleActive(moment)) continue;
      for (final app in rolled.apps) {
        final pkg = app.packageName;
        if (isEffectivelyAlwaysAllowed(pkg)) continue;
        if (isNeverAllowedPackage(pkg)) continue;

        final blockedByRule = rolled.isPackageBlocked(pkg, moment);
        final unblocking = rolled.isPackageTemporarilyUnblocked(pkg, moment);
        if (!blockedByRule && !unblocking) continue;
        appsByPackage.putIfAbsent(pkg, () => app);
      }
    }

    for (final rule in _rules.whereType<TimeLimitRule>()) {
      final rolled = _timeLimitForMoment(rule, moment);
      if (!rolled.isRuleActive(moment)) continue;
      for (final app in rolled.apps) {
        final pkg = app.packageName;
        if (isEffectivelyAlwaysAllowed(pkg)) continue;
        if (isNeverAllowedPackage(pkg)) continue;

        final usage = effectiveTimeLimitUsage(rolled, pkg);
        final blockedByRule = rolled.isPackageBlocked(pkg, usage, moment);
        final unblocking = rolled.isPackageTemporarilyUnblocked(pkg, moment);
        if (!blockedByRule && !unblocking) continue;
        appsByPackage.putIfAbsent(pkg, () => app);
      }
    }

    final result = appsByPackage.entries.map((entry) {
      final pkg = entry.key;
      final hardBlocked = isPackageHardBlocked(pkg, moment);
      final window = _packageUnblockWindow(pkg, moment);
      final hasUnblock = window != null;
      final blockedByRule = _isBlockedByActiveRule(pkg, moment);
      final blocked = (hardBlocked || blockedByRule) &&
          (hardBlocked || !hasUnblock);
      return BlockedAppDisplay(
        app: entry.value,
        isBlocked: blocked,
        isHardBlocked: hardBlocked,
        unblockedUntil: window?.until,
        unblockedStartedAt: window?.started,
      );
    }).toList();

    result.sort((a, b) => a.app.appName.compareTo(b.app.appName));
    return result
        .where((d) => !WebsiteHelpers.isWebsitePackage(d.app.packageName))
        .toList();
  }

  /// Websites for the Blocked websites section — one entry per domain.
  List<BlockedAppDisplay> blockedWebsitesDisplay([DateTime? at]) {
    final moment = at ?? DateTime.now();
    final sitesByPackage = <String, AppRuleItem>{};

    for (final rule in _rules.whereType<SessionRule>()) {
      for (final app in rule.apps) {
        final pkg = app.packageName;
        if (!WebsiteHelpers.isWebsitePackage(pkg)) continue;
        if (isEffectivelyAlwaysAllowed(pkg)) continue;
        if (isNeverAllowedPackage(pkg)) continue;
        final showForBlock = _isBlockedByActiveRule(pkg, moment);
        final showForUnblock = hasActivePackageUnblock(pkg, moment);
        if (!showForBlock && !showForUnblock) continue;
        sitesByPackage.putIfAbsent(pkg, () => app);
      }
    }

    for (final rule in _rules.whereType<OpenLimitRule>()) {
      final rolled = _openLimitForMoment(rule, moment);
      if (!rolled.isRuleActive(moment)) continue;
      for (final app in rolled.apps) {
        final pkg = app.packageName;
        if (!WebsiteHelpers.isWebsitePackage(pkg)) continue;
        if (isEffectivelyAlwaysAllowed(pkg)) continue;
        if (isNeverAllowedPackage(pkg)) continue;

        final blockedByRule = rolled.isPackageBlocked(pkg, moment);
        final unblocking = rolled.isPackageTemporarilyUnblocked(pkg, moment);
        if (!blockedByRule && !unblocking) continue;
        sitesByPackage.putIfAbsent(pkg, () => app);
      }
    }

    for (final rule in _rules.whereType<TimeLimitRule>()) {
      final rolled = _timeLimitForMoment(rule, moment);
      if (!rolled.isRuleActive(moment)) continue;
      for (final app in rolled.apps) {
        final pkg = app.packageName;
        if (!WebsiteHelpers.isWebsitePackage(pkg)) continue;
        if (isEffectivelyAlwaysAllowed(pkg)) continue;
        if (isNeverAllowedPackage(pkg)) continue;

        final usage = effectiveTimeLimitUsage(rolled, pkg);
        final blockedByRule = rolled.isPackageBlocked(pkg, usage, moment);
        final unblocking = rolled.isPackageTemporarilyUnblocked(pkg, moment);
        if (!blockedByRule && !unblocking) continue;
        sitesByPackage.putIfAbsent(pkg, () => app);
      }
    }

    final result = sitesByPackage.entries.map((entry) {
      final pkg = entry.key;
      final hardBlocked = isPackageHardBlocked(pkg, moment);
      final window = _packageUnblockWindow(pkg, moment);
      final hasUnblock = window != null;
      final blockedByRule = _isBlockedByActiveRule(pkg, moment);
      final blocked = (hardBlocked || blockedByRule) &&
          (hardBlocked || !hasUnblock);
      return BlockedAppDisplay(
        app: entry.value,
        isBlocked: blocked,
        isHardBlocked: hardBlocked,
        unblockedUntil: window?.until,
        unblockedStartedAt: window?.started,
      );
    }).toList();

    result.sort(
      (a, b) => WebsiteHelpers.domainFromPackage(a.app.packageName)
          .compareTo(WebsiteHelpers.domainFromPackage(b.app.packageName)),
    );
    return result;
  }

  /// Display state for a single package (blocked apps row / detail screen).
  BlockedAppDisplay? displayForPackage(String packageName, [DateTime? at]) {
    final displays = WebsiteHelpers.isWebsitePackage(packageName)
        ? blockedWebsitesDisplay(at)
        : blockedAppsDisplay(at);
    for (final display in displays) {
      if (display.app.packageName == packageName) return display;
    }
    return null;
  }

  /// All apps shown in the Blocked apps row (schedule-active rules).
  List<AppRuleItem> get currentlyBlockedApps {
    return blockedAppsDisplay().map((d) => d.app).toList(growable: false);
  }

  List<AppRule> rulesForApp(String packageName) {
    return _rules
        .where((r) => r.apps.any((a) => a.packageName == packageName))
        .toList();
  }

  /// Session rules that include [packageName] — shown on a blocked app's
  /// detail screen. Indefinitely disabled rules are excluded.
  List<SessionRule> blockingRulesForApp(String packageName) {
    return _rules
        .whereType<SessionRule>()
        .where(
          (rule) =>
              rule.apps.any((a) => a.packageName == packageName) &&
              !rule.isIndefinitelyDisabled(),
        )
        .toList();
  }

  List<OpenLimitRule> openLimitRulesForApp(String packageName) {
    return _rules
        .whereType<OpenLimitRule>()
        .where(
          (rule) =>
              rule.apps.any((a) => a.packageName == packageName) &&
              !rule.isIndefinitelyDisabled(),
        )
        .toList();
  }

  List<TimeLimitRule> timeLimitRulesForApp(String packageName) {
    return _rules
        .whereType<TimeLimitRule>()
        .where(
          (rule) =>
              rule.apps.any((a) => a.packageName == packageName) &&
              !rule.isIndefinitelyDisabled(),
        )
        .toList();
  }

  void _clearUnblocksForPackages(Set<String> packageNames) {
    var changed = false;
    for (var i = 0; i < _rules.length; i++) {
      final rule = _rules[i];
      if (rule is SessionRule) {
        final until = Map<String, DateTime>.from(rule.unblockedUntilByPackage);
        final started =
            Map<String, DateTime>.from(rule.unblockedStartedAtByPackage);
        var ruleChanged = false;
        for (final pkg in packageNames) {
          if (until.remove(pkg) != null) ruleChanged = true;
          if (started.remove(pkg) != null) ruleChanged = true;
        }
        if (ruleChanged) {
          _rules[i] = rule.copyWith(
            unblockedUntilByPackage: until,
            unblockedStartedAtByPackage: started,
          );
          changed = true;
        }
      } else if (rule is OpenLimitRule) {
        final until = Map<String, DateTime>.from(rule.unblockedUntilByPackage);
        final started =
            Map<String, DateTime>.from(rule.unblockedStartedAtByPackage);
        var ruleChanged = false;
        for (final pkg in packageNames) {
          if (until.remove(pkg) != null) ruleChanged = true;
          if (started.remove(pkg) != null) ruleChanged = true;
        }
        if (ruleChanged) {
          _rules[i] = rule.copyWith(
            unblockedUntilByPackage: until,
            unblockedStartedAtByPackage: started,
          );
          changed = true;
        }
      } else if (rule is TimeLimitRule) {
        final until = Map<String, DateTime>.from(rule.unblockedUntilByPackage);
        final started =
            Map<String, DateTime>.from(rule.unblockedStartedAtByPackage);
        var ruleChanged = false;
        for (final pkg in packageNames) {
          if (until.remove(pkg) != null) ruleChanged = true;
          if (started.remove(pkg) != null) ruleChanged = true;
        }
        if (ruleChanged) {
          _rules[i] = rule.copyWith(
            unblockedUntilByPackage: until,
            unblockedStartedAtByPackage: started,
          );
          changed = true;
        }
      }
    }
    if (changed) {
      _save();
    }
  }

  Future<void> _scheduleUnblockEndedNotifications({
    required String ruleId,
    required Map<String, DateTime> untilByPackage,
    required Iterable<String> packages,
  }) async {
    for (final pkg in packages) {
      final until = untilByPackage[pkg];
      if (until == null) continue;
      await RuleNotificationService.instance.scheduleUnblockEnded(
        dedupeKey: '$ruleId|$pkg',
        until: until,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reEnableTimer?.cancel();
    super.dispose();
  }
}
