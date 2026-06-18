import '../models/app_folder.dart';
import '../models/screen_time_data.dart';

class _AppNameMatcher {
  final String primary;
  final List<String> aliases;
  final List<String> exclusions;

  const _AppNameMatcher(
    this.primary, {
    this.aliases = const [],
    this.exclusions = const [],
  });

  Iterable<String> get patterns sync* {
    yield primary;
    yield* aliases;
  }

  bool matches(String appName) {
    final normalized = _normalize(appName);
    for (final exclusion in exclusions) {
      if (normalized.contains(_normalize(exclusion))) return false;
    }
    for (final pattern in patterns) {
      final target = _normalize(pattern);
      if (normalized == target || normalized.contains(target)) {
        return true;
      }
    }
    return false;
  }
}

String _normalize(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

const _distractingMatchers = [
  _AppNameMatcher('Instagram'),
  _AppNameMatcher('Youtube', aliases: ['YouTube'], exclusions: ['Music']),
  _AppNameMatcher('Tiktok', aliases: ['TikTok']),
  _AppNameMatcher('Snapchat'),
];

const _alwaysAllowedMatchers = [
  _AppNameMatcher(
    'Google Play',
    aliases: ['Play Store'],
    exclusions: ['Games'],
  ),
  _AppNameMatcher('Whatsapp', aliases: ['WhatsApp']),
  _AppNameMatcher('Chrome'),
  _AppNameMatcher('Gmail'),
];

List<FolderAppItem> _collectFolderMatches(
  List<AppUsageItem> installed,
  List<_AppNameMatcher> matchers,
  DateTime addedAt,
) {
  final matches = <FolderAppItem>[];
  final usedPackages = <String>{};

  for (final app in installed) {
    if (usedPackages.contains(app.packageName)) continue;

    final isMatch = matchers.any((matcher) => matcher.matches(app.appName));
    if (!isMatch) continue;

    matches.add(
      FolderAppItem(
        packageName: app.packageName,
        appName: app.appName,
        addedAt: addedAt,
      ),
    );
    usedPackages.add(app.packageName);
  }

  return matches;
}

/// Builds default folder contents by matching installed app display names.
Map<AppFolderType, List<FolderAppItem>> buildDefaultFolderAppsFromInstalled(
  List<AppUsageItem> installed,
) {
  final now = DateTime.now();

  return {
    AppFolderType.distracting:
        _collectFolderMatches(installed, _distractingMatchers, now),
    AppFolderType.alwaysAllowed:
        _collectFolderMatches(installed, _alwaysAllowedMatchers, now),
    AppFolderType.neverAllowed: const [],
  };
}
