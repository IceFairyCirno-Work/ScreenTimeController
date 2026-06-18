import 'gem_achievement.dart';

/// Presentation model for the gem unlock bottom sheet.
class GemUnlockInfo {
  final GemAchievementId id;
  final String title;
  final String subtitle;
  final String milestoneDescription;
  final int rarityPercent;
  final String assetPath;
  final DateTime unlockedAt;

  const GemUnlockInfo({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.milestoneDescription,
    required this.rarityPercent,
    required this.assetPath,
    required this.unlockedAt,
  });

  factory GemUnlockInfo.fromUnlock({
    required GemAchievementId id,
    required DateTime unlockedAt,
  }) {
    return GemUnlockInfo(
      id: id,
      title: id.displayTitle,
      subtitle: id.subtitle,
      milestoneDescription: id.milestoneDescription,
      rarityPercent: id.rarityPercent,
      assetPath: id.showcaseAssetPath,
      unlockedAt: unlockedAt,
    );
  }

  String get formattedUnlockDate => formatUnlockDate(unlockedAt);

  String get shareMessage {
    final date = formattedUnlockDate.replaceFirst('Unlocked on ', '');
    return 'I unlocked the $title in Silo! Unlocked on $date.';
  }

  static String formatUnlockDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return 'Unlocked on ${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
