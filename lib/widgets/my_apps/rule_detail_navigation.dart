import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_rule.dart';
import '../../providers/emergency_pass_provider.dart';
import '../../providers/rules_provider.dart';
import '../../screens/unblock_duration_screen.dart';
import '../../screens/waiting_screen.dart';
import 'open_limit_rule_detail_sheet.dart';
import 'open_limit_rule_edit_sheet.dart';
import 'rule_detail_sheet.dart';
import 'rule_edit_sheet.dart';
import 'time_limit_rule_detail_sheet.dart';
import 'time_limit_rule_edit_sheet.dart';

/// Opens the correct rule detail sheet and handles follow-up actions.
class RuleDetailNavigation {
  RuleDetailNavigation._();

  static Future<void> openRuleDetail(
    BuildContext context,
    AppRule rule,
  ) async {
    if (rule is SessionRule) {
      await _openSessionRuleDetail(context, rule);
    } else if (rule is OpenLimitRule) {
      await _openOpenLimitRuleDetail(context, rule);
    } else if (rule is TimeLimitRule) {
      await _openTimeLimitRuleDetail(context, rule);
    }
  }

  static Future<void> _openSessionRuleDetail(
    BuildContext context,
    SessionRule rule,
  ) async {
    final action = await showRuleDetailSheet(context, rule);
    if (!context.mounted) return;
    final provider = context.read<RulesProvider>();

    switch (action) {
      case RuleDetailAction.toggleRequested:
        if (context.read<EmergencyPassProvider>().manualUnblocksDisabled) {
          return;
        }
        final minutes = await showUnblockFlow(
          context,
          targetName: 'distractions',
        );
        if (minutes == null || !context.mounted) return;
        await provider.unblockRule(
          rule.id,
          Duration(minutes: minutes),
        );
        break;
      case RuleDetailAction.editRequested: {
        final idx = provider.sessions.indexWhere((r) => r.id == rule.id);
        final latest = idx >= 0 ? provider.sessions[idx] : rule;
        await _openEditRuleSheet(context, latest);
        break;
      }
      case RuleDetailAction.disableRequested:
        await _openDisableRuleSheet(context, rule);
        break;
      case RuleDetailAction.reenableRequested:
        await provider.enableRule(rule.id);
        break;
      case RuleDetailAction.cancelled:
        break;
    }
  }

  static Future<void> _openOpenLimitRuleDetail(
    BuildContext context,
    OpenLimitRule rule,
  ) async {
    final action = await showOpenLimitRuleDetailSheet(context, rule);
    if (!context.mounted) return;
    final provider = context.read<RulesProvider>();

    switch (action) {
      case OpenLimitDetailAction.toggleRequested: {
        if (context.read<EmergencyPassProvider>().manualUnblocksDisabled) {
          return;
        }
        final idx = provider.openLimits.indexWhere((r) => r.id == rule.id);
        final latest = idx >= 0 ? provider.openLimits[idx] : rule;
        final minutes = await showUnblockFlow(
          context,
          targetName: 'distractions',
          fixedMinutes: latest.sessionLengthMinutes,
        );
        if (minutes == null || !context.mounted) return;
        await provider.unblockRule(
          latest.id,
          Duration(minutes: minutes),
        );
        break;
      }
      case OpenLimitDetailAction.editRequested: {
        final idx = provider.openLimits.indexWhere((r) => r.id == rule.id);
        final latest = idx >= 0 ? provider.openLimits[idx] : rule;
        await _openEditOpenLimitRuleSheet(context, latest);
        break;
      }
      case OpenLimitDetailAction.disableRequested:
        await _openDisableOpenLimitRuleSheet(context, rule);
        break;
      case OpenLimitDetailAction.reenableRequested:
        await provider.enableRule(rule.id);
        break;
      case OpenLimitDetailAction.cancelled:
        break;
    }
  }

  static Future<void> _openTimeLimitRuleDetail(
    BuildContext context,
    TimeLimitRule rule,
  ) async {
    final action = await showTimeLimitRuleDetailSheet(context, rule);
    if (!context.mounted) return;
    final provider = context.read<RulesProvider>();

    switch (action) {
      case TimeLimitDetailAction.toggleRequested:
        if (context.read<EmergencyPassProvider>().manualUnblocksDisabled) {
          return;
        }
        final minutes = await showUnblockFlow(
          context,
          targetName: 'distractions',
        );
        if (minutes == null || !context.mounted) return;
        await provider.unblockRule(
          rule.id,
          Duration(minutes: minutes),
        );
        break;
      case TimeLimitDetailAction.editRequested: {
        final idx = provider.timeLimits.indexWhere((r) => r.id == rule.id);
        final latest = idx >= 0 ? provider.timeLimits[idx] : rule;
        await _openEditTimeLimitRuleSheet(context, latest);
        break;
      }
      case TimeLimitDetailAction.disableRequested:
        await _openDisableTimeLimitRuleSheet(context, rule);
        break;
      case TimeLimitDetailAction.reenableRequested:
        await provider.enableRule(rule.id);
        break;
      case TimeLimitDetailAction.cancelled:
        break;
    }
  }

  static Future<void> _openDisableOpenLimitRuleSheet(
    BuildContext context,
    OpenLimitRule rule,
  ) async {
    final outcome = await showDisableOpenLimitRuleSheet(context, rule);
    if (!context.mounted) return;
    final provider = context.read<RulesProvider>();
    switch (outcome.result) {
      case RuleEditResult.disabled:
        await provider.disableRule(
          outcome.ruleId,
          preset: outcome.disableDuration,
        );
        break;
      case RuleEditResult.removed:
        await provider.deleteRule(outcome.ruleId);
        break;
      case RuleEditResult.saved:
      case RuleEditResult.cancelled:
        break;
    }
  }

  static Future<void> _openEditOpenLimitRuleSheet(
    BuildContext context,
    OpenLimitRule rule,
  ) async {
    if (rule.isRuleActive()) {
      final result = await showWaitingScreen(context);
      if (result != WaitingResult.completed) return;
      if (!context.mounted) return;
    }
    final outcome = await showEditOpenLimitRuleSheet(context, rule);
    if (!context.mounted) return;
    final provider = context.read<RulesProvider>();
    switch (outcome.result) {
      case RuleEditResult.saved:
        if (outcome.rule != null) {
          await provider.updateRule(outcome.rule!);
        }
        break;
      case RuleEditResult.disabled:
        await provider.disableRule(
          outcome.ruleId,
          preset: outcome.disableDuration,
        );
        break;
      case RuleEditResult.removed:
        await provider.deleteRule(outcome.ruleId);
        break;
      case RuleEditResult.cancelled:
        break;
    }
  }

  static Future<void> _openDisableTimeLimitRuleSheet(
    BuildContext context,
    TimeLimitRule rule,
  ) async {
    final outcome = await showDisableTimeLimitRuleSheet(context, rule);
    if (!context.mounted) return;
    final provider = context.read<RulesProvider>();
    switch (outcome.result) {
      case RuleEditResult.disabled:
        await provider.disableRule(
          outcome.ruleId,
          preset: outcome.disableDuration,
        );
        break;
      case RuleEditResult.removed:
        await provider.deleteRule(outcome.ruleId);
        break;
      case RuleEditResult.saved:
      case RuleEditResult.cancelled:
        break;
    }
  }

  static Future<void> _openEditTimeLimitRuleSheet(
    BuildContext context,
    TimeLimitRule rule,
  ) async {
    if (rule.isRuleActive()) {
      final blocked = rule.apps.any((a) {
        final usage = context.read<RulesProvider>().effectiveTimeLimitUsage(
              rule,
              a.packageName,
            );
        return rule.isPackageBlocked(a.packageName, usage);
      });
      if (blocked) {
        final result = await showWaitingScreen(context);
        if (result != WaitingResult.completed) return;
        if (!context.mounted) return;
      }
    }
    final outcome = await showEditTimeLimitRuleSheet(context, rule);
    if (!context.mounted) return;
    final provider = context.read<RulesProvider>();
    switch (outcome.result) {
      case RuleEditResult.saved:
        if (outcome.rule != null) {
          await provider.updateRule(outcome.rule!);
        }
        break;
      case RuleEditResult.disabled:
        await provider.disableRule(
          outcome.ruleId,
          preset: outcome.disableDuration,
        );
        break;
      case RuleEditResult.removed:
        await provider.deleteRule(outcome.ruleId);
        break;
      case RuleEditResult.cancelled:
        break;
    }
  }

  static Future<void> _openDisableRuleSheet(
    BuildContext context,
    SessionRule rule,
  ) async {
    final outcome = await showDisableRuleSheet(context, rule);
    if (!context.mounted) return;
    final provider = context.read<RulesProvider>();
    switch (outcome.result) {
      case RuleEditResult.disabled:
        await provider.disableRule(
          outcome.ruleId,
          preset: outcome.disableDuration,
        );
        break;
      case RuleEditResult.removed:
        await provider.deleteRule(outcome.ruleId);
        break;
      case RuleEditResult.saved:
      case RuleEditResult.cancelled:
        break;
    }
  }

  static Future<void> _openEditRuleSheet(
    BuildContext context,
    SessionRule rule,
  ) async {
    if (rule.isScheduleActive()) {
      final result = await showWaitingScreen(context);
      if (result != WaitingResult.completed) return;
      if (!context.mounted) return;
    }
    final outcome = await showEditRuleSheet(context, rule);
    if (!context.mounted) return;
    final provider = context.read<RulesProvider>();
    switch (outcome.result) {
      case RuleEditResult.saved:
        if (outcome.rule != null) {
          await provider.updateRule(outcome.rule!);
        }
        break;
      case RuleEditResult.disabled:
        await provider.disableRule(
          outcome.ruleId,
          preset: outcome.disableDuration,
        );
        break;
      case RuleEditResult.removed:
        await provider.deleteRule(outcome.ruleId);
        break;
      case RuleEditResult.cancelled:
        break;
    }
  }
}
