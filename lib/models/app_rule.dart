import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum RuleType { session, timeLimit, openLimit }

enum RuleDifficulty { normal, strict, deepFocus }

enum RepeatDay {
  mon,
  tue,
  wed,
  thu,
  fri,
  sat,
  sun;

  static const List<RepeatDay> weekdays = [mon, tue, wed, thu, fri];
  static const List<RepeatDay> weekend = [sat, sun];
  static const List<RepeatDay> all = [mon, tue, wed, thu, fri, sat, sun];

  String get shortLabel => switch (this) {
        mon => 'Mon',
        tue => 'Tue',
        wed => 'Wed',
        thu => 'Thu',
        fri => 'Fri',
        sat => 'Sat',
        sun => 'Sun',
      };

  /// Maps a [DateTime.weekday] value (1 = Monday … 7 = Sunday per Dart) to the
  /// matching [RepeatDay].
  static RepeatDay fromDateTimeWeekday(int weekday) {
    // DateTime.weekday is 1-based with Monday = 1; our enum is 0-based with
    // Monday at index 0.
    return values[(weekday - 1) % 7];
  }
}

/// Formats the length of a [startTime]→[endTime] window as `XhYm`.
String formatTimeWindowDuration(TimeOfDay start, TimeOfDay end) {
  final startMin = start.hour * 60 + start.minute;
  final endMin = end.hour * 60 + end.minute;
  final totalMinutes =
      endMin > startMin ? endMin - startMin : (24 * 60 - startMin) + endMin;
  return '${totalMinutes ~/ 60}h${totalMinutes % 60}m';
}

/// Midnight at the start of the next eligible repeat day strictly after [from].
DateTime nextDayStartAfter({
  required DateTime from,
  required DateTime createdAt,
  required List<RepeatDay> repeatDays,
}) {
  final earliestDay =
      DateTime(createdAt.year, createdAt.month, createdAt.day);
  for (var i = 0; i < 8; i++) {
    final candidate = DateTime(from.year, from.month, from.day + i);
    if (!candidate.isAfter(from)) continue;
    final candidateDay =
        DateTime(candidate.year, candidate.month, candidate.day);
    if (candidateDay.isBefore(earliestDay)) continue;
    if (repeatDays
        .contains(RepeatDay.fromDateTimeWeekday(candidate.weekday))) {
      return candidate;
    }
  }
  return DateTime(from.year, from.month, from.day + 1);
}

class AppRuleItem {
  final String packageName;
  final String appName;
  final Uint8List? iconBytes;
  /// Base64-encoded Family Controls ApplicationToken (iOS only).
  final String? iosApplicationToken;

  const AppRuleItem({
    required this.packageName,
    required this.appName,
    this.iconBytes,
    this.iosApplicationToken,
  });

  AppRuleItem copyWith({
    String? packageName,
    String? appName,
    Uint8List? iconBytes,
    String? iosApplicationToken,
  }) =>
      AppRuleItem(
        packageName: packageName ?? this.packageName,
        appName: appName ?? this.appName,
        iconBytes: iconBytes ?? this.iconBytes,
        iosApplicationToken: iosApplicationToken ?? this.iosApplicationToken,
      );

  Map<String, dynamic> toJson() => {
        'packageName': packageName,
        'appName': appName,
        if (iosApplicationToken != null)
          'iosApplicationToken': iosApplicationToken,
      };

  factory AppRuleItem.fromJson(Map<String, dynamic> json) => AppRuleItem(
        packageName: json['packageName'] as String,
        appName: json['appName'] as String,
        iosApplicationToken: json['iosApplicationToken'] as String?,
      );
}

/// Display model for an app row under "Blocked apps".
class BlockedAppDisplay {
  final AppRuleItem app;
  final bool isBlocked;
  final DateTime? unblockedUntil;
  final DateTime? unblockedStartedAt;

  /// `true` when at least one schedule-active Hard mode rule covers this app.
  /// Hard blocked apps cannot be unblocked — the unblock button is disabled.
  final bool isHardBlocked;

  const BlockedAppDisplay({
    required this.app,
    required this.isBlocked,
    this.unblockedUntil,
    this.unblockedStartedAt,
    this.isHardBlocked = false,
  });

  double? progressAt(DateTime at) {
    if (isBlocked || unblockedUntil == null || unblockedStartedAt == null) {
      return null;
    }
    final total = unblockedUntil!.difference(unblockedStartedAt!).inMilliseconds;
    if (total <= 0) return null;
    final remaining = unblockedUntil!.difference(at).inMilliseconds;
    return (remaining / total).clamp(0.0, 1.0);
  }

  String statusLabelAt(DateTime at) {
    if (isHardBlocked) return 'Hard blocked';
    if (isBlocked) return 'Unblock';
    if (unblockedUntil == null) return 'Unblocked';
    final rem = unblockedUntil!.difference(at);
    if (rem.inHours > 0) {
      return '${rem.inHours}h ${rem.inMinutes.remainder(60)}m left';
    }
    final m = rem.inMinutes.remainder(60).clamp(1, 59);
    return '${m}m left';
  }
}

class AppRule {
  final String id;
  final String name;
  final RuleType type;
  final RuleDifficulty difficulty;
  final List<AppRuleItem> apps;
  final bool isEnabled;
  final DateTime createdAt;

  const AppRule({
    required this.id,
    required this.name,
    required this.type,
    this.difficulty = RuleDifficulty.normal,
    this.apps = const [],
    this.isEnabled = true,
    required this.createdAt,
  });

  /// Base copyWith — subclasses define their own with extra fields.
  AppRule copyWith({
    String? id,
    String? name,
    RuleDifficulty? difficulty,
    List<AppRuleItem>? apps,
    bool? isEnabled,
    DateTime? createdAt,
  }) {
    return AppRule(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type,
      difficulty: difficulty ?? this.difficulty,
      apps: apps ?? this.apps,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get difficultyLabel => switch (difficulty) {
        RuleDifficulty.normal => 'Normal',
        RuleDifficulty.strict => 'Strict',
        RuleDifficulty.deepFocus => 'Deep Focus',
      };

  /// `true` when the rule is in Hard mode (Deep Focus) — unblocks are forbidden.
  bool get isHardMode => difficulty == RuleDifficulty.deepFocus;
}

class SessionRule extends AppRule {
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final List<RepeatDay> repeatDays;

  /// When non-null, the rule is temporarily disabled until this moment.
  final DateTime? disabledUntil;

  /// Per-app unblock end times. Apps with a future timestamp are not blocked.
  final Map<String, DateTime> unblockedUntilByPackage;

  /// Per-app unblock start times — paired with [unblockedUntilByPackage].
  final Map<String, DateTime> unblockedStartedAtByPackage;

  const SessionRule({
    required super.id,
    required super.name,
    super.difficulty = RuleDifficulty.normal,
    super.apps = const [],
    super.isEnabled = true,
    required super.createdAt,
    required this.startTime,
    required this.endTime,
    this.repeatDays = RepeatDay.all,
    this.disabledUntil,
    this.unblockedUntilByPackage = const {},
    this.unblockedStartedAtByPackage = const {},
  }) : super(type: RuleType.session);

  /// Sentinel stored in [disabledUntil] when the user disables a rule
  /// indefinitely. Treated as always in the future by [isCurrentlyDisabled].
  static final DateTime indefiniteDisableUntil =
      DateTime.utc(9999, 12, 31, 23, 59, 59);

  /// Whether the rule is currently in a time-based disabled state.
  /// Returns `true` when [disabledUntil] lies in the future (including
  /// [indefiniteDisableUntil] for indefinite disables).
  bool isCurrentlyDisabled([DateTime? at]) {
    final moment = at ?? DateTime.now();
    final until = disabledUntil;
    return until != null && until.isAfter(moment);
  }

  /// `true` when the rule was disabled with no end date ([indefiniteDisableUntil]).
  bool isIndefinitelyDisabled() {
    final until = disabledUntil;
    if (until == null) return false;
    return !until.isBefore(indefiniteDisableUntil);
  }

  /// Short label for the disabled overlay on rule cards.
  String disabledOverlayLabel([DateTime? at]) {
    if (!isCurrentlyDisabled(at)) return '';
    if (isIndefinitelyDisabled()) return 'Disabled';
    final rem = disabledUntil!.difference(at ?? DateTime.now());
    if (rem.inDays > 0) return '${rem.inDays}d ${rem.inHours.remainder(24)}h';
    if (rem.inHours > 0) {
      return '${rem.inHours}h ${rem.inMinutes.remainder(60)}m';
    }
    final m = rem.inMinutes.remainder(60).clamp(1, 59);
    return '${m}m';
  }

  /// Whether `moment` falls inside the scheduled start→end window, taking
  /// overnight ranges (e.g. 23:00 → 07:00) into account.
  bool isWithinWindowAt(DateTime moment) {
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;
    final dtMinutes = moment.hour * 60 + moment.minute;
    if (startMinutes <= endMinutes) {
      return dtMinutes >= startMinutes && dtMinutes < endMinutes;
    }
    // Overnight window.
    return dtMinutes >= startMinutes || dtMinutes < endMinutes;
  }

  /// Whether any app in this rule has an active per-package unblock window.
  bool isCurrentlyUnblocked([DateTime? at]) {
    final moment = at ?? DateTime.now();
    return apps.any(
      (a) => isPackageTemporarilyUnblocked(a.packageName, moment),
    );
  }

  /// Whether [packageName] has an active unblock window in this rule.
  bool isPackageTemporarilyUnblocked(String packageName, [DateTime? at]) {
    final moment = at ?? DateTime.now();
    final until = unblockedUntilByPackage[packageName];
    return until != null && until.isAfter(moment);
  }

  DateTime? packageUnblockedUntil(String packageName, [DateTime? at]) {
    return isPackageTemporarilyUnblocked(packageName, at)
        ? unblockedUntilByPackage[packageName]
        : null;
  }

  DateTime? packageUnblockedStartedAt(String packageName, [DateTime? at]) {
    return isPackageTemporarilyUnblocked(packageName, at)
        ? unblockedStartedAtByPackage[packageName]
        : null;
  }

  /// Apps in this rule that are still blocked (includes newly added apps).
  bool hasNewAppsToUnblock([DateTime? at]) {
    if (!isScheduleActive(at)) return false;
    return apps.any((a) => isPackageBlocked(a.packageName, at));
  }

  /// Whether [packageName] in this rule is actively blocked right now.
  bool isPackageBlocked(String packageName, [DateTime? at]) {
    if (!apps.any((a) => a.packageName == packageName)) return false;
    if (!isScheduleActive(at)) return false;
    return !isPackageTemporarilyUnblocked(packageName, at);
  }

  /// Rule is schedule-active and at least one app is blocked.
  bool isCurrentlyActive([DateTime? at]) {
    if (!isScheduleActive(at)) return false;
    return apps.any((a) => isPackageBlocked(a.packageName, at));
  }

  /// Drops expired per-package unblock entries.
  SessionRule withPrunedUnblocks([DateTime? at]) {
    final moment = at ?? DateTime.now();
    final until = Map<String, DateTime>.from(unblockedUntilByPackage);
    final started = Map<String, DateTime>.from(unblockedStartedAtByPackage);
    until.removeWhere((_, end) => !end.isAfter(moment));
    started.removeWhere((pkg, _) => !until.containsKey(pkg));
    if (mapEquals(until, unblockedUntilByPackage) &&
        mapEquals(started, unblockedStartedAtByPackage)) {
      return this;
    }
    return copyWith(
      unblockedUntilByPackage: until,
      unblockedStartedAtByPackage: started,
    );
  }

  static Map<String, DateTime> _parseDateTimeMap(dynamic raw) {
    if (raw is! Map) return {};
    return Map<String, DateTime>.fromEntries(
      raw.entries.map(
        (e) => MapEntry(
          e.key as String,
          DateTime.parse(e.value as String),
        ),
      ),
    );
  }

  static Map<String, String> _serializeDateTimeMap(Map<String, DateTime> map) =>
      map.map((k, v) => MapEntry(k, v.toIso8601String()));

  /// Rule is inside its schedule window, enabled, and not user-disabled.
  /// Used for card visuals and countdown — includes temporary unblocks.
  bool isScheduleActive([DateTime? at]) {
    final moment = at ?? DateTime.now();
    return isEnabled &&
        !isCurrentlyDisabled(moment) &&
        isWithinWindow(moment);
  }

  /// Returns `true` when [at] falls inside this rule's scheduled day + time
  /// window. Both the day-of-week ([repeatDays]) and the [startTime]/[endTime]
  /// are honoured. Overnight windows (e.g. 23:00 → 07:00) that span midnight
  /// are considered active on the **start** day only.
  bool isWithinWindow(DateTime at) {
    final today = RepeatDay.fromDateTimeWeekday(at.weekday);
    if (!repeatDays.contains(today)) return false;

    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;
    final atMinutes = at.hour * 60 + at.minute;

    if (startMinutes <= endMinutes) {
      return atMinutes >= startMinutes && atMinutes < endMinutes;
    }
    // Overnight window — still attributed to the start day.
    return atMinutes >= startMinutes || atMinutes < endMinutes;
  }

  /// Computes the [DateTime] of the next upcoming scheduled start after [from]
  /// (i.e. the nearest future moment whose day is in [repeatDays] and whose
  /// time-of-day equals [startTime]). Used to render "Starts in Xd Xh Xm".
  DateTime nextStartAfter(DateTime from) {
    final earliestDay =
        DateTime(createdAt.year, createdAt.month, createdAt.day);
    for (var i = 0; i < 8; i++) {
      final candidate = DateTime(
        from.year,
        from.month,
        from.day + i,
        startTime.hour,
        startTime.minute,
      );
      if (!candidate.isAfter(from)) continue;
      final candidateDay =
          DateTime(candidate.year, candidate.month, candidate.day);
      if (candidateDay.isBefore(earliestDay)) continue;
      if (repeatDays
          .contains(RepeatDay.fromDateTimeWeekday(candidate.weekday))) {
        return candidate;
      }
    }
    // Fallback: same time tomorrow even if day not selected (should not happen
    // in practice because repeatDays is never empty).
    return DateTime(
      from.year,
      from.month,
      from.day + 1,
      startTime.hour,
      startTime.minute,
    );
  }

  /// End of the scheduled window that contains [start] (the moment the rule
  /// becomes active).
  DateTime endAtForStart(DateTime start) {
    final startMin = startTime.hour * 60 + startTime.minute;
    final endMin = endTime.hour * 60 + endTime.minute;
    if (endMin > startMin) {
      return DateTime(
        start.year,
        start.month,
        start.day,
        endTime.hour,
        endTime.minute,
      );
    }
    return DateTime(
      start.year,
      start.month,
      start.day + 1,
      endTime.hour,
      endTime.minute,
    );
  }

  /// Next moment this rule's scheduled window ends after [from].
  DateTime nextEndAfter(DateTime from) {
    if (isWithinWindow(from)) {
      final endMin = endTime.hour * 60 + endTime.minute;
      final startMin = startTime.hour * 60 + startTime.minute;
      final atMin = from.hour * 60 + from.minute;
      if (endMin > startMin) {
        return DateTime(
          from.year,
          from.month,
          from.day,
          endTime.hour,
          endTime.minute,
        );
      }
      if (atMin >= startMin) {
        return DateTime(
          from.year,
          from.month,
          from.day + 1,
          endTime.hour,
          endTime.minute,
        );
      }
      return DateTime(
        from.year,
        from.month,
        from.day,
        endTime.hour,
        endTime.minute,
      );
    }
    return endAtForStart(nextStartAfter(from));
  }

  String get formattedTime {
    final start = _formatTime(startTime);
    final end = _formatTime(endTime);
    return '$start - $end';
  }

  String get repeatLabel {
    if (repeatDays.length == 7) return 'Daily';
    if (repeatDays.length == 5 &&
        repeatDays.every((d) => RepeatDay.weekdays.contains(d))) {
      return 'Weekdays';
    }
    if (repeatDays.length == 2 &&
        repeatDays.every((d) => RepeatDay.weekend.contains(d))) {
      return 'Weekends';
    }
    return repeatDays.map((d) => d.shortLabel).join(', ');
  }

  static String _formatTime(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  SessionRule copyWith({
    String? id,
    String? name,
    RuleDifficulty? difficulty,
    List<AppRuleItem>? apps,
    bool? isEnabled,
    DateTime? createdAt,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    List<RepeatDay>? repeatDays,
    DateTime? disabledUntil,
    bool clearDisabledUntil = false,
    Map<String, DateTime>? unblockedUntilByPackage,
    Map<String, DateTime>? unblockedStartedAtByPackage,
  }) {
    return SessionRule(
      id: id ?? this.id,
      name: name ?? this.name,
      difficulty: difficulty ?? this.difficulty,
      apps: apps ?? this.apps,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      repeatDays: repeatDays ?? this.repeatDays,
      disabledUntil:
          clearDisabledUntil ? null : (disabledUntil ?? this.disabledUntil),
      unblockedUntilByPackage:
          unblockedUntilByPackage ?? this.unblockedUntilByPackage,
      unblockedStartedAtByPackage:
          unblockedStartedAtByPackage ?? this.unblockedStartedAtByPackage,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': 'session',
        'difficulty': difficulty.index,
        'apps': apps.map((a) => a.toJson()).toList(),
        'isEnabled': isEnabled,
        'createdAt': createdAt.toIso8601String(),
        'startHour': startTime.hour,
        'startMinute': startTime.minute,
        'endHour': endTime.hour,
        'endMinute': endTime.minute,
        'repeatDays': repeatDays.map((d) => d.index).toList(),
        if (disabledUntil != null)
          'disabledUntil': disabledUntil!.toIso8601String(),
        if (unblockedUntilByPackage.isNotEmpty)
          'unblockedUntilByPackage':
              _serializeDateTimeMap(unblockedUntilByPackage),
        if (unblockedStartedAtByPackage.isNotEmpty)
          'unblockedStartedAtByPackage':
              _serializeDateTimeMap(unblockedStartedAtByPackage),
      };

  factory SessionRule.fromJson(Map<String, dynamic> json) {
    var untilByPackage = _parseDateTimeMap(json['unblockedUntilByPackage']);
    var startedByPackage = _parseDateTimeMap(json['unblockedStartedAtByPackage']);

    // Migrate legacy single-window unblock fields.
    if (untilByPackage.isEmpty && json['unblockedUntil'] != null) {
      final legacyUntil = DateTime.parse(json['unblockedUntil'] as String);
      final legacyStarted = json['unblockedStartedAt'] == null
          ? legacyUntil
          : DateTime.parse(json['unblockedStartedAt'] as String);
      final packages = (json['unblockedPackageNames'] as List?)
              ?.map((e) => e as String)
              .toList() ??
          [];
      for (final pkg in packages) {
        untilByPackage[pkg] = legacyUntil;
        startedByPackage[pkg] = legacyStarted;
      }
    }

    return SessionRule(
        id: json['id'] as String,
        name: json['name'] as String,
        difficulty: RuleDifficulty.values[json['difficulty'] as int? ?? 0],
        apps: (json['apps'] as List?)
                ?.map((a) => AppRuleItem.fromJson(a as Map<String, dynamic>))
                .toList() ??
            [],
        isEnabled: json['isEnabled'] as bool? ?? true,
        createdAt: DateTime.parse(
            json['createdAt'] as String? ?? DateTime.now().toIso8601String()),
        startTime: TimeOfDay(
            hour: json['startHour'] as int? ?? 23,
            minute: json['startMinute'] as int? ?? 0),
        endTime: TimeOfDay(
            hour: json['endHour'] as int? ?? 7,
            minute: json['endMinute'] as int? ?? 0),
        repeatDays: (json['repeatDays'] as List?)
                ?.map((d) => RepeatDay.values[d as int])
                .toList() ??
            RepeatDay.all,
        disabledUntil: json['disabledUntil'] == null
            ? null
            : DateTime.parse(json['disabledUntil'] as String),
        unblockedUntilByPackage: untilByPackage,
        unblockedStartedAtByPackage: startedByPackage,
      );
  }
}

class TimeLimitRule extends AppRule {
  final Duration allowedTime;
  final Duration blockUntil;
  final List<RepeatDay> repeatDays;

  /// When non-null, the rule is temporarily disabled until this moment.
  final DateTime? disabledUntil;

  /// Per-app unblock end times. Apps with a future timestamp are not blocked.
  final Map<String, DateTime> unblockedUntilByPackage;

  /// Per-app unblock start times — paired with [unblockedUntilByPackage].
  final Map<String, DateTime> unblockedStartedAtByPackage;

  /// When daily usage first crossed [allowedTime] today (per package).
  final Map<String, DateTime> limitExceededAtByPackage;

  /// Per-app screen time (ms) already used before this rule started tracking.
  /// Only usage above this baseline counts toward [allowedTime].
  final Map<String, int> usageBaselineMsByPackage;

  /// Calendar day that [limitExceededAtByPackage] applies to.
  final String? usageQuotaDay;

  const TimeLimitRule({
    required super.id,
    required super.name,
    super.difficulty = RuleDifficulty.normal,
    super.apps = const [],
    super.isEnabled = true,
    required super.createdAt,
    this.allowedTime = const Duration(minutes: 30),
    this.blockUntil = const Duration(hours: 24),
    this.repeatDays = RepeatDay.weekdays,
    this.disabledUntil,
    this.unblockedUntilByPackage = const {},
    this.unblockedStartedAtByPackage = const {},
    this.limitExceededAtByPackage = const {},
    this.usageBaselineMsByPackage = const {},
    this.usageQuotaDay,
  }) : super(type: RuleType.timeLimit);

  static String quotaDayKey(DateTime at) =>
      '${at.year}-${at.month}-${at.day}';

  static final DateTime indefiniteDisableUntil =
      SessionRule.indefiniteDisableUntil;

  String get formattedAllowed {
    final h = allowedTime.inHours;
    final m = allowedTime.inMinutes.remainder(60);
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  String get formattedBlockUntil {
    if (blockUntil.inHours >= 24) return 'Tomorrow';
    final h = blockUntil.inHours;
    final m = blockUntil.inMinutes.remainder(60);
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  bool isCurrentlyDisabled([DateTime? at]) {
    final moment = at ?? DateTime.now();
    final until = disabledUntil;
    return until != null && until.isAfter(moment);
  }

  bool isIndefinitelyDisabled() {
    final until = disabledUntil;
    if (until == null) return false;
    return !until.isBefore(indefiniteDisableUntil);
  }

  String disabledOverlayLabel([DateTime? at]) {
    if (!isCurrentlyDisabled(at)) return '';
    if (isIndefinitelyDisabled()) return 'Disabled';
    final rem = disabledUntil!.difference(at ?? DateTime.now());
    if (rem.inDays > 0) return '${rem.inDays}d ${rem.inHours.remainder(24)}h';
    if (rem.inHours > 0) {
      return '${rem.inHours}h ${rem.inMinutes.remainder(60)}m';
    }
    final m = rem.inMinutes.remainder(60).clamp(1, 59);
    return '${m}m';
  }

  bool isOnActiveDay(DateTime at) {
    final today = RepeatDay.fromDateTimeWeekday(at.weekday);
    return repeatDays.contains(today);
  }

  /// Midnight at the start of the next eligible repeat day after [from].
  DateTime nextStartAfter(DateTime from) => nextDayStartAfter(
        from: from,
        createdAt: createdAt,
        repeatDays: repeatDays,
      );

  DateTime nextActiveAfter(DateTime from) => nextStartAfter(from);

  bool isRuleActive([DateTime? at]) {
    final moment = at ?? DateTime.now();
    return isEnabled && !isCurrentlyDisabled(moment) && isOnActiveDay(moment);
  }

  TimeLimitRule withQuotaRollover([DateTime? at]) {
    final moment = at ?? DateTime.now();
    final key = TimeLimitRule.quotaDayKey(moment);
    if (usageQuotaDay == key) return this;
    return copyWith(
      usageQuotaDay: key,
      limitExceededAtByPackage: const {},
      usageBaselineMsByPackage: const {},
    );
  }

  /// Usage that counts toward [allowedTime] — today total minus the baseline
  /// captured when the rule started tracking this package.
  Duration effectiveUsageForPackage(
    String packageName,
    Duration todayUsage,
  ) {
    final baselineMs = usageBaselineMsByPackage[packageName] ?? 0;
    final effectiveMs = todayUsage.inMilliseconds - baselineMs;
    if (effectiveMs <= 0) return Duration.zero;
    return Duration(milliseconds: effectiveMs);
  }

  bool isPackageTemporarilyUnblocked(String packageName, [DateTime? at]) {
    final moment = at ?? DateTime.now();
    final until = unblockedUntilByPackage[packageName];
    return until != null && until.isAfter(moment);
  }

  /// Block expiry after the daily usage cap is first exceeded.
  DateTime resolveBlockExpiry(DateTime exceededAt) {
    if (blockUntil.inHours >= 24) {
      return DateTime(
        exceededAt.year,
        exceededAt.month,
        exceededAt.day + 1,
      );
    }
    return exceededAt.add(blockUntil);
  }

  /// Whether [packageName] is blocked because rule-tracked usage reached
  /// [allowedTime]. [trackedUsage] should be [effectiveUsageForPackage].
  bool isPackageBlocked(
    String packageName,
    Duration trackedUsage, [
    DateTime? at,
  ]) {
    if (!apps.any((a) => a.packageName == packageName)) return false;
    if (!isRuleActive(at)) return false;
    if (isPackageTemporarilyUnblocked(packageName, at)) return false;
    if (trackedUsage < allowedTime) return false;

    final exceededAt = limitExceededAtByPackage[packageName];
    if (exceededAt == null) return true;

    final moment = at ?? DateTime.now();
    return moment.isBefore(resolveBlockExpiry(exceededAt));
  }

  bool isCurrentlyActive(Duration trackedUsage, [DateTime? at]) {
    if (!isRuleActive(at)) return false;
    return apps.any((a) => isPackageBlocked(a.packageName, trackedUsage, at));
  }

  TimeLimitRule withPrunedUnblocks([DateTime? at]) {
    final moment = at ?? DateTime.now();
    final until = Map<String, DateTime>.from(unblockedUntilByPackage);
    final started = Map<String, DateTime>.from(unblockedStartedAtByPackage);
    until.removeWhere((_, end) => !end.isAfter(moment));
    started.removeWhere((pkg, _) => !until.containsKey(pkg));
    if (mapEquals(until, unblockedUntilByPackage) &&
        mapEquals(started, unblockedStartedAtByPackage)) {
      return this;
    }
    return copyWith(
      unblockedUntilByPackage: until,
      unblockedStartedAtByPackage: started,
    );
  }

  String get repeatLabel {
    if (repeatDays.length == 7) return 'Everyday';
    if (repeatDays.length == 5 &&
        repeatDays.every((d) => RepeatDay.weekdays.contains(d))) {
      return 'Weekdays';
    }
    if (repeatDays.length == 2 &&
        repeatDays.every((d) => RepeatDay.weekend.contains(d))) {
      return 'Weekends';
    }
    return repeatDays.map((d) => d.shortLabel).join(', ');
  }

  @override
  TimeLimitRule copyWith({
    String? id,
    String? name,
    RuleDifficulty? difficulty,
    List<AppRuleItem>? apps,
    bool? isEnabled,
    DateTime? createdAt,
    Duration? allowedTime,
    Duration? blockUntil,
    List<RepeatDay>? repeatDays,
    DateTime? disabledUntil,
    bool clearDisabledUntil = false,
    Map<String, DateTime>? unblockedUntilByPackage,
    Map<String, DateTime>? unblockedStartedAtByPackage,
    Map<String, DateTime>? limitExceededAtByPackage,
    Map<String, int>? usageBaselineMsByPackage,
    String? usageQuotaDay,
  }) {
    return TimeLimitRule(
      id: id ?? this.id,
      name: name ?? this.name,
      difficulty: difficulty ?? this.difficulty,
      apps: apps ?? this.apps,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      allowedTime: allowedTime ?? this.allowedTime,
      blockUntil: blockUntil ?? this.blockUntil,
      repeatDays: repeatDays ?? this.repeatDays,
      disabledUntil:
          clearDisabledUntil ? null : (disabledUntil ?? this.disabledUntil),
      unblockedUntilByPackage:
          unblockedUntilByPackage ?? this.unblockedUntilByPackage,
      unblockedStartedAtByPackage:
          unblockedStartedAtByPackage ?? this.unblockedStartedAtByPackage,
      limitExceededAtByPackage:
          limitExceededAtByPackage ?? this.limitExceededAtByPackage,
      usageBaselineMsByPackage:
          usageBaselineMsByPackage ?? this.usageBaselineMsByPackage,
      usageQuotaDay: usageQuotaDay ?? this.usageQuotaDay,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': 'timeLimit',
        'difficulty': difficulty.index,
        'apps': apps.map((a) => a.toJson()).toList(),
        'isEnabled': isEnabled,
        'createdAt': createdAt.toIso8601String(),
        'allowedTimeMinutes': allowedTime.inMinutes,
        'blockUntilMinutes': blockUntil.inMinutes,
        'repeatDays': repeatDays.map((d) => d.index).toList(),
        if (usageQuotaDay != null) 'usageQuotaDay': usageQuotaDay,
        if (disabledUntil != null)
          'disabledUntil': disabledUntil!.toIso8601String(),
        if (unblockedUntilByPackage.isNotEmpty)
          'unblockedUntilByPackage': SessionRule._serializeDateTimeMap(
            unblockedUntilByPackage,
          ),
        if (unblockedStartedAtByPackage.isNotEmpty)
          'unblockedStartedAtByPackage': SessionRule._serializeDateTimeMap(
            unblockedStartedAtByPackage,
          ),
        if (limitExceededAtByPackage.isNotEmpty)
          'limitExceededAtByPackage': SessionRule._serializeDateTimeMap(
            limitExceededAtByPackage,
          ),
        if (usageBaselineMsByPackage.isNotEmpty)
          'usageBaselineMsByPackage': usageBaselineMsByPackage,
      };

  factory TimeLimitRule.fromJson(Map<String, dynamic> json) => TimeLimitRule(
        id: json['id'] as String,
        name: json['name'] as String,
        difficulty: RuleDifficulty.values[json['difficulty'] as int? ?? 0],
        apps: (json['apps'] as List?)
                ?.map((a) => AppRuleItem.fromJson(a as Map<String, dynamic>))
                .toList() ??
            [],
        isEnabled: json['isEnabled'] as bool? ?? true,
        createdAt: DateTime.parse(
          json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
        ),
        allowedTime: Duration(
          minutes: json['allowedTimeMinutes'] as int? ?? 30,
        ),
        blockUntil: Duration(
          minutes: json['blockUntilMinutes'] as int? ?? 1440,
        ),
        repeatDays: (json['repeatDays'] as List?)
                ?.map((d) => RepeatDay.values[d as int])
                .toList() ??
            RepeatDay.weekdays,
        disabledUntil: json['disabledUntil'] == null
            ? null
            : DateTime.parse(json['disabledUntil'] as String),
        unblockedUntilByPackage:
            SessionRule._parseDateTimeMap(json['unblockedUntilByPackage']),
        unblockedStartedAtByPackage:
            SessionRule._parseDateTimeMap(json['unblockedStartedAtByPackage']),
        limitExceededAtByPackage:
            SessionRule._parseDateTimeMap(json['limitExceededAtByPackage']),
        usageBaselineMsByPackage: _parseIntMap(json['usageBaselineMsByPackage']),
        usageQuotaDay: json['usageQuotaDay'] as String? ??
            json['quotaDayKey'] as String?,
      );
}

Map<String, int> _parseIntMap(dynamic raw) {
  if (raw is! Map) return {};
  return Map<String, int>.fromEntries(
    raw.entries.map(
      (e) => MapEntry(e.key as String, (e.value as num).toInt()),
    ),
  );
}

/// While active, all [apps] are blocked. [maxOpens] is the daily allowance of
/// temporary unblock actions (each uses [sessionLengthMinutes]).
class OpenLimitRule extends AppRule {
  final int maxOpens;
  final int sessionLengthMinutes;
  final List<RepeatDay> repeatDays;

  /// When non-null, the rule is temporarily disabled until this moment.
  final DateTime? disabledUntil;

  /// Per-app unblock end times. Apps with a future timestamp are not blocked.
  final Map<String, DateTime> unblockedUntilByPackage;

  /// Per-app unblock start times — paired with [unblockedUntilByPackage].
  final Map<String, DateTime> unblockedStartedAtByPackage;

  /// Unblock actions consumed today for this rule ("unblock all" = 1).
  final int unblocksUsed;

  /// Calendar day ([quotaDayKey]) that [unblocksUsed] applies to.
  final String? unblocksQuotaDay;

  const OpenLimitRule({
    required super.id,
    required super.name,
    super.difficulty = RuleDifficulty.normal,
    super.apps = const [],
    super.isEnabled = true,
    required super.createdAt,
    this.maxOpens = 4,
    this.sessionLengthMinutes = 5,
    this.repeatDays = RepeatDay.weekdays,
    this.disabledUntil,
    this.unblockedUntilByPackage = const {},
    this.unblockedStartedAtByPackage = const {},
    this.unblocksUsed = 0,
    this.unblocksQuotaDay,
  }) : super(type: RuleType.openLimit);

  static String quotaDayKey(DateTime at) =>
      '${at.year}-${at.month}-${at.day}';

  static final DateTime indefiniteDisableUntil =
      SessionRule.indefiniteDisableUntil;

  bool isCurrentlyDisabled([DateTime? at]) {
    final moment = at ?? DateTime.now();
    final until = disabledUntil;
    return until != null && until.isAfter(moment);
  }

  bool isIndefinitelyDisabled() {
    final until = disabledUntil;
    if (until == null) return false;
    return !until.isBefore(indefiniteDisableUntil);
  }

  String disabledOverlayLabel([DateTime? at]) {
    if (!isCurrentlyDisabled(at)) return '';
    if (isIndefinitelyDisabled()) return 'Disabled';
    final rem = disabledUntil!.difference(at ?? DateTime.now());
    if (rem.inDays > 0) return '${rem.inDays}d ${rem.inHours.remainder(24)}h';
    if (rem.inHours > 0) {
      return '${rem.inHours}h ${rem.inMinutes.remainder(60)}m';
    }
    final m = rem.inMinutes.remainder(60).clamp(1, 59);
    return '${m}m';
  }

  bool isOnActiveDay(DateTime at) {
    final today = RepeatDay.fromDateTimeWeekday(at.weekday);
    return repeatDays.contains(today);
  }

  /// Midnight at the start of the next eligible repeat day after [from].
  DateTime nextStartAfter(DateTime from) => nextDayStartAfter(
        from: from,
        createdAt: createdAt,
        repeatDays: repeatDays,
      );

  /// Used for "Starts in …" when today is not an active day.
  DateTime nextActiveAfter(DateTime from) => nextStartAfter(from);

  /// Rule is enabled, not user-disabled, and today is in [repeatDays].
  bool isRuleActive([DateTime? at]) {
    final moment = at ?? DateTime.now();
    return isEnabled && !isCurrentlyDisabled(moment) && isOnActiveDay(moment);
  }

  OpenLimitRule withQuotaRollover([DateTime? at]) {
    final moment = at ?? DateTime.now();
    final key = quotaDayKey(moment);
    if (unblocksQuotaDay == key) return this;
    return copyWith(unblocksUsed: 0, unblocksQuotaDay: key);
  }

  int get unblocksRemaining => (maxOpens - unblocksUsed).clamp(0, maxOpens);

  bool get hasUnblockQuota => unblocksRemaining > 0;

  bool isPackageTemporarilyUnblocked(String packageName, [DateTime? at]) {
    final moment = at ?? DateTime.now();
    final until = unblockedUntilByPackage[packageName];
    return until != null && until.isAfter(moment);
  }

  /// Whether [packageName] is blocked by this active rule (not on a break).
  bool isPackageBlocked(String packageName, [DateTime? at]) {
    if (!apps.any((a) => a.packageName == packageName)) return false;
    if (!isRuleActive(at)) return false;
    return !isPackageTemporarilyUnblocked(packageName, at);
  }

  bool isCurrentlyActive([DateTime? at]) {
    if (!isRuleActive(at)) return false;
    return apps.any((a) => isPackageBlocked(a.packageName, at));
  }

  OpenLimitRule withPrunedUnblocks([DateTime? at]) {
    final moment = at ?? DateTime.now();
    final until = Map<String, DateTime>.from(unblockedUntilByPackage);
    final started = Map<String, DateTime>.from(unblockedStartedAtByPackage);
    until.removeWhere((_, end) => !end.isAfter(moment));
    started.removeWhere((pkg, _) => !until.containsKey(pkg));
    if (mapEquals(until, unblockedUntilByPackage) &&
        mapEquals(started, unblockedStartedAtByPackage)) {
      return this;
    }
    return copyWith(
      unblockedUntilByPackage: until,
      unblockedStartedAtByPackage: started,
    );
  }

  String get repeatLabel {
    if (repeatDays.length == 7) return 'Everyday';
    if (repeatDays.length == 5 &&
        repeatDays.every((d) => RepeatDay.weekdays.contains(d))) {
      return 'Weekdays';
    }
    if (repeatDays.length == 2 &&
        repeatDays.every((d) => RepeatDay.weekend.contains(d))) {
      return 'Weekends';
    }
    return repeatDays.map((d) => d.shortLabel).join(', ');
  }

  Duration get sessionLength => Duration(minutes: sessionLengthMinutes);

  @override
  OpenLimitRule copyWith({
    String? id,
    String? name,
    RuleDifficulty? difficulty,
    List<AppRuleItem>? apps,
    bool? isEnabled,
    DateTime? createdAt,
    int? maxOpens,
    int? sessionLengthMinutes,
    List<RepeatDay>? repeatDays,
    DateTime? disabledUntil,
    bool clearDisabledUntil = false,
    Map<String, DateTime>? unblockedUntilByPackage,
    Map<String, DateTime>? unblockedStartedAtByPackage,
    int? unblocksUsed,
    String? unblocksQuotaDay,
  }) {
    return OpenLimitRule(
      id: id ?? this.id,
      name: name ?? this.name,
      difficulty: difficulty ?? this.difficulty,
      apps: apps ?? this.apps,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      maxOpens: maxOpens ?? this.maxOpens,
      sessionLengthMinutes: sessionLengthMinutes ?? this.sessionLengthMinutes,
      repeatDays: repeatDays ?? this.repeatDays,
      disabledUntil:
          clearDisabledUntil ? null : (disabledUntil ?? this.disabledUntil),
      unblockedUntilByPackage:
          unblockedUntilByPackage ?? this.unblockedUntilByPackage,
      unblockedStartedAtByPackage:
          unblockedStartedAtByPackage ?? this.unblockedStartedAtByPackage,
      unblocksUsed: unblocksUsed ?? this.unblocksUsed,
      unblocksQuotaDay: unblocksQuotaDay ?? this.unblocksQuotaDay,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': 'openLimit',
        'difficulty': difficulty.index,
        'apps': apps.map((a) => a.toJson()).toList(),
        'isEnabled': isEnabled,
        'createdAt': createdAt.toIso8601String(),
        'maxOpens': maxOpens,
        'sessionLengthMinutes': sessionLengthMinutes,
        'repeatDays': repeatDays.map((d) => d.index).toList(),
        'unblocksUsed': unblocksUsed,
        if (unblocksQuotaDay != null) 'unblocksQuotaDay': unblocksQuotaDay,
        if (disabledUntil != null)
          'disabledUntil': disabledUntil!.toIso8601String(),
        if (unblockedUntilByPackage.isNotEmpty)
          'unblockedUntilByPackage': SessionRule._serializeDateTimeMap(
            unblockedUntilByPackage,
          ),
        if (unblockedStartedAtByPackage.isNotEmpty)
          'unblockedStartedAtByPackage': SessionRule._serializeDateTimeMap(
            unblockedStartedAtByPackage,
          ),
      };

  factory OpenLimitRule.fromJson(Map<String, dynamic> json) => OpenLimitRule(
        id: json['id'] as String,
        name: json['name'] as String,
        difficulty: RuleDifficulty.values[json['difficulty'] as int? ?? 0],
        apps: (json['apps'] as List?)
                ?.map((a) => AppRuleItem.fromJson(a as Map<String, dynamic>))
                .toList() ??
            [],
        isEnabled: json['isEnabled'] as bool? ?? true,
        createdAt: DateTime.parse(
          json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
        ),
        maxOpens: json['maxOpens'] as int? ?? 4,
        sessionLengthMinutes: json['sessionLengthMinutes'] as int? ?? 5,
        repeatDays: (json['repeatDays'] as List?)
                ?.map((d) => RepeatDay.values[d as int])
                .toList() ??
            RepeatDay.weekdays,
        disabledUntil: json['disabledUntil'] == null
            ? null
            : DateTime.parse(json['disabledUntil'] as String),
        unblockedUntilByPackage:
            SessionRule._parseDateTimeMap(json['unblockedUntilByPackage']),
        unblockedStartedAtByPackage:
            SessionRule._parseDateTimeMap(json['unblockedStartedAtByPackage']),
        unblocksUsed: json['unblocksUsed'] as int? ?? 0,
        unblocksQuotaDay: json['unblocksQuotaDay'] as String?,
      );
}
