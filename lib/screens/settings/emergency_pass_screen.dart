import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/emergency_pass_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/settings/emergency_pass_ticket.dart';
import '../../widgets/shared/circle_icon_button.dart';
import '../../widgets/shared/hold_to_confirm_button.dart';

class EmergencyPassScreen extends StatelessWidget {
  const EmergencyPassScreen({super.key});

  EmergencyPassTicketState _ticketState(EmergencyPassProvider pass) {
    if (pass.isActive) return EmergencyPassTicketState.active;
    if (pass.canRedeem) return EmergencyPassTicketState.ready;
    return EmergencyPassTicketState.cooldown;
  }

  Future<void> _redeem(BuildContext context) async {
    final pass = context.read<EmergencyPassProvider>();
    final redeemed = await pass.redeem();
    if (!context.mounted || !redeemed) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Emergency pass active for 30 minutes',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
          ),
          backgroundColor: AppTheme.screenTimerControllerCard,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final pass = context.watch<EmergencyPassProvider>();
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final ticketState = _ticketState(pass);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        bottom: false,
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
                      'Emergency pass',
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
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: EmergencyPassTicket(
                      state: ticketState,
                      activeRemaining: pass.activeRemaining,
                      cooldownRemaining: pass.cooldownRemaining,
                    ),
                  ),
                  const Spacer(flex: 2),
                  Padding(
                    padding: EdgeInsets.fromLTRB(24, 0, 24, 12 + bottomInset),
                    child: pass.canRedeem
                        ? HoldToConfirmButton(
                            label: 'Hold to redeem',
                            holdingLabel: 'Keep holding...',
                            onComplete: () => _redeem(context),
                          )
                        : _InactiveRedeemHint(
                            isActive: pass.isActive,
                            activeRemaining: pass.activeRemaining,
                            cooldownRemaining: pass.cooldownRemaining,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InactiveRedeemHint extends StatelessWidget {
  final bool isActive;
  final Duration? activeRemaining;
  final Duration? cooldownRemaining;

  const _InactiveRedeemHint({
    required this.isActive,
    this.activeRemaining,
    this.cooldownRemaining,
  });

  String _formatDuration(Duration duration) {
    return EmergencyPassProvider.formatDurationLabel(duration);
  }

  String _formatCooldown(Duration duration) {
    final days = duration.inDays;
    if (days >= 1) return '$days day${days == 1 ? '' : 's'}';
    final hours = duration.inHours;
    if (hours >= 1) return '$hours hour${hours == 1 ? '' : 's'}';
    final minutes = duration.inMinutes.clamp(1, 9999);
    return '$minutes minute${minutes == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    final text = isActive
        ? 'Pass active · ${_formatDuration(activeRemaining ?? Duration.zero)} left'
        : 'Available again in ${_formatCooldown(cooldownRemaining ?? Duration.zero)}';

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 58),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        color: AppTheme.screenTimerControllerPillBg,
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTheme.bodyMedium.copyWith(
          color: AppTheme.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
