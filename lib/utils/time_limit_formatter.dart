/// Auto-generated titles and duration labels for Time limit rules.
class TimeLimitFormatter {
  const TimeLimitFormatter._();

  static const List<Duration> allowedDurationOptions = [
    Duration(minutes: 5),
    Duration(minutes: 10),
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(minutes: 45),
    Duration(hours: 1),
    Duration(minutes: 90),
    Duration(hours: 2),
    Duration(hours: 3),
    Duration(hours: 4),
  ];

  /// Sentinel duration stored in [TimeLimitRule.blockUntil] for "Tomorrow".
  static const Duration tomorrowBlockUntil = Duration(hours: 24);

  static const List<Duration> blockUntilOptions = [
    tomorrowBlockUntil,
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(hours: 1),
  ];

  static String formatTitle(Duration allowedTime) =>
      'After ${formatDurationShort(allowedTime)}';

  static bool isDefaultTimeLimitName(String name, Duration allowedTime) {
    return name.trim() == formatTitle(allowedTime);
  }

  static String formatDurationShort(Duration d) {
    final totalMinutes = d.inMinutes;
    if (totalMinutes >= 60) {
      final hours = totalMinutes ~/ 60;
      final minutes = totalMinutes % 60;
      if (minutes == 0) return '${hours}h';
      if (minutes == 30) return '${hours}h30m';
      return '${hours}h${minutes}m';
    }
    return '${totalMinutes}m';
  }

  static String formatBlockUntilLabel(Duration blockUntil) {
    if (blockUntil >= tomorrowBlockUntil) return 'Tomorrow';
    return formatDurationShort(blockUntil);
  }

  static Duration nearestAllowedDuration(Duration value) {
    for (final option in allowedDurationOptions) {
      if (option == value) return option;
    }
    return allowedDurationOptions[3]; // 30m default
  }

  static Duration nearestBlockUntil(Duration value) {
    for (final option in blockUntilOptions) {
      if (option == value) return option;
    }
    return tomorrowBlockUntil;
  }
}
