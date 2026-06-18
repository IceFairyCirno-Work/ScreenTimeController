import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/gem_achievement.dart';
import '../../models/gem_unlock_info.dart';
import '../../theme/app_theme.dart';
import '../shared/app_bottom_sheet.dart';

class GemUnlockSheet extends StatelessWidget {
  final GemUnlockInfo info;
  final bool hasExistingHeroGem;

  const GemUnlockSheet({
    super.key,
    required this.info,
    required this.hasExistingHeroGem,
  });

  /// Returns `true` when the user chose to set this gem as their home hero.
  static Future<bool> show(
    BuildContext context, {
    required GemUnlockInfo info,
    required bool hasExistingHeroGem,
  }) async {
    final result = await showAppBottomSheet<bool>(
      context: context,
      isDismissible: true,
      backgroundColor: AppTheme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).padding.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.92 - bottomInset,
            child: GemUnlockSheet(
              info: info,
              hasExistingHeroGem: hasExistingHeroGem,
            ),
          ),
        );
      },
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return GemUnlockContent(
      info: info,
      hasExistingHeroGem: hasExistingHeroGem,
      showDragHandle: true,
      onComplete: (setAsCurrent) =>
          Navigator.of(context).pop(setAsCurrent),
    );
  }
}

class GemUnlockContent extends StatelessWidget {
  final GemUnlockInfo info;
  final bool hasExistingHeroGem;
  final bool showDragHandle;
  final bool confirmOnly;
  final void Function(bool setAsCurrent) onComplete;

  const GemUnlockContent({
    super.key,
    required this.info,
    required this.onComplete,
    this.hasExistingHeroGem = false,
    this.showDragHandle = false,
    this.confirmOnly = false,
  });

  void _share(BuildContext context) {
    Clipboard.setData(ClipboardData(text: info.shareMessage));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Share text copied',
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
        ),
        backgroundColor: AppTheme.screenTimerControllerCard,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Column(
      children: [
        if (showDragHandle) ...[
          const SizedBox(height: 10),
          const _DragHandle(),
          const SizedBox(height: 20),
        ] else
          const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            info.title,
            textAlign: TextAlign.center,
            style: AppTheme.headingLarge.copyWith(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(width: 44),
              Expanded(
                child: Text(
                  info.subtitle,
                  textAlign: TextAlign.center,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 15,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _share(context),
                icon: const Icon(
                  Icons.ios_share,
                  color: AppTheme.textPrimary,
                  size: 22,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 44,
                  minHeight: 44,
                ),
                tooltip: 'Share',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _RarityBadge(percent: info.rarityPercent),
        const SizedBox(height: 12),
        Expanded(
          child: _GemShowcase(
            assetPath: info.assetPath,
            zoom: info.id.showcaseZoom,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: AppTheme.textPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 12,
                      color: AppTheme.background,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      info.formattedUnlockDate,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                info.milestoneDescription,
                textAlign: TextAlign.center,
                style: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, 16 + bottomInset),
          child: _UnlockActions(
            confirmOnly: confirmOnly,
            keepLabel:
                hasExistingHeroGem ? 'Keep Current Gem' : 'Maybe Later',
            onSetAsCurrent: () => onComplete(true),
            onKeepCurrent: () => onComplete(false),
          ),
        ),
      ],
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 5,
      decoration: BoxDecoration(
        color: AppTheme.textHint.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

class _RarityBadge extends StatelessWidget {
  final int percent;

  const _RarityBadge({required this.percent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF3A2E14).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.emoji_events_outlined,
            size: 14,
            color: Color(0xFFD4AF37),
          ),
          const SizedBox(width: 6),
          Text(
            'Owned by $percent%',
            style: AppTheme.bodySmall.copyWith(
              color: const Color(0xFFD4AF37),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _GemShowcase extends StatelessWidget {
  static const _baseSize = 200.0;

  final String assetPath;
  final double zoom;

  const _GemShowcase({
    required this.assetPath,
    this.zoom = 1.2,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final baseSize = (constraints.maxHeight / zoom).clamp(96.0, _baseSize);
        final renderSize = baseSize * zoom;
        final glowSize = renderSize + 40;

        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: glowSize,
              height: glowSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.screenTimerControllerMintGlow
                        .withValues(alpha: 0.35),
                    blurRadius: 80,
                    spreadRadius: 20,
                  ),
                  BoxShadow(
                    color: AppTheme.screenTimerControllerMint
                        .withValues(alpha: 0.18),
                    blurRadius: 120,
                    spreadRadius: 30,
                  ),
                ],
              ),
            ),
            Image.asset(
              assetPath,
              width: renderSize,
              height: renderSize,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ],
        );
      },
    );
  }
}

class _UnlockActions extends StatelessWidget {
  final bool confirmOnly;
  final String keepLabel;
  final VoidCallback onSetAsCurrent;
  final VoidCallback onKeepCurrent;

  const _UnlockActions({
    required this.keepLabel,
    required this.onSetAsCurrent,
    required this.onKeepCurrent,
    this.confirmOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    if (confirmOnly) {
      return SizedBox(
        width: double.infinity,
        child: Material(
          color: AppTheme.surfaceLight.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(99),
          child: InkWell(
            onTap: onSetAsCurrent,
            borderRadius: BorderRadius.circular(99),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check,
                    size: 18,
                    color: AppTheme.textPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Confirm',
                    style: AppTheme.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: Material(
            color: AppTheme.surfaceLight.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(99),
            child: InkWell(
              onTap: onSetAsCurrent,
              borderRadius: BorderRadius.circular(99),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check,
                      size: 18,
                      color: AppTheme.textPrimary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Set as Current Gem',
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: onKeepCurrent,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              keepLabel,
              style: AppTheme.bodyLarge.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 15,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
