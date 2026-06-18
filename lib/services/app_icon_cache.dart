import 'dart:typed_data';

import '../services/screen_time_service.dart';

class AppIconCache {
  AppIconCache._();

  static final AppIconCache instance = AppIconCache._();

  final ScreenTimeService _service = ScreenTimeService();
  final Map<String, Uint8List?> _cache = {};
  final Map<String, Future<Uint8List?>> _pending = {};

  Future<Uint8List?> getIcon(String packageName) {
    if (_cache.containsKey(packageName)) {
      return Future.value(_cache[packageName]);
    }

    return _pending.putIfAbsent(packageName, () async {
      try {
        final bytes = await _service.getAppIcon(packageName);
        if (bytes != null && bytes.isNotEmpty) {
          _cache[packageName] = bytes;
        }
        return bytes;
      } finally {
        _pending.remove(packageName);
      }
    });
  }

  Future<Map<String, Uint8List?>> getIcons(List<String> packageNames) async {
    final results = await Future.wait(
      packageNames.map((packageName) async {
        final bytes = await getIcon(packageName);
        return MapEntry(packageName, bytes);
      }),
    );
    return Map.fromEntries(results);
  }

  void clear() {
    _cache.clear();
    _pending.clear();
  }
}
