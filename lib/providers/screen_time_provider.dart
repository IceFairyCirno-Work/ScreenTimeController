import 'package:flutter/foundation.dart';

import '../models/screen_time_data.dart';
import '../services/screen_time_service.dart';

class ScreenTimeProvider extends ChangeNotifier {
  final ScreenTimeService _service = ScreenTimeService();

  ScreenTimeData _data = ScreenTimeData.empty;

  ScreenTimeData get data => _data;
  bool get hasPermission => _data.hasPermission;

  /// Loads usage data. When [showLoading] is false (e.g. pull-to-refresh),
  /// skips the pre-fetch notify so [RefreshIndicator] is not disposed mid-refresh.
  Future<void> loadUsage({bool showLoading = true}) async {
    if (showLoading) {
      notifyListeners();
    }

    try {
      _data = await _service.fetchUsageData();
    } catch (e) {
      _data = ScreenTimeData.empty;
    } finally {
      notifyListeners();
    }
  }

  Future<void> refreshUsage() => loadUsage(showLoading: false);
}
