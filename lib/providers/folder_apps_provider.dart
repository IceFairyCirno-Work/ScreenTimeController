import 'dart:async';

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_folder.dart';
import '../models/app_rule.dart';
import '../models/screen_time_data.dart';
import '../services/default_folder_seeder.dart';
import '../services/screen_time_service.dart';

class FolderAppsProvider extends ChangeNotifier {
  static const _storageKey = 'folder_apps';
  static const _defaultSeededKey = 'folder_apps_default_seeded';
  static const _adultWebsitesBlockedKey = 'adult_websites_blocked';

  Map<AppFolderType, List<FolderAppItem>> _folderApps =
      createInitialFolderApps();
  bool _isLoading = false;
  bool _initialized = false;
  bool _adultWebsitesBlocked = true;
  String? _error;
  int _dataVersion = 0;

  Map<AppFolderType, List<FolderAppItem>> get folderApps => {
        for (final entry in _folderApps.entries)
          entry.key: List<FolderAppItem>.unmodifiable(entry.value),
      };

  bool get isLoading => _isLoading;
  bool get initialized => _initialized;
  bool get adultWebsitesBlocked => _adultWebsitesBlocked;
  String? get error => _error;

  List<FolderAppItem> appsFor(AppFolderType type) =>
      List.unmodifiable(_folderApps[type] ?? const []);

  List<AppRuleItem> get distractingAppsAsRuleItems => appsFor(
        AppFolderType.distracting,
      ).map((item) => item.toAppRuleItem()).toList();

  Set<String> get alwaysAllowedPackageNames => appsFor(
        AppFolderType.alwaysAllowed,
      ).map((item) => item.packageName).toSet();

  Set<String> get neverAllowedPackageNames => appsFor(
        AppFolderType.neverAllowed,
      ).map((item) => item.packageName).toSet();

  bool isAlwaysAllowed(String packageName) =>
      alwaysAllowedPackageNames.contains(packageName);

  bool isNeverAllowed(String packageName) =>
      neverAllowedPackageNames.contains(packageName);

  bool isInFolder(AppFolderType type, String packageName) =>
      appsFor(type).any((item) => item.packageName == packageName);

  Future<void> addAppToFolder(
    AppFolderType type, {
    required String packageName,
    required String appName,
  }) async {
    if (isInFolder(type, packageName)) return;

    final apps = List<FolderAppItem>.from(appsFor(type))
      ..add(
        FolderAppItem(
          packageName: packageName,
          appName: appName,
          addedAt: DateTime.now(),
        ),
      );
    await updateFolder(type, apps);
  }

  Future<void> removeAppFromFolder(
    AppFolderType type,
    String packageName,
  ) async {
    if (!isInFolder(type, packageName)) return;

    final apps = appsFor(type)
        .where((item) => item.packageName != packageName)
        .toList();
    await updateFolder(type, apps);
  }

  /// When a package is in both folders, Never allowed takes precedence.
  bool isEffectivelyAlwaysAllowed(String packageName) =>
      isAlwaysAllowed(packageName) && !isNeverAllowed(packageName);

  Future<void> setAdultWebsitesBlocked(bool blocked) async {
    if (_adultWebsitesBlocked == blocked) return;
    _adultWebsitesBlocked = blocked;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_adultWebsitesBlockedKey, blocked);
    } catch (e, stack) {
      debugPrint('Failed to save adult websites setting: $e\n$stack');
    }
  }

  Future<void> load() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;

    final versionAtStart = _dataVersion;

    try {
      final prefs = await SharedPreferences.getInstance();
      _adultWebsitesBlocked =
          prefs.getBool(_adultWebsitesBlockedKey) ?? true;
      final jsonStr = prefs.getString(_storageKey);

      if (versionAtStart != _dataVersion) return;

      if (jsonStr != null && jsonStr.isNotEmpty) {
        _folderApps = _decode(jsonStr);
      } else {
        _folderApps = createInitialFolderApps();
        await _save();
      }
    } catch (e, stack) {
      _error = e.toString();
      debugPrint('Failed to load folder apps: $e\n$stack');
      if (versionAtStart == _dataVersion) {
        _folderApps = createInitialFolderApps();
      }
    } finally {
      _isLoading = false;
      _initialized = true;
      notifyListeners();
    }

    // Seeding walks every installed app + icon — never block cold start on it.
    unawaited(_seedDefaultFoldersIfNeeded());
  }

  /// Populates Distracting / Always allowed from installed apps on first launch.
  Future<void> trySeedDefaultFolders() async {
    if (!_initialized) return;
    await _seedDefaultFoldersIfNeeded();
  }

  Future<void> _seedDefaultFoldersIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_defaultSeededKey) == true) return;

    final service = ScreenTimeService();
    if (!await service.hasUsagePermission()) return;

    List<AppUsageItem> installed;
    try {
      installed = await service
          .getInstalledApps()
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      debugPrint('Default folder seed timed out — skipping for this launch');
      return;
    } catch (e, stack) {
      debugPrint('Default folder seed failed: $e\n$stack');
      return;
    }

    final versionAtStart = _dataVersion;

    if (versionAtStart != _dataVersion) return;

    _dataVersion++;
    _folderApps = buildDefaultFolderAppsFromInstalled(installed);
    await prefs.setBool(_defaultSeededKey, true);
    await _save();
    if (_initialized) notifyListeners();
  }

  Future<void> updateFolder(
    AppFolderType type,
    List<FolderAppItem> apps,
  ) async {
    _dataVersion++;
    _folderApps[type] = List<FolderAppItem>.from(apps);
    notifyListeners();
    await _save();
  }

  List<FolderAppItem> mergeRuleItemsIntoFolder(
    AppFolderType type,
    List<AppRuleItem> updatedApps,
  ) {
    final existing = appsFor(type);
    final existingByPackage = {
      for (final item in existing) item.packageName: item,
    };
    final now = DateTime.now();

    return updatedApps
        .map(
          (app) =>
              existingByPackage[app.packageName]?.copyWith() ??
              FolderAppItem(
                packageName: app.packageName,
                appName: app.appName,
                addedAt: now,
              ),
        )
        .toList();
  }

  Map<AppFolderType, List<FolderAppItem>> _decode(String jsonStr) {
    final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
    final defaults = createInitialFolderApps();
    final loaded = <AppFolderType, List<FolderAppItem>>{};

    for (final type in AppFolderType.values) {
      final raw = decoded[type.storageKey];
      if (raw is List<dynamic>) {
        loaded[type] = raw
            .map(
              (json) => FolderAppItem.fromJson(json as Map<String, dynamic>),
            )
            .toList();
      } else {
        loaded[type] = List<FolderAppItem>.from(defaults[type] ?? const []);
      }
    }

    return loaded;
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = <String, dynamic>{
        for (final type in AppFolderType.values)
          type.storageKey: (_folderApps[type] ?? const [])
              .map((item) => item.toJson())
              .toList(),
      };
      final saved = await prefs.setString(_storageKey, jsonEncode(encoded));
      if (!saved) {
        _error = 'Failed to persist folder apps';
        debugPrint('SharedPreferences.setString returned false for $_storageKey');
      }
    } catch (e, stack) {
      _error = e.toString();
      debugPrint('Failed to save folder apps: $e\n$stack');
    }
  }

  void resetAfterAccountDeletion() {
    _dataVersion++;
    _folderApps = createInitialFolderApps();
    _adultWebsitesBlocked = true;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
