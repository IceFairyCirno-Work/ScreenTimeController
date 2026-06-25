import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/focus_timer_blocking_state.dart';
import '../providers/autofocus_settings_provider.dart';
import '../providers/emergency_pass_provider.dart';
import '../providers/folder_apps_provider.dart';
import '../providers/permissions_provider.dart';
import '../providers/rules_provider.dart';
import '../providers/timer_provider.dart';
import '../services/app_blocking_service.dart';
import '../services/blocking_sync_coordinator.dart';

/// Watches rules and timer state and pushes the blocked package list to native.
class BlockingSyncListener extends StatefulWidget {
  const BlockingSyncListener({super.key, required this.child});

  final Widget child;

  @override
  State<BlockingSyncListener> createState() => _BlockingSyncListenerState();
}

class _BlockingSyncListenerState extends State<BlockingSyncListener>
    with WidgetsBindingObserver {
  static const _pollInterval = Duration(seconds: 1);

  final AppBlockingService _blockingService = AppBlockingService();
  Set<String>? _lastSynced;
  Set<String>? _lastSyncedDistracting;
  Map<String, int>? _lastSyncedUnblocks;
  Set<String>? _lastSyncedDomains;
  Map<String, int>? _lastSyncedDomainUnblocks;
  String? _lastSyncedTimeLimitRulesJson;
  String? _lastSyncedSessionRulesJson;
  bool? _lastAdultWebsitesBlocked;
  bool? _lastDistractingOverlayEnabled;
  bool? _lastEmergencyPassActive;
  String? _lastScheduleStateKey;
  String? _lastTimerStateKey;
  Timer? _pollTimer;
  bool _listenersAttached = false;

  RulesProvider? _rules;
  TimerProvider? _timer;
  PermissionsProvider? _permissions;
  FolderAppsProvider? _folderApps;

  EmergencyPassProvider? _emergencyPass;
  AutofocusSettingsProvider? _autofocusSettings;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _attachListeners());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _lastScheduleStateKey = null;
      unawaited(_applyPendingAutoMovedFolders());
      _scheduleSync(force: true);
    }
  }

  Future<void> _applyPendingAutoMovedFolders() async {
    if (!mounted || _folderApps == null) return;
    await applyPendingAutoMovedFolders(context.read<FolderAppsProvider>());
  }

  void _attachListeners() {
    if (!mounted || _rules != null) return;

    _rules = context.read<RulesProvider>()..addListener(_scheduleSync);
    _timer = context.read<TimerProvider>()..addListener(_scheduleSync);
    _permissions = context.read<PermissionsProvider>()..addListener(_scheduleSync);
    _folderApps = context.read<FolderAppsProvider>()..addListener(_onFolderAppsChanged);
    _emergencyPass = context.read<EmergencyPassProvider>()..addListener(_scheduleSync);
    _autofocusSettings = context.read<AutofocusSettingsProvider>()
      ..addListener(_scheduleSync);

    _listenersAttached = true;
    _pollTimer = Timer.periodic(_pollInterval, (_) => _scheduleSync());

    _onFolderAppsChanged();
    _scheduleSync();
  }

  void _onFolderAppsChanged() {
    if (!mounted) return;
    final folderApps = context.read<FolderAppsProvider>();
    final rules = context.read<RulesProvider>();
    rules.setAlwaysAllowedPackages(folderApps.alwaysAllowedPackageNames);
    rules.setNeverAllowedPackages(folderApps.neverAllowedPackageNames);
    _scheduleSync();
  }

  void _scheduleSync({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _syncIfNeeded(force: force),
    );
  }

  void _syncIfNeeded({bool force = false}) {
    if (!mounted || !_listenersAttached) return;

    final payload = _computeSyncPayload(this);
    if (!force && !payload.scheduleChanged && !payload.timerChanged && _isPayloadUnchanged(payload)) {
      return;
    }

    _lastSynced = Set<String>.from(payload.packages);
    _lastSyncedDistracting = Set<String>.from(payload.distractingPackages);
    _lastSyncedUnblocks = Map<String, int>.from(payload.temporaryUnblocks);
    _lastSyncedDomains = Set<String>.from(payload.domains);
    _lastSyncedDomainUnblocks = Map<String, int>.from(payload.temporaryDomainUnblocks);
    _lastSyncedTimeLimitRulesJson = payload.timeLimitRulesJson;
    _lastSyncedSessionRulesJson = payload.sessionScheduleRulesJson;
    _lastAdultWebsitesBlocked = payload.adultWebsitesBlocked;
    _lastDistractingOverlayEnabled = payload.distractingOverlayEnabled;
    _lastEmergencyPassActive = payload.emergencyActive;
    _blockingService.syncBlockedPackages(
      payload.packages,
      temporaryUnblockUntilByPackage: payload.temporaryUnblocks,
      domains: payload.domains,
      temporaryUnblockUntilByDomain: payload.temporaryDomainUnblocks,
      timeLimitRules: payload.timeLimitRules,
      sessionScheduleRules: payload.sessionScheduleRules,
      adultWebsitesBlocked: payload.adultWebsitesBlocked,
      distractingPackages: payload.distractingPackages,
      distractingOverlayEnabled: payload.distractingOverlayEnabled,
      alwaysAllowedPackages: payload.alwaysAllowed,
      neverAllowedPackages: payload.neverAllowed,
      emergencyPassActive: payload.emergencyActive,
    );
  }

  bool _isPayloadUnchanged(_SyncPayload payload) {
    return setEquals(_lastSynced, payload.packages) &&
        setEquals(_lastSyncedDistracting, payload.distractingPackages) &&
        mapEquals(_lastSyncedUnblocks, payload.temporaryUnblocks) &&
        setEquals(_lastSyncedDomains, payload.domains) &&
        mapEquals(_lastSyncedDomainUnblocks, payload.temporaryDomainUnblocks) &&
        _lastSyncedTimeLimitRulesJson == payload.timeLimitRulesJson &&
        _lastSyncedSessionRulesJson == payload.sessionScheduleRulesJson &&
        _lastAdultWebsitesBlocked == payload.adultWebsitesBlocked &&
        _lastDistractingOverlayEnabled == payload.distractingOverlayEnabled &&
        _lastEmergencyPassActive == payload.emergencyActive;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _rules?.removeListener(_scheduleSync);
    _timer?.removeListener(_scheduleSync);
    _permissions?.removeListener(_scheduleSync);
    _folderApps?.removeListener(_onFolderAppsChanged);
    _emergencyPass?.removeListener(_scheduleSync);
    _autofocusSettings?.removeListener(_scheduleSync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _SyncPayload {
  _SyncPayload({
    required this.packages,
    required this.temporaryUnblocks,
    required this.domains,
    required this.temporaryDomainUnblocks,
    required this.timeLimitRules,
    required this.sessionScheduleRules,
    required this.adultWebsitesBlocked,
    required this.distractingPackages,
    required this.distractingOverlayEnabled,
    required this.alwaysAllowed,
    required this.neverAllowed,
    required this.emergencyActive,
    required this.scheduleChanged,
    required this.timerChanged,
    required this.timeLimitRulesJson,
    required this.sessionScheduleRulesJson,
  });

  final Set<String> packages;
  final Map<String, int> temporaryUnblocks;
  final Set<String> domains;
  final Map<String, int> temporaryDomainUnblocks;
  final List<Map<String, dynamic>> timeLimitRules;
  final List<Map<String, dynamic>> sessionScheduleRules;
  final bool adultWebsitesBlocked;
  final Set<String> distractingPackages;
  final bool distractingOverlayEnabled;
  final Set<String> alwaysAllowed;
  final Set<String> neverAllowed;
  final bool emergencyActive;
  final bool scheduleChanged;
  final bool timerChanged;
  final String timeLimitRulesJson;
  final String sessionScheduleRulesJson;
}

_SyncPayload _computeSyncPayload(_BlockingSyncListenerState listener) {
  final rules = listener._rules!;
  final timer = listener._timer!;
  final folderApps = listener._folderApps!;
  final emergencyPass = listener._emergencyPass!;
  final autofocusSettings = listener._autofocusSettings!;
  final emergencyActive = emergencyPass.isActive;

  final alwaysAllowed = folderApps.alwaysAllowedPackageNames;
  final neverAllowed = folderApps.neverAllowedPackageNames;
  rules.setAlwaysAllowedPackages(alwaysAllowed);
  rules.setNeverAllowedPackages(neverAllowed);

  final timerState = FocusTimerBlockingState.from(timer);

  final packages = computeBlockedPackages(
    rules,
    timerState,
    alwaysAllowedPackages: alwaysAllowed,
    neverAllowedPackages: neverAllowed,
    emergencyPassActive: emergencyActive,
  );
  final temporaryUnblocks = computeTemporaryUnblockUntilByPackage(
    rules,
    timerState,
    emergencyPassActive: emergencyActive,
  );
  final domains = computeBlockedDomains(
    rules,
    timerState,
    emergencyPassActive: emergencyActive,
  );
  final temporaryDomainUnblocks = computeTemporaryUnblockUntilByDomain(
    rules,
    timerState,
    emergencyPassActive: emergencyActive,
  );
  final timeLimitRules = computeTimeLimitRulesForNative(
    rules,
    emergencyPassActive: emergencyActive,
  );
  final timeLimitRulesJson = jsonEncode(timeLimitRules);
  final sessionScheduleRules = computeSessionScheduleRulesForNative(
    rules,
    emergencyPassActive: emergencyActive,
  );
  final sessionScheduleRulesJson = jsonEncode(sessionScheduleRules);
  final adultWebsitesBlocked = emergencyActive ? false : folderApps.adultWebsitesBlocked;
  final distractingOverlayEnabled = autofocusSettings.overlayEnabled;
  final distractingPackages = computeDistractingPackagesForNative(
    folderApps,
    emergencyPassActive: emergencyActive,
  );

  final scheduleStateKey = rules.scheduleStateKey();
  final scheduleChanged = scheduleStateKey != listener._lastScheduleStateKey;
  if (scheduleChanged) {
    listener._lastScheduleStateKey = scheduleStateKey;
  }

  final timerStateKey =
      '${timer.isRunning}:${timer.blockedApps.map((a) => a.packageName).join('|')}';
  final timerChanged = timerStateKey != listener._lastTimerStateKey;
  if (timerChanged) {
    listener._lastTimerStateKey = timerStateKey;
  }

  return _SyncPayload(
    packages: packages,
    temporaryUnblocks: temporaryUnblocks,
    domains: domains,
    temporaryDomainUnblocks: temporaryDomainUnblocks,
    timeLimitRules: timeLimitRules,
    sessionScheduleRules: sessionScheduleRules,
    adultWebsitesBlocked: adultWebsitesBlocked,
    distractingPackages: distractingPackages,
    distractingOverlayEnabled: distractingOverlayEnabled,
    alwaysAllowed: alwaysAllowed,
    neverAllowed: neverAllowed,
    emergencyActive: emergencyActive,
    scheduleChanged: scheduleChanged,
    timerChanged: timerChanged,
    timeLimitRulesJson: timeLimitRulesJson,
    sessionScheduleRulesJson: sessionScheduleRulesJson,
  );
}

/// Call when the main shell mounts to force a native sync after startup.
void syncBlockingPackages(BuildContext context) {
  final permissions = context.read<PermissionsProvider>();
  final rules = context.read<RulesProvider>();
  final timer = context.read<TimerProvider>();
  final folderApps = context.read<FolderAppsProvider>();
  final emergencyPass = context.read<EmergencyPassProvider>();
  final autofocusSettings = context.read<AutofocusSettingsProvider>();

  if (!permissions.initialized ||
      rules.isLoading ||
      folderApps.isLoading ||
      !emergencyPass.initialized ||
      !autofocusSettings.initialized) {
    return;
  }

  final payload = _computeSyncPayloadFromContext(
    permissions: permissions,
    rules: rules,
    timer: timer,
    folderApps: folderApps,
    emergencyPass: emergencyPass,
    autofocusSettings: autofocusSettings,
  );

  AppBlockingService().syncBlockedPackages(
    payload.packages,
    temporaryUnblockUntilByPackage: payload.temporaryUnblocks,
    domains: payload.domains,
    temporaryUnblockUntilByDomain: payload.temporaryDomainUnblocks,
    timeLimitRules: payload.timeLimitRules,
    sessionScheduleRules: payload.sessionScheduleRules,
    adultWebsitesBlocked: payload.adultWebsitesBlocked,
    distractingPackages: payload.distractingPackages,
    distractingOverlayEnabled: payload.distractingOverlayEnabled,
    alwaysAllowedPackages: payload.alwaysAllowed,
    neverAllowedPackages: payload.neverAllowed,
    emergencyPassActive: payload.emergencyActive,
  );
}

_SyncPayload _computeSyncPayloadFromContext({
  required PermissionsProvider permissions,
  required RulesProvider rules,
  required TimerProvider timer,
  required FolderAppsProvider folderApps,
  required EmergencyPassProvider emergencyPass,
  required AutofocusSettingsProvider autofocusSettings,
}) {
  final emergencyActive = emergencyPass.isActive;
  final alwaysAllowed = folderApps.alwaysAllowedPackageNames;
  final neverAllowed = folderApps.neverAllowedPackageNames;
  rules.setAlwaysAllowedPackages(alwaysAllowed);
  rules.setNeverAllowedPackages(neverAllowed);

  final timerState = FocusTimerBlockingState.from(timer);

  final packages = computeBlockedPackages(
    rules,
    timerState,
    alwaysAllowedPackages: alwaysAllowed,
    neverAllowedPackages: neverAllowed,
    emergencyPassActive: emergencyActive,
  );
  final temporaryUnblocks = computeTemporaryUnblockUntilByPackage(
    rules,
    timerState,
    emergencyPassActive: emergencyActive,
  );
  final domains = computeBlockedDomains(
    rules,
    timerState,
    emergencyPassActive: emergencyActive,
  );
  final temporaryDomainUnblocks = computeTemporaryUnblockUntilByDomain(
    rules,
    timerState,
    emergencyPassActive: emergencyActive,
  );
  final timeLimitRules = computeTimeLimitRulesForNative(
    rules,
    emergencyPassActive: emergencyActive,
  );
  final timeLimitRulesJson = jsonEncode(timeLimitRules);
  final sessionScheduleRules = computeSessionScheduleRulesForNative(
    rules,
    emergencyPassActive: emergencyActive,
  );
  final sessionScheduleRulesJson = jsonEncode(sessionScheduleRules);
  final adultWebsitesBlocked = emergencyActive ? false : folderApps.adultWebsitesBlocked;
  final distractingOverlayEnabled = autofocusSettings.overlayEnabled;
  final distractingPackages = computeDistractingPackagesForNative(
    folderApps,
    emergencyPassActive: emergencyActive,
  );

  return _SyncPayload(
    packages: packages,
    temporaryUnblocks: temporaryUnblocks,
    domains: domains,
    temporaryDomainUnblocks: temporaryDomainUnblocks,
    timeLimitRules: timeLimitRules,
    sessionScheduleRules: sessionScheduleRules,
    adultWebsitesBlocked: adultWebsitesBlocked,
    distractingPackages: distractingPackages,
    distractingOverlayEnabled: distractingOverlayEnabled,
    alwaysAllowed: alwaysAllowed,
    neverAllowed: neverAllowed,
    emergencyActive: emergencyActive,
    scheduleChanged: false,
    timerChanged: false,
    timeLimitRulesJson: timeLimitRulesJson,
    sessionScheduleRulesJson: sessionScheduleRulesJson,
  );
}
