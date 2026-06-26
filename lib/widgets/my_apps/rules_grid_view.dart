import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/app_rule.dart';
import '../../providers/rules_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import 'rules_carousel.dart';
import 'add_rule_sheet.dart';

class RulesGridView extends StatelessWidget {
  final VoidCallback onBack;
  final void Function(AppRule rule)? onRuleTap;

  const RulesGridView({
    super.key,
    required this.onBack,
    this.onRuleTap,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onBack,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppTheme.surface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        size: 20,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Rules',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      decoration: TextDecoration.none,
                      height: 1.2,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () async {
                      final rule = await showAddRuleSheet(context);
                      if (rule != null && context.mounted) {
                        await context.read<RulesProvider>().addRule(rule);
                      }
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppTheme.surface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add,
                        size: 22,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Consumer<RulesProvider>(
                builder: (context, provider, _) {
                  final allRules = <AppRule>[
                    ...provider.sessions,
                    ...provider.timeLimits,
                    ...provider.openLimits,
                  ];
                  if (allRules.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.rule_folder_outlined,
                            size: 48,
                            color: AppTheme.textHint,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No rules yet',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              color: AppTheme.textHint,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return GridView(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: Responsive.gridCrossAxisCount(context),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      mainAxisExtent: Responsive.rulesCardHeight(context),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      Responsive.horizontalPadding(context),
                      0,
                      Responsive.horizontalPadding(context),
                      Responsive.scrollBottomPadding(context),
                    ),
                    children: allRules.map((rule) {
                      if (rule is SessionRule) {
                        return SessionRuleCard(
                          rule: rule,
                          expand: true,
                          onTap: onRuleTap != null
                              ? () => onRuleTap!(rule)
                              : null,
                        );
                      }
                      if (rule is TimeLimitRule) {
                        return TimeLimitRuleCard(
                          rule: rule,
                          expand: true,
                          onTap: onRuleTap != null
                              ? () => onRuleTap!(rule)
                              : null,
                        );
                      }
                      return OpenLimitRuleCard(
                        rule: rule as OpenLimitRule,
                        expand: true,
                        onTap: onRuleTap != null
                            ? () => onRuleTap!(rule)
                            : null,
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
