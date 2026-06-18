/// Formats a duration using the single most meaningful unit: days → hours → minutes.
String formatDurationSingleUnit(Duration d) {
  if (d.inDays > 0) return '${d.inDays}d';
  if (d.inHours > 0) return '${d.inHours}h';
  return '${d.inMinutes.remainder(60).clamp(1, 60)}m';
}
