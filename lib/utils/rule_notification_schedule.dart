import '../models/app_rule.dart';

/// Schedule metadata used to plan rule start / end notifications.
class RuleNotificationSchedule {
  const RuleNotificationSchedule({
    required this.ruleId,
    required this.ruleName,
    required this.nextStart,
    required this.blockingDurationLabel,
    this.nextEnd,
  });

  final String ruleId;
  final String ruleName;
  final DateTime nextStart;
  final String blockingDurationLabel;

  /// When non-null, a "rule ended" notification should fire at this moment.
  final DateTime? nextEnd;

  static bool isEligible(SessionRule rule, DateTime now) {
    if (!rule.isEnabled) return false;
    return !rule.isIndefinitelyDisabled() && !rule.isCurrentlyDisabled(now);
  }

  static RuleNotificationSchedule? from(SessionRule rule, DateTime now) {
    if (!isEligible(rule, now)) return null;

    return RuleNotificationSchedule(
      ruleId: rule.id,
      ruleName: rule.name,
      nextStart: rule.nextStartAfter(now),
      blockingDurationLabel:
          formatTimeWindowDuration(rule.startTime, rule.endTime),
      nextEnd: rule.nextEndAfter(now),
    );
  }
}
