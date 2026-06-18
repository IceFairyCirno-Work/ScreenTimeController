import 'package:flutter_test/flutter_test.dart';
import 'package:screen_time_controller/models/gem_achievement.dart';
import 'package:screen_time_controller/models/screen_timer_controller_metrics.dart';
import 'package:screen_time_controller/services/gem_achievement_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const zeroMetrics = ScreenTimerControllerMetrics(
    score: 0,
    sleep: 0,
    sleepScore: 0,
    focus: 0,
    rest: 0,
  );

  const perfectMetrics = ScreenTimerControllerMetrics(
    score: 100,
    sleep: 0,
    sleepScore: 100,
    focus: 100,
    rest: 100,
  );

  group('GemAchievementService.getHeroAssetPath', () {
    test('returns first_gem when nothing is unlocked', () {
      final service = GemAchievementService();
      expect(
        service.getHeroAssetPath(),
        GemAchievementIdX.defaultHeroAsset,
      );
    });

    test('uses selected hero gem when set', () {
      final service = GemAchievementService();
      service.setUnlocksForTest({
        GemAchievementId.firstStreak: DateTime(2026, 6, 1),
        GemAchievementId.streak5: DateTime(2026, 6, 10),
      });
      service.setSelectedHeroGemForTest(GemAchievementId.firstStreak);

      expect(
        service.getHeroAssetPath(),
        GemAchievementId.firstStreak.assetPath,
      );
    });

    test('returns default hero when unlocked but none is selected', () {
      final service = GemAchievementService();
      service.setUnlocksForTest({
        GemAchievementId.firstStreak: DateTime(2026, 6, 1),
        GemAchievementId.streak5: DateTime(2026, 6, 10),
      });
      expect(
        service.getHeroAssetPath(),
        GemAchievementIdX.defaultHeroAsset,
      );
    });

    test('uses explicitly selected gem among multiple unlocks', () {
      final service = GemAchievementService();
      final sameMoment = DateTime(2026, 6, 10, 12);
      service.setUnlocksForTest({
        GemAchievementId.firstStreak: sameMoment,
        GemAchievementId.streak5: sameMoment,
      });
      service.setSelectedHeroGemForTest(GemAchievementId.streak5);

      expect(
        service.getHeroAssetPath(),
        GemAchievementId.streak5.assetPath,
      );
    });
  });

  group('GemAchievementService.evaluate', () {
    late GemAchievementService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = GemAchievementService();
    });

    test('unlocks streak milestones from streak count', () async {
      final pending = await service.evaluate(
        streakCount: 10,
        metrics: zeroMetrics,
        metricsHasPermission: false,
        now: DateTime(2026, 6, 17),
      );

      expect(service.unlocks.keys, contains(GemAchievementId.streak5));
      expect(service.unlocks.keys, contains(GemAchievementId.streak10));
      expect(service.unlocks.keys, isNot(contains(GemAchievementId.streak30)));
      expect(service.unlocks.keys, isNot(contains(GemAchievementId.firstStreak)));
      expect(pending, hasLength(2));
    });

    test('does not auto-equip latest gem after evaluation', () async {
      await service.evaluate(
        streakCount: 10,
        metrics: zeroMetrics,
        metricsHasPermission: false,
        now: DateTime(2026, 6, 17),
      );

      expect(
        service.getHeroAssetPath(),
        GemAchievementIdX.defaultHeroAsset,
      );
    });

    test('unlocks metric gems only when permission is granted', () async {
      await service.evaluate(
        streakCount: 0,
        metrics: perfectMetrics,
        metricsHasPermission: false,
      );
      expect(service.unlocks, isEmpty);

      await service.evaluate(
        streakCount: 0,
        metrics: perfectMetrics,
        metricsHasPermission: true,
        now: DateTime(2026, 6, 18),
      );
      expect(service.unlocks.keys, contains(GemAchievementId.focus100));
      expect(service.unlocks.keys, contains(GemAchievementId.score100));
    });

    test('keeps metric gems after scores drop', () async {
      await service.evaluate(
        streakCount: 0,
        metrics: perfectMetrics,
        metricsHasPermission: true,
        now: DateTime(2026, 6, 18),
      );

      await service.evaluate(
        streakCount: 0,
        metrics: zeroMetrics,
        metricsHasPermission: true,
        now: DateTime(2026, 6, 19),
      );

      expect(service.unlocks.keys, contains(GemAchievementId.score100));
      expect(
        service.getHeroAssetPath(),
        GemAchievementIdX.defaultHeroAsset,
      );
    });

    test('unlocks timerFull when timer naturally completes', () async {
      await service.evaluate(
        streakCount: 0,
        metrics: zeroMetrics,
        metricsHasPermission: false,
        timerJustCompleted: true,
        now: DateTime(2026, 6, 20),
      );

      expect(service.unlocks.keys, contains(GemAchievementId.timerFull));
      expect(
        service.getHeroAssetPath(),
        GemAchievementIdX.defaultHeroAsset,
      );
    });

    test('returns pending unlock sheets for unseen gems', () async {
      final firstUnlock = await service.unlockWelcomeGem(
        now: DateTime(2026, 6, 17),
      );

      expect(firstUnlock, isNotNull);
      expect(firstUnlock!.id, GemAchievementId.firstStreak);
      expect(firstUnlock.title, 'FIRST GEM');

      final stillPending = await service.unlockWelcomeGem();
      expect(stillPending, isNotNull);

      await service.markUnlockSheetShown(GemAchievementId.firstStreak);

      final afterShown = await service.unlockWelcomeGem();
      expect(afterShown, isNull);
    });

    test('welcome gem is awarded for downloading Silo, not streak', () async {
      await service.evaluate(
        streakCount: 30,
        metrics: zeroMetrics,
        metricsHasPermission: false,
        now: DateTime(2026, 6, 17),
      );

      expect(service.unlocks.containsKey(GemAchievementId.firstStreak), isFalse);

      final welcome = await service.unlockWelcomeGem(
        now: DateTime(2026, 6, 17),
      );
      expect(welcome?.id, GemAchievementId.firstStreak);
      expect(welcome?.subtitle, 'You downloaded Silo');
    });

    test('unlockAndSelectHeroGem unlocks and equips a gem for testing', () async {
      await service.unlockAndSelectHeroGem(
        GemAchievementId.streak10,
        unlockedAt: DateTime(2026, 6, 17),
      );

      expect(service.unlocks.keys, contains(GemAchievementId.streak10));
      expect(
        service.getHeroAssetPath(),
        GemAchievementId.streak10.assetPath,
      );
    });

    test('persists unlock timestamps to shared preferences', () async {
      await service.unlockWelcomeGem(
        now: DateTime(2026, 6, 17, 9, 30),
      );

      final prefs = await SharedPreferences.getInstance();
      final restored = GemAchievementService();
      await restored.load();

      expect(
        restored.unlocks[GemAchievementId.firstStreak],
        DateTime(2026, 6, 17, 9, 30),
      );
      expect(prefs.getString('gem_unlock_timestamps'), isNotNull);
    });
  });
}
