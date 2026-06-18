import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_folder.dart';
import '../../models/app_rule.dart';
import '../../providers/rules_provider.dart';
import '../../screens/home/app_folder_detail_screen.dart';
import '../../services/device_auth_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/platform_capabilities.dart';
import '../../widgets/my_apps/add_rule_sheet.dart';
import '../../widgets/my_apps/app_folders_row.dart';
import '../../widgets/my_apps/blocked_apps_row.dart';
import '../../widgets/my_apps/blocked_websites_row.dart';
import '../../widgets/my_apps/rule_detail_navigation.dart';
import '../../widgets/my_apps/rules_carousel.dart';
import '../../widgets/my_apps/rules_grid_view.dart';

class MyAppsScreen extends StatefulWidget {
  const MyAppsScreen({super.key});

  @override
  State<MyAppsScreen> createState() => _MyAppsScreenState();
}

class _MyAppsScreenState extends State<MyAppsScreen> {
  bool _showRulesGrid = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RulesProvider>().loadRules();
    });
  }

  Future<void> _openAddRuleSheet() async {
    final rule = await showAddRuleSheet(context);
    if (rule != null && mounted) {
      await context.read<RulesProvider>().addRule(rule);
    }
  }

  Future<void> _openRuleDetail(AppRule rule) =>
      RuleDetailNavigation.openRuleDetail(context, rule);

  Future<void> _openFolderDetail(AppFolderType type) async {
    if (type == AppFolderType.neverAllowed) {
      final authenticated = await DeviceAuthService.instance.authenticate(
        reason: 'Unlock your device to view Never allowed apps',
      );
      if (!authenticated || !mounted) return;
    }

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => AppFolderDetailScreen(
          folderType: type,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showRulesGrid) {
      return RulesGridView(
        onBack: () => setState(() => _showRulesGrid = false),
        onRuleTap: _openRuleDetail,
      );
    }

    return ColoredBox(
      color: AppTheme.background,
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 140),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PageHeader(),
              if (PlatformCapabilities.isIOS &&
                  !PlatformCapabilities.supportsNativeEnforcement) ...[
                const SizedBox(height: 16),
                const _IosEnforcementBanner(),
              ],
              const SizedBox(height: 28),
              const BlockedAppsRow(),
              const SizedBox(height: 32),
              const BlockedWebsitesRow(),
              RulesCarousel(
                onSeeAllTap: () => setState(() => _showRulesGrid = true),
                onAddTap: _openAddRuleSheet,
                onRuleTap: _openRuleDetail,
              ),
              const SizedBox(height: 32),
              AppFoldersRow(
                onFolderTap: _openFolderDetail,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Text(
        'Apps',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
          decoration: TextDecoration.none,
          height: 1.2,
        ),
      ),
    );
  }
}

class _IosEnforcementBanner extends StatelessWidget {
  const _IosEnforcementBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.screenTimerControllerPillBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.surfaceLight.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 20,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Rules are saved locally. Native app blocking requires '
                'Screen Time API — coming after Apple approval.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                  height: 1.45,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
