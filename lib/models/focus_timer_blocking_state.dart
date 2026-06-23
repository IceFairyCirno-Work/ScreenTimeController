import '../models/app_rule.dart';
import '../providers/timer_provider.dart';

/// Snapshot of focus-timer blocking inputs for [computeBlockedPackages].
class FocusTimerBlockingState {
  const FocusTimerBlockingState({
    required this.isRunning,
    this.blockedApps = const [],
  });

  final bool isRunning;
  final List<AppRuleItem> blockedApps;

  factory FocusTimerBlockingState.from(TimerProvider timer) =>
      FocusTimerBlockingState(
        isRunning: timer.isRunning,
        blockedApps: timer.blockedApps,
      );
}
