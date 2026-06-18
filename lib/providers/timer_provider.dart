import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_rule.dart';
import '../services/streak_service.dart';
import '../services/app_blocking_service.dart';

/// Timer session state shared with app blocking sync.
class TimerProvider extends ChangeNotifier with WidgetsBindingObserver {
  static const _storageKey = 'active_timer_session';

  final AppBlockingService _blockingService = AppBlockingService();
  final StreakService _streakService = StreakService();

  bool _isRunning = false;
  int _remainingSeconds = 0;
  bool _isInfiniteMode = false;
  List<AppRuleItem> _blockedApps = [];
  int? _endTimeMs;
  int? _startedAtMs;
  bool _initialized = false;
  bool _openTimerTabOnNextShell = false;
  bool _playEnterAnimationOnNextActiveShell = false;
  bool _timerNaturallyCompleted = false;
  Timer? _timer;

  TimerProvider() {
    WidgetsBinding.instance.addObserver(this);
  }

  bool get isRunning => _isRunning;
  int get remainingSeconds => _remainingSeconds;
  bool get isInfiniteMode => _isInfiniteMode;
  bool get initialized => _initialized;
  List<AppRuleItem> get blockedApps => List.unmodifiable(_blockedApps);

  /// Consumed once when [ActiveTimerShell] mounts after the user starts a session.
  bool consumePlayEnterAnimation() {
    if (!_playEnterAnimationOnNextActiveShell) return false;
    _playEnterAnimationOnNextActiveShell = false;
    return true;
  }

  /// Consumed once when [HomeShell] mounts after the countdown ends.
  bool consumeOpenTimerTab() {
    if (!_openTimerTabOnNextShell) return false;
    _openTimerTabOnNextShell = false;
    return true;
  }

  /// Consumed once when a finite timer naturally reaches zero.
  bool consumeTimerNaturallyCompleted() {
    if (!_timerNaturallyCompleted) return false;
    _timerNaturallyCompleted = false;
    return true;
  }

  void ensureInitializedForStartup() {
    if (_initialized) return;
    _initialized = true;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      unawaited(_persistSession());
    }
  }

  Future<void> load() async {
    if (_initialized) return;

    try {
      Map<String, dynamic>? flutterState;
      try {
        final prefs = await SharedPreferences.getInstance().timeout(
          const Duration(seconds: 8),
        );
        final jsonStr = prefs.getString(_storageKey);
        if (jsonStr != null && jsonStr.isNotEmpty) {
          flutterState = jsonDecode(jsonStr) as Map<String, dynamic>;
        }
      } on TimeoutException {
        debugPrint('Timer session prefs load timed out during startup');
      } catch (e, stack) {
        debugPrint('Failed to load timer session from prefs: $e\n$stack');
      }

      Map<String, dynamic>? nativeState;
      if (!kIsWeb && Platform.isAndroid) {
        try {
          nativeState = await _blockingService
              .getActiveTimer()
              .timeout(const Duration(seconds: 5));
        } on TimeoutException {
          debugPrint('Native active timer read timed out during startup');
        } catch (e, stack) {
          debugPrint('Failed to load timer session from native: $e\n$stack');
        }
      }

      final restored = _pickRestoredState(flutterState, nativeState);
      if (restored != null) {
        _applyPersistedState(restored);
      }
    } catch (e, stack) {
      debugPrint('Failed to restore timer session: $e\n$stack');
      _clearSessionState(notify: false);
      unawaited(_persistSession());
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Map<String, dynamic>? _pickRestoredState(
    Map<String, dynamic>? flutterState,
    Map<String, dynamic>? nativeState,
  ) {
    final candidates = <Map<String, dynamic>>[];
    if (flutterState != null) candidates.add(flutterState);
    if (nativeState != null) {
      candidates.add(_normalizeNativeState(nativeState));
    }

    Map<String, dynamic>? best;
    var bestRemainingMs = -1;

    for (final candidate in candidates) {
      final remainingMs = _remainingMsForState(candidate);
      if (remainingMs == null) continue;
      if (remainingMs > bestRemainingMs) {
        bestRemainingMs = remainingMs;
        best = candidate;
      }
    }

    if (best != null) return best;

    for (final candidate in candidates) {
      if (candidate['isRunning'] == true && candidate['isInfiniteMode'] == true) {
        return candidate;
      }
    }

    if (flutterState != null && flutterState['isRunning'] != true) {
      return flutterState;
    }
    return flutterState ?? nativeState;
  }

  Map<String, dynamic> _normalizeNativeState(Map<String, dynamic> native) {
    final blockedAppsJson = native['blockedAppsJson'];
    dynamic blockedApps = const [];
    if (blockedAppsJson is String && blockedAppsJson.isNotEmpty) {
      try {
        blockedApps = jsonDecode(blockedAppsJson);
      } catch (e) {
        debugPrint('Failed to decode native timer blocked apps: $e');
      }
    }

    return {
      'isRunning': native['isRunning'] == true,
      'isInfiniteMode': native['isInfiniteMode'] == true,
      'endTimeMs': _readInt(native['endTimeMs']),
      'startedAtMs': _readInt(native['startedAtMs']),
      'blockedApps': blockedApps,
    };
  }

  int? _remainingMsForState(Map<String, dynamic> json) {
    if (json['isRunning'] != true) return null;
    if (json['isInfiniteMode'] == true) return 1 << 30;

    final endTimeMs = _readInt(json['endTimeMs']);
    if (endTimeMs == null) return null;
    return endTimeMs - DateTime.now().millisecondsSinceEpoch;
  }

  int? _readInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  void _applyPersistedState(Map<String, dynamic> json) {
    final blockedAppsJson = json['blockedApps'];
    if (blockedAppsJson is List) {
      _blockedApps = blockedAppsJson
          .whereType<Map<String, dynamic>>()
          .map((item) {
            try {
              return AppRuleItem.fromJson(item);
            } catch (e) {
              debugPrint('Skipping corrupt timer blocked app entry: $e');
              return null;
            }
          })
          .whereType<AppRuleItem>()
          .toList();
    }

    if (json['isRunning'] != true) return;

    _isInfiniteMode = json['isInfiniteMode'] == true;
    _endTimeMs = _readInt(json['endTimeMs']);
    _startedAtMs = _readInt(json['startedAtMs']);

    if (_isInfiniteMode) {
      if (_startedAtMs == null) return;
      _remainingSeconds = _elapsedSecondsSince(_startedAtMs!);
      _resumeRunningSession(notify: false);
      unawaited(_recordStreakForRestoredSession());
      return;
    }

    if (_endTimeMs == null) return;
    final remainingMs = _endTimeMs! - DateTime.now().millisecondsSinceEpoch;
    if (remainingMs <= 0) {
      _clearSessionState(notify: false);
      unawaited(_persistSession());
      return;
    }

    _remainingSeconds = (remainingMs / 1000).ceil();
    _resumeRunningSession(notify: false);
    unawaited(_recordStreakForRestoredSession());
  }

  Future<void> _recordStreakForRestoredSession() async {
    if (!_isRunning) return;
    if (_startedAtMs != null) {
      await _streakService.recordTimerStart(
        DateTime.fromMillisecondsSinceEpoch(_startedAtMs!),
      );
      return;
    }
    await _streakService.recordTimerStart();
  }

  Future<void> startTimer({
    required Duration duration,
    required bool infiniteMode,
  }) async {
    final now = DateTime.now();
    _isInfiniteMode = infiniteMode;
    if (infiniteMode) {
      _startedAtMs = now.millisecondsSinceEpoch;
      _endTimeMs = null;
      _remainingSeconds = 0;
    } else {
      _endTimeMs = now.add(duration).millisecondsSinceEpoch;
      _startedAtMs = null;
      _remainingSeconds = duration.inSeconds;
    }
    _isRunning = true;
    _playEnterAnimationOnNextActiveShell = true;
    notifyListeners();
    _startTick();
    await Future.wait([
      _persistSession(),
      _streakService.recordTimerStart(now),
    ]);
  }

  Future<void> startFromTemplate(Duration duration) async {
    _isInfiniteMode = false;
    final now = DateTime.now();
    _endTimeMs = now.add(duration).millisecondsSinceEpoch;
    _startedAtMs = null;
    _remainingSeconds = duration.inSeconds;
    _isRunning = true;
    _playEnterAnimationOnNextActiveShell = true;
    notifyListeners();
    _startTick();
    await Future.wait([
      _persistSession(),
      _streakService.recordTimerStart(now),
    ]);
  }

  void _resumeRunningSession({bool notify = true}) {
    _isRunning = true;
    _startTick();
    if (notify) {
      notifyListeners();
    }
  }

  void _startTick() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isInfiniteMode) {
        if (_startedAtMs == null) {
          stopTimer();
          return;
        }
        _remainingSeconds = _elapsedSecondsSince(_startedAtMs!);
      } else if (_endTimeMs == null) {
        stopTimer();
        return;
      } else {
        final remainingMs =
            _endTimeMs! - DateTime.now().millisecondsSinceEpoch;
        if (remainingMs <= 0) {
          _timerNaturallyCompleted = true;
          stopTimer();
          return;
        }
        _remainingSeconds = (remainingMs / 1000).ceil();
      }
      notifyListeners();
      unawaited(_persistSession());
    });
  }

  int _elapsedSecondsSince(int startedAtMs) {
    final elapsedMs = DateTime.now().millisecondsSinceEpoch - startedAtMs;
    return elapsedMs > 0 ? elapsedMs ~/ 1000 : 0;
  }

  Future<void> stopTimer() async {
    _timer?.cancel();
    _timer = null;
    if (!_isRunning && _remainingSeconds == 0) return;
    _openTimerTabOnNextShell = true;
    _clearSessionState();
    notifyListeners();
    await _persistSession();
  }

  void _clearSessionState({bool notify = true}) {
    _isRunning = false;
    _remainingSeconds = 0;
    _isInfiniteMode = false;
    _endTimeMs = null;
    _startedAtMs = null;
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> setBlockedApps(List<AppRuleItem> apps) async {
    _blockedApps = List<AppRuleItem>.from(apps);
    notifyListeners();
    await _persistSession();
  }

  void resetAfterAccountDeletion() {
    _timer?.cancel();
    _timer = null;
    _blockedApps = [];
    _openTimerTabOnNextShell = false;
    _playEnterAnimationOnNextActiveShell = false;
    _timerNaturallyCompleted = false;
    _clearSessionState(notify: false);
    notifyListeners();
  }

  Future<void> _persistSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_isRunning && _blockedApps.isEmpty) {
        await prefs.remove(_storageKey);
        if (!kIsWeb && Platform.isAndroid) {
          await _blockingService.clearActiveTimer();
        }
        return;
      }

      final blockedAppsJson =
          jsonEncode(_blockedApps.map((app) => app.toJson()).toList());
      final payload = <String, dynamic>{
        'isRunning': _isRunning,
        'isInfiniteMode': _isInfiniteMode,
        'blockedApps': _blockedApps.map((app) => app.toJson()).toList(),
      };

      if (_isRunning) {
        if (_isInfiniteMode) {
          payload['startedAtMs'] = _startedAtMs;
        } else {
          payload['endTimeMs'] = _endTimeMs;
        }
      }

      await prefs.setString(_storageKey, jsonEncode(payload));

      if (!kIsWeb && Platform.isAndroid) {
        if (_isRunning) {
          await _blockingService.syncActiveTimer(
            isRunning: true,
            isInfiniteMode: _isInfiniteMode,
            endTimeMs: _endTimeMs,
            startedAtMs: _startedAtMs,
            blockedAppsJson: blockedAppsJson,
          );
        } else {
          await _blockingService.clearActiveTimer();
        }
      }
    } catch (e, stack) {
      debugPrint('Failed to persist timer session: $e\n$stack');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }
}
