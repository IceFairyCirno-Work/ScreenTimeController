/// Auto-generated titles for Open limit rules, e.g. `4 opens limit`.
class OpenLimitFormatter {
  const OpenLimitFormatter._();

  static String formatTitle(int maxOpens) => '$maxOpens opens limit';

  static bool isDefaultOpenLimitName(String name, int maxOpens) {
    return name.trim() == formatTitle(maxOpens);
  }

  static String formatSessionLength(int minutes) => '${minutes}m';
}
