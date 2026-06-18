import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF1C1C1E);
  static const Color surfaceLight = Color(0xFF2C2C2E);
  static const Color accent = Color(0xFFFFFFFF);
  static const Color accentInverse = Color(0xFF000000);
  static const Color cardBackground = Color(0xFF1C1C1E);
  static const Color cardBorder = Color(0xFF3A3A3C);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFAEAEB2);
  static const Color textHint = Color(0xFF636366);
  static const Color textOnAccent = Color(0xFF000000);
  static const Color highlightPurple = Color(0xFFB388FF);
  static const Color highlightBlue = Color(0xFF64B5F6);

  // ScreenTimerController shared tokens
  static const Color screenTimerControllerMint = Color(0xFF7EEBC6);
  static const Color screenTimerControllerMintDim = Color(0xFF4A9E82);
  static const Color screenTimerControllerMintGlow = Color(0xFF4ADE80);
  static const Color screenTimerControllerCard = Color(0xFF1A1A1A);
  static const Color screenTimerControllerPillBg = Color(0xFF141414);
  static const Color screenTimerControllerFlame = Color(0xFFFF8C42);

  // My Apps tab tokens
  static const Color screenTimerControllerRuleCardBg = Color(0xFF161616);
  static const Color screenTimerControllerGreenBadgeBg = Color(0xFF1A3A2A);
  static const Color screenTimerControllerNavCapsuleBg = Color(0xFF1A2E24);
  static const Color screenTimerControllerToggleInactive = Color(0xFF4A4A4A);
  static const Color screenTimerControllerDeepFocus = Color(0xFFFF6B6B);
  static const Color screenTimerControllerStrict = Color(0xFFFFB347);

  static const LinearGradient purpleBlueGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [highlightPurple, highlightBlue],
  );

  static TextStyle get headingLarge => GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        height: 1.3,
        decoration: TextDecoration.none,
      );

  static TextStyle get headingMedium => GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        height: 1.3,
        decoration: TextDecoration.none,
      );

  /// Section headers (e.g. "For you", "Rules", "Blocked apps").
  static TextStyle get sectionTitle => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        decoration: TextDecoration.none,
      );

  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textPrimary,
        height: 1.5,
        decoration: TextDecoration.none,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textSecondary,
        height: 1.5,
        decoration: TextDecoration.none,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: textHint,
        height: 1.5,
        decoration: TextDecoration.none,
      );

  static TextStyle get buttonText => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textOnAccent,
        decoration: TextDecoration.none,
      );

  static TextStyle get statNumber => GoogleFonts.inter(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        decoration: TextDecoration.none,
      );

  static TextStyle get statLabel => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: textSecondary,
        decoration: TextDecoration.none,
      );

  static TextStyle get screenTimerControllerScore => GoogleFonts.inter(
        fontSize: 52,
        fontWeight: FontWeight.w700,
        color: screenTimerControllerMint,
        decoration: TextDecoration.none,
        height: 1.0,
      );

  static TextStyle get screenTimerControllerScoreLabel => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: screenTimerControllerMint,
        letterSpacing: 0.5,
        decoration: TextDecoration.none,
      );

  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          primary: accent,
          secondary: textSecondary,
          surface: surface,
        ),
        textTheme: TextTheme(
          bodyLarge: bodyLarge,
          bodyMedium: bodyMedium,
          bodySmall: bodySmall,
          titleLarge: headingLarge,
          titleMedium: headingMedium,
        ),
        pageTransitionsTheme: PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      );
}
