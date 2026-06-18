import 'dart:typed_data';

import 'app_rule.dart';

enum AppFolderType {
  distracting,
  alwaysAllowed,
  neverAllowed;

  String get storageKey => switch (this) {
        AppFolderType.distracting => 'distracting',
        AppFolderType.alwaysAllowed => 'alwaysAllowed',
        AppFolderType.neverAllowed => 'neverAllowed',
      };

  static AppFolderType? fromStorageKey(String key) => switch (key) {
        'distracting' => AppFolderType.distracting,
        'alwaysAllowed' => AppFolderType.alwaysAllowed,
        'neverAllowed' => AppFolderType.neverAllowed,
        _ => null,
      };
}

class FolderAppItem {
  final String packageName;
  final String appName;
  final DateTime addedAt;

  const FolderAppItem({
    required this.packageName,
    required this.appName,
    required this.addedAt,
  });

  AppRuleItem toAppRuleItem({Uint8List? iconBytes}) => AppRuleItem(
        packageName: packageName,
        appName: appName,
        iconBytes: iconBytes,
      );

  FolderAppItem copyWith({DateTime? addedAt}) => FolderAppItem(
        packageName: packageName,
        appName: appName,
        addedAt: addedAt ?? this.addedAt,
      );

  Map<String, dynamic> toJson() => {
        'packageName': packageName,
        'appName': appName,
        'addedAt': addedAt.toIso8601String(),
      };

  factory FolderAppItem.fromJson(Map<String, dynamic> json) => FolderAppItem(
        packageName: json['packageName'] as String,
        appName: json['appName'] as String,
        addedAt: DateTime.parse(json['addedAt'] as String),
      );
}

class AppFolder {
  final AppFolderType type;
  final String title;
  final String bannerText;
  final bool showEye;

  const AppFolder({
    required this.type,
    required this.title,
    required this.bannerText,
    this.showEye = false,
  });

  static const List<AppFolder> all = [
    AppFolder(
      type: AppFolderType.distracting,
      title: 'Distracting',
      bannerText:
          'Silo will add distracting apps & websites based on your usage.',
    ),
    AppFolder(
      type: AppFolderType.alwaysAllowed,
      title: 'Always allowed',
      bannerText:
          'Apps & websites in this folder are always allowed, even when other rules are active.',
    ),
    AppFolder(
      type: AppFolderType.neverAllowed,
      title: 'Never allowed',
      bannerText:
          'Apps & websites in this folder are never allowed on this device.',
      showEye: true,
    ),
  ];

  static AppFolder forType(AppFolderType type) =>
      all.firstWhere((folder) => folder.type == type);

  String subtitleFor(int appCount) {
    if (showEye) return 'Hidden';
    if (appCount == 1) return '1 app';
    return '$appCount apps';
  }
}

String formatFolderAddedAt(DateTime addedAt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final addedDay = DateTime(addedAt.year, addedAt.month, addedAt.day);
  final diff = today.difference(addedDay).inDays;
  if (diff == 0) return 'today';
  if (diff == 1) return 'yesterday';
  final day = addedAt.day.toString().padLeft(2, '0');
  final month = addedAt.month.toString().padLeft(2, '0');
  return '$day/$month';
}

Map<AppFolderType, List<FolderAppItem>> createInitialFolderApps() {
  return {
    AppFolderType.distracting: const [],
    AppFolderType.alwaysAllowed: const [],
    AppFolderType.neverAllowed: const [],
  };
}
