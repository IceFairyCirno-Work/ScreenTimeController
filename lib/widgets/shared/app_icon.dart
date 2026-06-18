import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class AppIcon extends StatelessWidget {
  final Uint8List? iconBytes;
  final double size;
  final double? borderRadius;
  final Color fallbackIconColor;
  final double? fallbackIconSize;

  const AppIcon({
    super.key,
    this.iconBytes,
    required this.size,
    this.borderRadius,
    this.fallbackIconColor = AppTheme.screenTimerControllerMint,
    this.fallbackIconSize,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? size * 0.22;
    final iconSize = fallbackIconSize ?? size * 0.55;

    if (iconBytes != null && iconBytes!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.memory(
          iconBytes!,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(
        Icons.apps,
        color: fallbackIconColor,
        size: iconSize,
      ),
    );
  }
}
