import 'package:flutter/foundation.dart';

import '../models/gem_achievement.dart';
import '../models/gem_unlock_info.dart';
import '../models/screen_timer_controller_metrics.dart';
import '../services/gem_achievement_service.dart';

class GemAchievementProvider extends ChangeNotifier {
  final GemAchievementService _service = GemAchievementService();

  bool _initialized = false;

  bool get initialized => _initialized;
  String get heroAssetPath => _service.getHeroAssetPath();

  void ensureInitializedForStartup() {
    if (_initialized) return;
    _initialized = true;
    notifyListeners();
  }

  Future<void> load() async {
    if (_initialized) return;
    try {
      await _service.load();
    } catch (e, stack) {
      debugPrint('Failed to load gem achievements: $e\n$stack');
    } finally {
      if (!_initialized) {
        _initialized = true;
        notifyListeners();
      }
    }
  }

  Future<List<GemUnlockInfo>> evaluate({
    required int streakCount,
    required ScreenTimerControllerMetrics metrics,
    required bool metricsHasPermission,
    bool timerJustCompleted = false,
  }) async {
    final pending = await _service.evaluate(
      streakCount: streakCount,
      metrics: metrics,
      metricsHasPermission: metricsHasPermission,
      timerJustCompleted: timerJustCompleted,
    );
    if (pending.isNotEmpty || !_initialized) {
      notifyListeners();
    }
    return pending;
  }

  Future<GemUnlockInfo?> prepareWelcomeGem() async {
    final info = await _service.unlockWelcomeGem();
    if (info != null) {
      notifyListeners();
    }
    return info;
  }

  Future<void> markUnlockSheetShown(GemAchievementId id) async {
    await _service.markUnlockSheetShown(id);
  }

  Future<void> markUnlockSheetsShown(Set<GemAchievementId> ids) async {
    await _service.markUnlockSheetsShown(ids);
  }

  Future<void> setSelectedHeroGem(GemAchievementId id) async {
    await _service.setSelectedHeroGem(id);
    notifyListeners();
  }

  Future<void> unlockAndSelectHeroGem(GemAchievementId id) async {
    await _service.unlockAndSelectHeroGem(id);
    notifyListeners();
  }

  void resetAfterAccountDeletion() {
    _service.reset();
    notifyListeners();
  }

  bool isSelectedHeroGem(GemAchievementId id) =>
      _service.isSelectedHeroGem(id);

  bool get hasSelectedHeroGem => _service.hasSelectedHeroGem;
}
