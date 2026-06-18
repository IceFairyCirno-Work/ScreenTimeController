import '../models/screen_time_data.dart';
import 'screen_time_service.dart';

/// In-memory cache of the full installed-app list for the session.
///
/// The installed-app set rarely changes during a single editing session, so
/// we pre-fetch it once when the selected-apps sheet opens and reuse the
/// result across the "Add apps" view. This removes the visible loading delay
/// when the user taps "Add app".
class InstalledAppsCache {
  InstalledAppsCache._();
  static final InstalledAppsCache instance = InstalledAppsCache._();

  final ScreenTimeService _service = ScreenTimeService();
  List<AppUsageItem>? _cache;
  Future<List<AppUsageItem>>? _pending;

  /// Returns the cached list, fetching it on first access.
  Future<List<AppUsageItem>> getApps() {
    final cached = _cache;
    if (cached != null) return Future.value(cached);

    return _pending ??= _service.getInstalledApps().then((apps) {
      _cache = apps;
      _pending = null;
      return apps;
    });
  }

  /// Pre-fetches the list in the background. Safe to call multiple times —
  /// concurrent calls share the same future.
  void preload() {
    if (_cache == null && _pending == null) {
      _pending = _service.getInstalledApps().then<List<AppUsageItem>>((apps) {
        _cache = apps;
        _pending = null;
        return apps;
      });
    }
  }

  /// Clears the cache so the next access re-fetches from the service.
  void clear() {
    _cache = null;
    _pending = null;
  }
}
