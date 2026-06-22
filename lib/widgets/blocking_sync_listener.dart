import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  String? _lastScheduleStateKey;
  Timer? _pollTimer;

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
    _pollTimer = Timer.periodic(_pollInterval, (_) => _scheduleSync());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _lastScheduleStateKey = null;
      _scheduleSync(force: true);
    }
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
    if (!mounted) return;

    final permissions = context.read<PermissionsProvider>();
    final rules = context.read<RulesProvider>();
    final timer = context.read<TimerProvider>();
    final folderApps = context.read<FolderAppsProvider>();
    final emergencyPass = context.read<EmergencyPassProvider>();
    final autofocusSettings = context.read<AutofocusSettingsProvider>();
    final emergencyActive = emergencyPass.isActive;

    if (!permissions.initialized ||
        rules.isLoading ||
        folderApps.isLoading ||
        !emergencyPass.initialized ||
        !autofocusSettings.initialized) {
      return;
    }

    final alwaysAllowed = folderApps.alwaysAllowedPackageNames;
    final neverAllowed = folderApps.neverAllowedPackageNames;
    rules.setAlwaysAllowedPackages(alwaysAllowed);
    rules.setNeverAllowedPackages(neverAllowed);

    final packages = computeBlockedPackages(
      rules,
      timer,
      alwaysAllowedPackages: alwaysAllowed,
      neverAllowedPackages: neverAllowed,
      emergencyPassActive: emergencyActive,
    );
    final temporaryUnblocks = computeTemporaryUnblockUntilByPackage(rules);
    final domains = computeBlockedDomains(
      rules,
      emergencyPassActive: emergencyActive,
    );
    final temporaryDomainUnblocks = computeTemporaryUnblockUntilByDomain(rules);
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
    final adultWebsitesBlocked =
        emergencyActive ? false : folderApps.adultWebsitesBlocked;
    final distractingOverlayEnabled = autofocusSettings.overlayEnabled;
    final distractingPackages = computeDistractingPackagesForNative(
      folderApps,
      emergencyPassActive: emergencyActive,
    );

    final scheduleStateKey = rules.scheduleStateKey();
    final scheduleChanged = scheduleStateKey != _lastScheduleStateKey;
    if (scheduleChanged) {
      _lastScheduleStateKey = scheduleStateKey;
      force = true;
    }

    if (!force &&
        setEquals(_lastSynced, packages) &&
        setEquals(_lastSyncedDistracting, distractingPackages) &&
        mapEquals(_lastSyncedUnblocks, temporaryUnblocks) &&
        setEquals(_lastSyncedDomains, domains) &&
        mapEquals(_lastSyncedDomainUnblocks, temporaryDomainUnblocks) &&
        _lastSyncedTimeLimitRulesJson == timeLimitRulesJson &&
        _lastSyncedSessionRulesJson == sessionScheduleRulesJson &&
        _lastAdultWebsitesBlocked == adultWebsitesBlocked &&
        _lastDistractingOverlayEnabled == distractingOverlayEnabled) {
      return;
    }

    _lastSynced = Set<String>.from(packages);
    _lastSyncedDistracting = Set<String>.from(distractingPackages);
    _lastSyncedUnblocks = Map<String, int>.from(temporaryUnblocks);
    _lastSyncedDomains = Set<String>.from(domains);
    _lastSyncedDomainUnblocks = Map<String, int>.from(temporaryDomainUnblocks);
    _lastSyncedTimeLimitRulesJson = timeLimitRulesJson;
    _lastSyncedSessionRulesJson = sessionScheduleRulesJson;
    _lastAdultWebsitesBlocked = adultWebsitesBlocked;
    _lastDistractingOverlayEnabled = distractingOverlayEnabled;
    _blockingService.syncBlockedPackages(
      packages,
      temporaryUnblockUntilByPackage: temporaryUnblocks,
      domains: domains,
      temporaryUnblockUntilByDomain: temporaryDomainUnblocks,
      timeLimitRules: timeLimitRules,
      sessionScheduleRules: sessionScheduleRules,
      adultWebsitesBlocked: adultWebsitesBlocked,
      distractingPackages: distractingPackages,
      distractingOverlayEnabled: distractingOverlayEnabled,
    );
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

/// Call when the main shell mounts to force a native sync after startup.
void syncBlockingPackages(BuildContext context) {
  final permissions = context.read<PermissionsProvider>();
  final rules = context.read<RulesProvider>();
  final timer = context.read<TimerProvider>();
  final folderApps = context.read<FolderAppsProvider>();
  final emergencyPass = context.read<EmergencyPassProvider>();
  final autofocusSettings = context.read<AutofocusSettingsProvider>();
  final emergencyActive = emergencyPass.isActive;

  if (!permissions.initialized ||
      rules.isLoading ||
      folderApps.isLoading ||
      !emergencyPass.initialized ||
      !autofocusSettings.initialized) {
    return;
  }

  final alwaysAllowed = folderApps.alwaysAllowedPackageNames;
  final neverAllowed = folderApps.neverAllowedPackageNames;
  rules.setAlwaysAllowedPackages(alwaysAllowed);
  rules.setNeverAllowedPackages(neverAllowed);

  final packages = computeBlockedPackages(
    rules,
    timer,
    alwaysAllowedPackages: alwaysAllowed,
    neverAllowedPackages: neverAllowed,
    emergencyPassActive: emergencyActive,
  );
  final temporaryUnblocks = computeTemporaryUnblockUntilByPackage(rules);
  final domains = computeBlockedDomains(
    rules,
    emergencyPassActive: emergencyActive,
  );
  final temporaryDomainUnblocks = computeTemporaryUnblockUntilByDomain(rules);
  final timeLimitRules = computeTimeLimitRulesForNative(
    rules,
    emergencyPassActive: emergencyActive,
  );
  final sessionScheduleRules = computeSessionScheduleRulesForNative(
    rules,
    emergencyPassActive: emergencyActive,
  );
  final distractingPackages = computeDistractingPackagesForNative(
    folderApps,
    emergencyPassActive: emergencyActive,
  );
  AppBlockingService().syncBlockedPackages(
    packages,
    temporaryUnblockUntilByPackage: temporaryUnblocks,
    domains: domains,
    temporaryUnblockUntilByDomain: temporaryDomainUnblocks,
    timeLimitRules: timeLimitRules,
    sessionScheduleRules: sessionScheduleRules,
    adultWebsitesBlocked:
        emergencyActive ? false : folderApps.adultWebsitesBlocked,
    distractingPackages: distractingPackages,
    distractingOverlayEnabled: autofocusSettings.overlayEnabled,
  );
}
