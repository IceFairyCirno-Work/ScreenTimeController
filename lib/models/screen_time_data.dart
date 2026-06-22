import 'dart:typed_data';

class AppUsageItem {
  final String appName;
  final String packageName;
  final Duration usage;
  final Uint8List? iconBytes;

  const AppUsageItem({
    required this.appName,
    required this.packageName,
    required this.usage,
    this.iconBytes,
  });
}

class ScreenTimeData {
  final Duration todayTotal;
  final Duration weekTotal;
  final List<AppUsageItem> topApps;
  final List<AppUsageItem> weekTopApps;
  final bool hasPermission;
  final int nightUsageMinutes;
  final int weekNightUsageMinutes;

  const ScreenTimeData({
    required this.todayTotal,
    required this.weekTotal,
    required this.topApps,
    required this.hasPermission,
    this.weekTopApps = const [],
    this.nightUsageMinutes = 0,
    this.weekNightUsageMinutes = 0,
  });

  static const empty = ScreenTimeData(
    todayTotal: Duration.zero,
    weekTotal: Duration.zero,
    topApps: [],
    hasPermission: false,
    weekTopApps: [],
    nightUsageMinutes: 0,
    weekNightUsageMinutes: 0,
  );

  String get formattedToday => _formatDuration(todayTotal);
  String get formattedWeek => _formatDuration(weekTotal);

  static String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    if (totalSeconds <= 0) return '0s';

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    if (minutes > 0) {
      return '${minutes}m';
    }
    return '${seconds}s';
  }

  static String formatDuration(Duration duration) => _formatDuration(duration);

  /// Compact label for the blocked-app detail metrics row.
  static String formatMetricDuration(Duration duration) {
    if (duration.inMinutes < 1) {
      return duration.inSeconds > 0 ? '<1m' : '0m';
    }
    return _formatDuration(duration);
  }

  ScreenTimeData copyWith({
    Duration? todayTotal,
    Duration? weekTotal,
    List<AppUsageItem>? topApps,
    List<AppUsageItem>? weekTopApps,
    bool? hasPermission,
    int? nightUsageMinutes,
    int? weekNightUsageMinutes,
  }) {
    return ScreenTimeData(
      todayTotal: todayTotal ?? this.todayTotal,
      weekTotal: weekTotal ?? this.weekTotal,
      topApps: topApps ?? this.topApps,
      weekTopApps: weekTopApps ?? this.weekTopApps,
      hasPermission: hasPermission ?? this.hasPermission,
      nightUsageMinutes: nightUsageMinutes ?? this.nightUsageMinutes,
      weekNightUsageMinutes:
          weekNightUsageMinutes ?? this.weekNightUsageMinutes,
    );
  }
}

class BlockedAppTodayStats {
  final int opens;
  final Duration screenTime;
  final int unblocks;

  const BlockedAppTodayStats({
    required this.opens,
    required this.screenTime,
    required this.unblocks,
  });

  static const empty = BlockedAppTodayStats(
    opens: 0,
    screenTime: Duration.zero,
    unblocks: 0,
  );
}
