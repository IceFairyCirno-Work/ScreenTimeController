import 'package:flutter/material.dart';

/// Formats [TimeOfDay] using Traditional Chinese (zh-hk) 12-hour convention
/// with 上午 / 下午 markers, e.g. `上午9:00`, `下午5:00`.
class CjkTimeFormatter {
  const CjkTimeFormatter._();

  /// Returns `上午9:00` style label for a single time point.
  static String format(TimeOfDay time) {
    final period = time.period == DayPeriod.am ? '上午' : '下午';
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$period$hour:$minute';
  }

  /// Returns a range label joined by an en-dash, e.g. `上午9:00 – 下午5:00`.
  static String formatRange(TimeOfDay start, TimeOfDay end) {
    return '${format(start)} – ${format(end)}';
  }

  /// Whether [name] is the auto-generated title for [start]–[end].
  static bool isDefaultRangeName(
    String name,
    TimeOfDay start,
    TimeOfDay end,
  ) {
    return name.trim() == formatRange(start, end);
  }
}
