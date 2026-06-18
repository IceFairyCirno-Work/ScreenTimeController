import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/gem_achievement.dart';
import '../models/gem_unlock_info.dart';
import '../models/screen_timer_controller_metrics.dart';

class GemAchievementService {
  static const _keyUnlockTimestamps = 'gem_unlock_timestamps';
  static const _keyShownUnlockSheets = 'gem_shown_unlock_sheets';
  static const _keySheetsMigrated = 'gem_unlock_sheets_migrated';
  static const _keySelectedHeroGem = 'gem_selected_hero';

  Map<GemAchievementId, DateTime> _unlocks = {};
  Set<GemAchievementId> _shownUnlockSheets = {};
  GemAchievementId? _selectedHeroGemId;

  Map<GemAchievementId, DateTime> get unlocks => Map.unmodifiable(_unlocks);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _unlocks = _decodeUnlocks(prefs.getString(_keyUnlockTimestamps));
      _shownUnlockSheets = _decodeShown(prefs.getString(_keyShownUnlockSheets));
      _selectedHeroGemId =
          _idFromStorageKey(prefs.getString(_keySelectedHeroGem) ?? '');

      if (!(prefs.getBool(_keySheetsMigrated) ?? false)) {
        _shownUnlockSheets = _unlocks.keys.toSet();
        await _persistShownUnlockSheets();
        await prefs.setBool(_keySheetsMigrated, true);
      }
    } catch (e, stack) {
      debugPrint('Failed to load gem achievements: $e\n$stack');
    }
  }

  /// Evaluates criteria, persists unlocks, and returns gems pending unlock UI.
  ///
  /// When true, metric-based gems may be awarded. Callers should also require
  /// real usage data (e.g. today's total screen time > 0).
  Future<List<GemUnlockInfo>> evaluate({
    required int streakCount,
    required ScreenTimerControllerMetrics metrics,
    required bool metricsHasPermission,
    bool timerJustCompleted = false,
    DateTime? now,
  }) async {
    final moment = now ?? DateTime.now();
    final newlyUnlocked = <GemAchievementId>[];

    if (streakCount >= 5) newlyUnlocked.add(GemAchievementId.streak5);
    if (streakCount >= 10) newlyUnlocked.add(GemAchievementId.streak10);
    if (streakCount >= 30) newlyUnlocked.add(GemAchievementId.streak30);
    if (streakCount >= 60) newlyUnlocked.add(GemAchievementId.streak60);
    if (streakCount >= 100) newlyUnlocked.add(GemAchievementId.streak100);
    if (streakCount >= 365) newlyUnlocked.add(GemAchievementId.streak365);

    if (metricsHasPermission) {
      if (metrics.focus >= 100) newlyUnlocked.add(GemAchievementId.focus100);
      if (metrics.rest >= 100) newlyUnlocked.add(GemAchievementId.rest100);
      if (metrics.sleepScore >= 100) {
        newlyUnlocked.add(GemAchievementId.sleep100);
      }
      if (metrics.score >= 100) newlyUnlocked.add(GemAchievementId.score100);
    }

    if (timerJustCompleted) {
      newlyUnlocked.add(GemAchievementId.timerFull);
    }

    var changed = false;
    for (final id in newlyUnlocked) {
      if (_unlocks.containsKey(id)) continue;
      _unlocks[id] = moment;
      changed = true;
    }

    if (changed) {
      await _persistUnlocks();
    }

    return _pendingUnlockInfos(includeWelcomeGem: false);
  }

  /// Awards the welcome gem for downloading Silo and returns sheet info if
  /// it still needs to be shown before the user enters home.
  Future<GemUnlockInfo?> unlockWelcomeGem({DateTime? now}) async {
    final moment = now ?? DateTime.now();
    if (!_unlocks.containsKey(GemAchievementId.firstStreak)) {
      _unlocks[GemAchievementId.firstStreak] = moment;
      await _persistUnlocks();
    }

    if (_shownUnlockSheets.contains(GemAchievementId.firstStreak)) {
      return null;
    }

    return GemUnlockInfo.fromUnlock(
      id: GemAchievementId.firstStreak,
      unlockedAt: _unlocks[GemAchievementId.firstStreak]!,
    );
  }

  Future<void> markUnlockSheetShown(GemAchievementId id) async {
    await markUnlockSheetsShown({id});
  }

  Future<void> markUnlockSheetsShown(Set<GemAchievementId> ids) async {
    var changed = false;
    for (final id in ids) {
      if (_shownUnlockSheets.contains(id)) continue;
      _shownUnlockSheets.add(id);
      changed = true;
    }
    if (changed) {
      await _persistShownUnlockSheets();
    }
  }

  Future<void> setSelectedHeroGem(GemAchievementId id) async {
    if (!_unlocks.containsKey(id)) return;
    _selectedHeroGemId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedHeroGem, id.storageKey);
  }

  /// Unlocks [id] when needed, then sets it as the home hero gem.
  Future<void> unlockAndSelectHeroGem(
    GemAchievementId id, {
    DateTime? unlockedAt,
  }) async {
    final moment = unlockedAt ?? DateTime.now();
    var unlocksChanged = false;
    if (!_unlocks.containsKey(id)) {
      _unlocks[id] = moment;
      unlocksChanged = true;
    }
    _selectedHeroGemId = id;

    final prefs = await SharedPreferences.getInstance();
    if (unlocksChanged) {
      await _persistUnlocks();
    }
    await prefs.setString(_keySelectedHeroGem, id.storageKey);
  }

  bool isSelectedHeroGem(GemAchievementId id) => _selectedHeroGemId == id;

  bool get hasSelectedHeroGem =>
      _selectedHeroGemId != null &&
      _unlocks.containsKey(_selectedHeroGemId);

  String getHeroAssetPath() {
    if (_selectedHeroGemId != null &&
        _unlocks.containsKey(_selectedHeroGemId)) {
      return _selectedHeroGemId!.assetPath;
    }

    return GemAchievementIdX.defaultHeroAsset;
  }

  GemAchievementId? get latestUnlockedId {
    if (_unlocks.isEmpty) return null;
    return _unlocks.entries.reduce((a, b) {
      final timeCompare = a.value.compareTo(b.value);
      if (timeCompare != 0) {
        return timeCompare > 0 ? a : b;
      }
      return a.key.index > b.key.index ? a : b;
    }).key;
  }

  List<GemUnlockInfo> _pendingUnlockInfos({bool includeWelcomeGem = true}) {
    final pending = _unlocks.entries
        .where((entry) {
          if (!includeWelcomeGem &&
              entry.key == GemAchievementId.firstStreak) {
            return false;
          }
          return !_shownUnlockSheets.contains(entry.key);
        })
        .map(
          (entry) => GemUnlockInfo.fromUnlock(
            id: entry.key,
            unlockedAt: entry.value,
          ),
        )
        .toList()
      ..sort((a, b) {
        final timeCompare = a.unlockedAt.compareTo(b.unlockedAt);
        if (timeCompare != 0) return timeCompare;
        return a.id.index.compareTo(b.id.index);
      });
    return pending;
  }

  Future<void> _persistUnlocks() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = <String, String>{
      for (final entry in _unlocks.entries)
        entry.key.storageKey: entry.value.toIso8601String(),
    };
    await prefs.setString(_keyUnlockTimestamps, jsonEncode(encoded));
  }

  Future<void> _persistShownUnlockSheets() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = _shownUnlockSheets.map((id) => id.storageKey).toList()
      ..sort();
    await prefs.setString(_keyShownUnlockSheets, jsonEncode(encoded));
  }

  Map<GemAchievementId, DateTime> _decodeUnlocks(String? raw) {
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final result = <GemAchievementId, DateTime>{};
      for (final entry in decoded.entries) {
        final id = _idFromStorageKey(entry.key.toString());
        if (id == null) continue;
        final parsed = DateTime.tryParse(entry.value.toString());
        if (parsed != null) {
          result[id] = parsed;
        }
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  Set<GemAchievementId> _decodeShown(String? raw) {
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return {};
      return decoded
          .map((value) => _idFromStorageKey(value.toString()))
          .whereType<GemAchievementId>()
          .toSet();
    } catch (_) {
      return {};
    }
  }

  GemAchievementId? _idFromStorageKey(String key) {
    for (final value in GemAchievementId.values) {
      if (value.storageKey == key) return value;
    }
    return null;
  }

  @visibleForTesting
  void setUnlocksForTest(Map<GemAchievementId, DateTime> unlocks) {
    _unlocks = Map.from(unlocks);
  }

  void reset() {
    _unlocks = {};
    _shownUnlockSheets = {};
    _selectedHeroGemId = null;
  }

  @visibleForTesting
  void setSelectedHeroGemForTest(GemAchievementId? id) {
    _selectedHeroGemId = id;
  }
}
