/// Achievement gems shown on the home hero.
enum GemAchievementId {
  firstStreak,
  streak5,
  streak10,
  streak30,
  streak60,
  streak100,
  streak365,
  focus100,
  rest100,
  sleep100,
  score100,
  timerFull,
}

extension GemAchievementIdX on GemAchievementId {
  static const defaultHeroAsset = 'assets/images/first_gem.png';

  String get assetPath => switch (this) {
        GemAchievementId.firstStreak => 'assets/images/first_gem.png',
        GemAchievementId.streak5 => 'assets/images/5day_gem.png',
        GemAchievementId.streak10 => 'assets/images/10day_gem.png',
        GemAchievementId.streak30 => 'assets/images/30day_gem.png',
        GemAchievementId.streak60 => 'assets/images/60streak_gem.png',
        GemAchievementId.streak100 => 'assets/images/100streak_gem.png',
        GemAchievementId.streak365 => 'assets/images/365day_gem.png',
        GemAchievementId.focus100 => 'assets/images/focus100_gem.png',
        GemAchievementId.rest100 => 'assets/images/rest100_gem.png',
        GemAchievementId.sleep100 => 'assets/images/sleep100_gem.png',
        GemAchievementId.score100 => 'assets/images/score100_gem.png',
        GemAchievementId.timerFull => 'assets/images/timerfull_gem.png',
      };

  /// Cropped assets used in achievement unlock showcase UI.
  String get showcaseAssetPath => switch (this) {
        GemAchievementId.firstStreak => 'assets/cropped/first.PNG',
        GemAchievementId.streak5 => 'assets/cropped/5day.PNG',
        GemAchievementId.streak10 => 'assets/cropped/10day.PNG',
        GemAchievementId.streak30 => 'assets/cropped/30day.PNG',
        GemAchievementId.streak60 => 'assets/cropped/60day.PNG',
        GemAchievementId.streak100 => 'assets/cropped/100day.PNG',
        GemAchievementId.streak365 => 'assets/cropped/365day.PNG',
        GemAchievementId.focus100 => 'assets/cropped/focus100.PNG',
        GemAchievementId.rest100 => 'assets/cropped/rest100.PNG',
        GemAchievementId.sleep100 => 'assets/cropped/sleep100.PNG',
        GemAchievementId.score100 => 'assets/cropped/score100.PNG',
        GemAchievementId.timerFull => 'assets/cropped/timerfull.PNG',
      };

  /// Zoom factor for the achievement unlock showcase image.
  double get showcaseZoom => switch (this) {
        GemAchievementId.firstStreak => 0.8,
        _ => 1.2,
      };

  String get storageKey => name;

  String get displayTitle => switch (this) {
        GemAchievementId.firstStreak => 'FIRST GEM',
        GemAchievementId.streak5 => '5-DAY GEM',
        GemAchievementId.streak10 => '10-DAY GEM',
        GemAchievementId.streak30 => '30-DAY GEM',
        GemAchievementId.streak60 => '60-DAY GEM',
        GemAchievementId.streak100 => '100-DAY GEM',
        GemAchievementId.streak365 => '365-DAY GEM',
        GemAchievementId.focus100 => 'FOCUS GEM',
        GemAchievementId.rest100 => 'REST GEM',
        GemAchievementId.sleep100 => 'SLEEP GEM',
        GemAchievementId.score100 => 'SCORE GEM',
        GemAchievementId.timerFull => 'TIMER GEM',
      };

  String get subtitle => switch (this) {
        GemAchievementId.firstStreak => 'You downloaded Silo',
        GemAchievementId.streak5 => 'Five days of protecting your time',
        GemAchievementId.streak10 => 'Ten days of showing up in Silo',
        GemAchievementId.streak30 => 'A month of Silo consistency',
        GemAchievementId.streak60 => 'Sixty days deep in Silo',
        GemAchievementId.streak100 => 'A century streak in Silo',
        GemAchievementId.streak365 => 'One year of focus with Silo',
        GemAchievementId.focus100 => 'You reached perfect Focus',
        GemAchievementId.rest100 => 'You reached perfect Rest',
        GemAchievementId.sleep100 => 'You reached perfect Sleep',
        GemAchievementId.score100 => 'You reached a perfect Silo score',
        GemAchievementId.timerFull => 'You completed a full focus timer',
      };

  String get milestoneDescription => switch (this) {
        GemAchievementId.firstStreak =>
          'Unlock this MileStone when you download Silo.',
        GemAchievementId.streak5 =>
          'Unlock this MileStone when you reach a 5-day Silo streak.',
        GemAchievementId.streak10 =>
          'Unlock this MileStone when you reach a 10-day Silo streak.',
        GemAchievementId.streak30 =>
          'Unlock this MileStone when you reach a 30-day Silo streak.',
        GemAchievementId.streak60 =>
          'Unlock this MileStone when you reach a 60-day Silo streak.',
        GemAchievementId.streak100 =>
          'Unlock this MileStone when you reach a 100-day Silo streak.',
        GemAchievementId.streak365 =>
          'Unlock this MileStone when you reach a 365-day Silo streak.',
        GemAchievementId.focus100 =>
          'Unlock this MileStone when your Focus score reaches 100.',
        GemAchievementId.rest100 =>
          'Unlock this MileStone when your Rest score reaches 100.',
        GemAchievementId.sleep100 =>
          'Unlock this MileStone when your Sleep score reaches 100.',
        GemAchievementId.score100 =>
          'Unlock this MileStone when your overall Silo score reaches 100.',
        GemAchievementId.timerFull =>
          'Unlock this MileStone when you complete a finite focus timer in Silo.',
      };

  /// Approximate share of Silo users who own this gem (higher = more common).
  int get rarityPercent => switch (this) {
        GemAchievementId.firstStreak => 98,
        GemAchievementId.streak5 => 72,
        GemAchievementId.streak10 => 48,
        GemAchievementId.streak30 => 22,
        GemAchievementId.streak60 => 9,
        GemAchievementId.streak100 => 3,
        GemAchievementId.streak365 => 1,
        GemAchievementId.focus100 => 35,
        GemAchievementId.rest100 => 28,
        GemAchievementId.sleep100 => 31,
        GemAchievementId.score100 => 18,
        GemAchievementId.timerFull => 54,
      };
}
