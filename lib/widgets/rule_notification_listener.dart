import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/permissions_provider.dart';
import '../providers/rules_provider.dart';
import '../services/rule_notification_service.dart';
import '../utils/rule_notification_schedule.dart';

/// Keeps rule notification schedules in sync with app state.
class RuleNotificationListener extends StatefulWidget {
  const RuleNotificationListener({super.key, required this.child});

  final Widget child;

  @override
  State<RuleNotificationListener> createState() =>
      _RuleNotificationListenerState();
}

class _RuleNotificationListenerState extends State<RuleNotificationListener>
    with WidgetsBindingObserver {
  static const _resyncInterval = Duration(minutes: 5);

  RulesProvider? _rules;
  PermissionsProvider? _permissions;
  Timer? _resyncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _attach());
    _resyncTimer = Timer.periodic(_resyncInterval, (_) => _syncSchedules());
  }

  void _attach() {
    if (!mounted || _rules != null) return;
    _rules = context.read<RulesProvider>()..addListener(_syncSchedules);
    _permissions = context.read<PermissionsProvider>()
      ..addListener(_syncSchedules);
    _syncSchedules();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncSchedules();
    }
  }

  void _syncSchedules() {
    if (!mounted) return;

    final permissions = context.read<PermissionsProvider>();
    final rules = context.read<RulesProvider>();
    final service = RuleNotificationService.instance;

    final enabled = permissions.notificationsOn;
    service.setEnabled(enabled);

    if (!enabled || rules.isLoading) {
      if (!enabled) {
        service.cancelAll();
      }
      return;
    }

    final now = DateTime.now();
    final sessions = rules.sessions.where((rule) {
      return RuleNotificationSchedule.isEligible(rule, now);
    });

    service.syncRuleSchedules(sessions);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resyncTimer?.cancel();
    _rules?.removeListener(_syncSchedules);
    _permissions?.removeListener(_syncSchedules);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
