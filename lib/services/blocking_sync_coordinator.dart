import '../models/app_folder.dart';
import '../providers/folder_apps_provider.dart';
import '../providers/rules_provider.dart';
import '../providers/timer_provider.dart';
import '../utils/website_helpers.dart';

/// Computes the set of package names that should be blocked on Android.
///
/// Uses [RulesProvider.isAppBlocked] so expiry is evaluated at [at] even when
/// stale unblock entries have not yet been pruned from storage. Packages in the
/// Always allowed folder are never included unless they are also in Never
/// allowed (Never wins). Packages in the Never allowed folder are always
/// included.
Set<String> computeBlockedPackages(
  RulesProvider rules,
  TimerProvider timer, {
  DateTime? at,
  Set<String> alwaysAllowedPackages = const {},
  Set<String> neverAllowedPackages = const {},
  bool emergencyPassActive = false,
}) {
  if (emergencyPassActive) return <String>{};

  final blocked = <String>{...neverAllowedPackages};
  final moment = at ?? DateTime.now();

  final candidatePackages = <String>{};
  for (final rule in rules.rules) {
    for (final app in rule.apps) {
      final pkg = app.packageName;
      if (WebsiteHelpers.isWebsitePackage(pkg)) continue;
      candidatePackages.add(pkg);
    }
  }

  if (timer.isRunning) {
    for (final app in timer.blockedApps) {
      candidatePackages.add(app.packageName);
    }
  }

  for (final pkg in candidatePackages) {
    if (alwaysAllowedPackages.contains(pkg) &&
        !neverAllowedPackages.contains(pkg)) {
      continue;
    }
    if (rules.isAppBlocked(pkg, moment)) {
      blocked.add(pkg);
    }
  }

  blocked.removeWhere(
    (pkg) =>
        alwaysAllowedPackages.contains(pkg) &&
        !neverAllowedPackages.contains(pkg),
  );
  blocked.addAll(neverAllowedPackages);
  return blocked;
}

/// Domains that should be blocked in supported browsers.
Set<String> computeBlockedDomains(
  RulesProvider rules, {
  DateTime? at,
  bool emergencyPassActive = false,
}) {
  if (emergencyPassActive) return <String>{};

  final moment = at ?? DateTime.now();
  final blocked = <String>{};

  for (final display in rules.blockedWebsitesDisplay(moment)) {
    final pkg = display.app.packageName;
    if (rules.isAppBlocked(pkg, moment)) {
      blocked.add(WebsiteHelpers.domainFromPackage(pkg));
    }
  }

  return blocked;
}

/// Active per-domain unblock end times for native browser enforcement.
Map<String, int> computeTemporaryUnblockUntilByDomain(
  RulesProvider rules, [
  DateTime? at,
]) {
  final moment = at ?? DateTime.now();
  final result = <String, int>{};

  for (final display in rules.blockedWebsitesDisplay(moment)) {
    final until = display.unblockedUntil;
    if (until != null && until.isAfter(moment)) {
      result[WebsiteHelpers.domainFromPackage(display.app.packageName)] =
          until.millisecondsSinceEpoch;
    }
  }

  return result;
}

/// Active per-package unblock end times for native enforcement when a window
/// expires while the user remains in the app.
Map<String, int> computeTemporaryUnblockUntilByPackage(
  RulesProvider rules, [
  DateTime? at,
]) {
  final moment = at ?? DateTime.now();
  final result = <String, int>{};

  for (final display in rules.blockedAppsDisplay(moment)) {
    final pkg = display.app.packageName;
    if (WebsiteHelpers.isWebsitePackage(pkg)) continue;
    final until = display.unblockedUntil;
    if (until != null && until.isAfter(moment)) {
      result[pkg] = until.millisecondsSinceEpoch;
    }
  }

  return result;
}

/// Time limit rule rows for native [TimeLimitEnforcer] (works while Flutter
/// is backgrounded).
List<Map<String, dynamic>> computeTimeLimitRulesForNative(
  RulesProvider rules, {
  DateTime? at,
  bool emergencyPassActive = false,
}) {
  if (emergencyPassActive) return const [];

  final moment = at ?? DateTime.now();
  final result = <Map<String, dynamic>>[];

  for (final rule in rules.timeLimits) {
    if (!rule.isEnabled) continue;
    for (final app in rule.apps) {
      final pkg = app.packageName;
      if (rules.isNeverAllowedPackage(pkg)) continue;
      if (rules.isEffectivelyAlwaysAllowed(pkg)) continue;

      final exceeded = rule.limitExceededAtByPackage[pkg];
      result.add({
        'packageName': pkg,
        'allowedMs': rule.allowedTime.inMilliseconds,
        'baselineMs': rule.usageBaselineMsByPackage[pkg] ?? 0,
        'blockUntilMs': rule.blockUntil.inMilliseconds,
        'blockUntilMidnight': rule.blockUntil.inHours >= 24,
        'limitExceededAtMs': exceeded?.millisecondsSinceEpoch ?? 0,
        'ruleActive': rule.isRuleActive(moment),
      });
    }
  }

  return result;
}

/// Schedule (session) rules for native [SessionScheduleEnforcer] — evaluated on
/// device so blocking starts on time even when Flutter is backgrounded.
List<Map<String, dynamic>> computeSessionScheduleRulesForNative(
  RulesProvider rules, {
  bool emergencyPassActive = false,
}) {
  if (emergencyPassActive) return const [];

  final result = <Map<String, dynamic>>[];

  for (final rule in rules.sessions) {
    if (!rule.isEnabled) continue;
    final disabledUntilMs = rule.disabledUntil?.millisecondsSinceEpoch ?? 0;
    for (final app in rule.apps) {
      final pkg = app.packageName;
      if (rules.isNeverAllowedPackage(pkg)) continue;
      if (rules.isEffectivelyAlwaysAllowed(pkg)) continue;

      result.add({
        'packageName': pkg,
        'startHour': rule.startTime.hour,
        'startMinute': rule.startTime.minute,
        'endHour': rule.endTime.hour,
        'endMinute': rule.endTime.minute,
        'repeatDays': rule.repeatDays.map((d) => d.index).toList(),
        'disabledUntilMs': disabledUntilMs,
      });
    }
  }

  return result;
}

/// Distracting folder packages for the native awareness pill overlay.
Set<String> computeDistractingPackagesForNative(
  FolderAppsProvider folderApps, {
  bool emergencyPassActive = false,
}) {
  if (emergencyPassActive) return const {};

  final alwaysAllowed = folderApps.alwaysAllowedPackageNames;
  final neverAllowed = folderApps.neverAllowedPackageNames;
  final packages = <String>{};

  for (final item in folderApps.appsFor(AppFolderType.distracting)) {
    final pkg = item.packageName;
    if (alwaysAllowed.contains(pkg) && !neverAllowed.contains(pkg)) {
      continue;
    }
    packages.add(pkg);
  }

  return packages;
}