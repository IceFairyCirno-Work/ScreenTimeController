import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/emergency_pass_provider.dart';
import '../../theme/app_theme.dart';

enum EmergencyPassTicketState { ready, active, cooldown }

class EmergencyPassTicket extends StatelessWidget {
  final EmergencyPassTicketState state;
  final Duration? activeRemaining;
  final Duration? cooldownRemaining;

  const EmergencyPassTicket({
    super.key,
    required this.state,
    this.activeRemaining,
    this.cooldownRemaining,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.clamp(0.0, 340.0);
        return SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTicketBody(),
              _buildTicketStub(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTicketBody() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3A2A10),
            Color(0xFF1F1608),
            Color(0xFF120E06),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFD4A853).withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4A853).withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'SILO',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 3.2,
              color: const Color(0xFFD4A853).withValues(alpha: 0.75),
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'EMERGENCY PASS',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppTheme.textPrimary,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '30 MIN',
            style: GoogleFonts.inter(
              fontSize: 44,
              fontWeight: FontWeight.w800,
              height: 1,
              color: const Color(0xFFE8C872),
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Full app access',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Bypasses all rules, focus blocks\nand hard limits immediately',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w400,
              color: AppTheme.textSecondary,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFD4A853).withValues(alpha: 0.18),
              ),
            ),
            child: Column(
              children: [
                Text(
                  _statusLabel,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: _statusColor,
                    decoration: TextDecoration.none,
                  ),
                ),
                if (_statusDetail != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _statusDetail!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '1 use every ${EmergencyPassProvider.cooldown.inDays} days',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textHint,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketStub() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.screenTimerControllerPillBg,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
        border: Border(
          left: BorderSide(
            color: const Color(0xFFD4A853).withValues(alpha: 0.35),
          ),
          right: BorderSide(
            color: const Color(0xFFD4A853).withValues(alpha: 0.35),
          ),
          bottom: BorderSide(
            color: const Color(0xFFD4A853).withValues(alpha: 0.35),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'PASS ID · ${_passId()}',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.6,
                color: AppTheme.textHint,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          Text(
            'NON-TRANSFERABLE',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: AppTheme.textHint,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }

  String get _statusLabel {
    return switch (state) {
      EmergencyPassTicketState.ready => 'READY TO REDEEM',
      EmergencyPassTicketState.active => 'PASS ACTIVE',
      EmergencyPassTicketState.cooldown => 'ON COOLDOWN',
    };
  }

  Color get _statusColor {
    return switch (state) {
      EmergencyPassTicketState.ready => const Color(0xFF7EEBC6),
      EmergencyPassTicketState.active => const Color(0xFFE8C872),
      EmergencyPassTicketState.cooldown => AppTheme.textHint,
    };
  }

  String? get _statusDetail {
    return switch (state) {
      EmergencyPassTicketState.ready =>
        'Break glass in case of emergency. All blocks lift for 30 minutes.',
      EmergencyPassTicketState.active =>
        'All blocks are currently lifted.',
      EmergencyPassTicketState.cooldown =>
        'Next pass available in ${_formatCooldown(cooldownRemaining ?? Duration.zero)}',
    };
  }

  String _passId() {
    final seed = DateTime.now().year * 100 + DateTime.now().month;
    return 'EP-${seed.toString().padLeft(4, '0')}';
  }

  String _formatCooldown(Duration duration) {
    final days = duration.inDays;
    if (days >= 1) {
      final hours = duration.inHours % 24;
      return hours > 0 ? '$days d $hours h' : '$days d';
    }
    final hours = duration.inHours;
    if (hours >= 1) {
      final minutes = duration.inMinutes % 60;
      return minutes > 0 ? '$hours h $minutes m' : '$hours h';
    }
    final minutes = duration.inMinutes;
    return minutes <= 1 ? '1 m' : '$minutes m';
  }
}
