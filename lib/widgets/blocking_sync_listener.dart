import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

class _BlockingSyncListenerState extends State<BlockingSyncListener> {
  static const _pollInterval = Duration(seconds: 1);

  final AppBlockingService _blockingService = AppBlockingService();
  Set<String>? _lastSynced;
  Set<String>? _lastSyncedDistracting;
  Map<String, int>? _lastSyncedUnblocks;
  Set<String>? _lastSyncedDomains;
  Map<String, int>? _lastSyncedDomainUnblocks;
  String? _lastSyncedTimeLimitRulesJson;
  bool? _lastAdultWebsitesBlocked;
  Timer? _pollTimer;

  RulesProvider? _rules;
  TimerProvider? _timer;
  PermissionsProvider? _permissions;
  FolderAppsProvider? _folderApps;

  EmergencyPassProvider? _emergencyPass;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _attachListeners());
    _pollTimer = Timer.periodic(_pollInterval, (_) => _scheduleSync());
  }

  void _attachListeners() {
    if (!mounted || _rules != null) return;

    _rules = context.read<RulesProvider>()..addListener(_scheduleSync);
    _timer = context.read<TimerProvider>()..addListener(_scheduleSync);
    _permissions = context.read<PermissionsProvider>()..addListener(_scheduleSync);
    _folderApps = context.read<FolderAppsProvider>()..addListener(_onFolderAppsChanged);
    _emergencyPass = context.read<EmergencyPassProvider>()..addListener(_scheduleSync);

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

  void _scheduleSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncIfNeeded());
  }

  void _syncIfNeeded() {
    if (!mounted) return;

    final permissions = context.read<PermissionsProvider>();
    final rules = context.read<RulesProvider>();
    final timer = context.read<TimerProvider>();
    final folderApps = context.read<FolderAppsProvider>();
    final emergencyPass = context.read<EmergencyPassProvider>();
    final emergencyActive = emergencyPass.isActive;

    if (!permissions.initialized ||
        rules.isLoading ||
        folderApps.isLoading ||
        !emergencyPass.initialized) {
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
    final adultWebsitesBlocked =
        emergencyActive ? false : folderApps.adultWebsitesBlocked;
    final distractingPackages = computeDistractingPackagesForNative(
      folderApps,
      emergencyPassActive: emergencyActive,
    );

    if (setEquals(_lastSynced, packages) &&
        setEquals(_lastSyncedDistracting, distractingPackages) &&
        mapEquals(_lastSyncedUnblocks, temporaryUnblocks) &&
        setEquals(_lastSyncedDomains, domains) &&
        mapEquals(_lastSyncedDomainUnblocks, temporaryDomainUnblocks) &&
        _lastSyncedTimeLimitRulesJson == timeLimitRulesJson &&
        _lastAdultWebsitesBlocked == adultWebsitesBlocked) {
      return;
    }

    _lastSynced = Set<String>.from(packages);
    _lastSyncedDistracting = Set<String>.from(distractingPackages);
    _lastSyncedUnblocks = Map<String, int>.from(temporaryUnblocks);
    _lastSyncedDomains = Set<String>.from(domains);
    _lastSyncedDomainUnblocks = Map<String, int>.from(temporaryDomainUnblocks);
    _lastSyncedTimeLimitRulesJson = timeLimitRulesJson;
    _lastAdultWebsitesBlocked = adultWebsitesBlocked;
    _blockingService.syncBlockedPackages(
      packages,
      temporaryUnblockUntilByPackage: temporaryUnblocks,
      domains: domains,
      temporaryUnblockUntilByDomain: temporaryDomainUnblocks,
      timeLimitRules: timeLimitRules,
      adultWebsitesBlocked: adultWebsitesBlocked,
      distractingPackages: distractingPackages,
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _rules?.removeListener(_scheduleSync);
    _timer?.removeListener(_scheduleSync);
    _permissions?.removeListener(_scheduleSync);
    _folderApps?.removeListener(_onFolderAppsChanged);
    _emergencyPass?.removeListener(_scheduleSync);
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
  final emergencyActive = emergencyPass.isActive;

  if (!permissions.initialized ||
      rules.isLoading ||
      folderApps.isLoading ||
      !emergencyPass.initialized) {
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
    adultWebsitesBlocked:
        emergencyActive ? false : folderApps.adultWebsitesBlocked,
    distractingPackages: distractingPackages,
  );
}
