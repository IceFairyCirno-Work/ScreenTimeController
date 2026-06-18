import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_rule.dart';

/// Manages the once-per-7-days emergency pass that bypasses all blocking for 30m.
class EmergencyPassProvider extends ChangeNotifier {
  static const _keyLastRedeemedAt = 'emergency_pass_last_redeemed_at';
  static const _keyActiveUntil = 'emergency_pass_active_until';
  static const cooldown = Duration(days: 7);
  static const passDuration = Duration(minutes: 30);

  /// Formats a duration as `29m45s`.
  static String formatDurationLabel(Duration duration) {
    final totalSeconds = duration.inSeconds.clamp(0, 999999);
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes}m${seconds.toString().padLeft(2, '0')}s';
  }

  DateTime? _lastRedeemedAt;
  DateTime? _activeUntil;
  bool _initialized = false;
  Timer? _tickTimer;

  bool get initialized => _initialized;
  DateTime? get lastRedeemedAt => _lastRedeemedAt;

  bool get isActive {
    final until = _activeUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  DateTime? get activeUntil => isActive ? _activeUntil : null;

  Duration? get activeRemaining {
    final until = _activeUntil;
    if (until == null || !isActive) return null;
    return until.difference(DateTime.now());
  }

  bool get canRedeem {
    if (isActive) return false;
    final last = _lastRedeemedAt;
    if (last == null) return true;
    return DateTime.now().difference(last) >= cooldown;
  }

  Duration? get cooldownRemaining {
    if (canRedeem) return null;
    final last = _lastRedeemedAt;
    if (last == null || isActive) return null;
    final next = last.add(cooldown);
    final remaining = next.difference(DateTime.now());
    if (remaining.isNegative) return Duration.zero;
    return remaining;
  }

  /// Keeps the blocked-apps row intact while showing every app as unblocked
  /// with the emergency pass countdown.
  List<BlockedAppDisplay> overlayBlockedAppDisplays(
    List<BlockedAppDisplay> displays,
  ) {
    if (!isActive) return displays;
    final until = _activeUntil;
    if (until == null) return displays;

    final started = until.subtract(passDuration);
    return displays
        .map(
          (display) => BlockedAppDisplay(
            app: display.app,
            isBlocked: false,
            isHardBlocked: false,
            unblockedUntil: until,
            unblockedStartedAt: started,
          ),
        )
        .toList();
  }

  BlockedAppDisplay? overlayBlockedAppDisplay(BlockedAppDisplay? display) {
    if (display == null) return null;
    final overlaid = overlayBlockedAppDisplays([display]);
    return overlaid.isEmpty ? display : overlaid.first;
  }

  bool get manualUnblocksDisabled => isActive;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastMs = prefs.getInt(_keyLastRedeemedAt);
      final untilMs = prefs.getInt(_keyActiveUntil);
      _lastRedeemedAt =
          lastMs == null ? null : DateTime.fromMillisecondsSinceEpoch(lastMs);
      _activeUntil =
          untilMs == null ? null : DateTime.fromMillisecondsSinceEpoch(untilMs);
      _pruneExpiredActivePass();
    } catch (e, stack) {
      debugPrint('Failed to load emergency pass: $e\n$stack');
    } finally {
      _initialized = true;
      _startTickTimer();
      notifyListeners();
    }
  }

  Future<bool> redeem() async {
    if (!canRedeem) return false;
    final now = DateTime.now();
    _lastRedeemedAt = now;
    _activeUntil = now.add(passDuration);
    await _persist();
    notifyListeners();
    return true;
  }

  void resetAfterAccountDeletion() {
    _lastRedeemedAt = null;
    _activeUntil = null;
    notifyListeners();
  }

  void _pruneExpiredActivePass() {
    final until = _activeUntil;
    if (until != null && !DateTime.now().isBefore(until)) {
      _activeUntil = null;
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    if (_lastRedeemedAt == null) {
      await prefs.remove(_keyLastRedeemedAt);
    } else {
      await prefs.setInt(
        _keyLastRedeemedAt,
        _lastRedeemedAt!.millisecondsSinceEpoch,
      );
    }
    if (_activeUntil == null) {
      await prefs.remove(_keyActiveUntil);
    } else {
      await prefs.setInt(
        _keyActiveUntil,
        _activeUntil!.millisecondsSinceEpoch,
      );
    }
  }

  void _startTickTimer() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final wasActive = isActive;
      _pruneExpiredActivePass();
      if (wasActive || isActive || cooldownRemaining != null) {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }
}
