import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/user_data.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../widgets/shared/circle_icon_button.dart';

const occupationOptions = [
  'Student',
  'Professional',
  'Freelancer',
  'Homemaker',
  'Retired',
  'Other',
];

class OccupationEditScreen extends StatelessWidget {
  const OccupationEditScreen({super.key});

  Future<void> _select(BuildContext context, String value) async {
    HapticFeedback.selectionClick();
    await context.read<UserData>().setOccupation(value);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final selected = context.watch<UserData>().occupation;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: Row(
                children: [
                  CircleIconButton(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Occupation',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.headingMedium.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Responsive.centeredContent(
                context: context,
                child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                itemCount: occupationOptions.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  thickness: 1,
                  color: AppTheme.cardBorder.withValues(alpha: 0.45),
                ),
                itemBuilder: (context, index) {
                  final option = occupationOptions[index];
                  final isSelected = option == selected;

                  return InkWell(
                    onTap: () => _select(context, option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              option,
                              style: AppTheme.bodyLarge.copyWith(
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          _RadioIndicator(isSelected: isSelected),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadioIndicator extends StatelessWidget {
  final bool isSelected;

  const _RadioIndicator({required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? AppTheme.textPrimary : AppTheme.textHint,
          width: 2,
        ),
      ),
      child: isSelected
          ? Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.textPrimary,
                ),
              ),
            )
          : null,
    );
  }
}
