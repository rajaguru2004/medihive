import 'package:flutter/material.dart';

/// MediHive Color Palette
/// Inspired by Apple's glass-effect UI + hospital management aesthetics.
/// Uses cool teal-blues (trust, health) + warm neutrals + vibrant accents.
abstract class AppColors {
  // ─── Brand / Primary ──────────────────────────────────────────────────────
  /// Primary teal-blue — clinical trust
  static const Color primary = Color(0xFF0A84FF); // Apple blue
  static const Color primaryLight = Color(0xFF409CFF);
  static const Color primaryDark = Color(0xFF0066CC);

  // ─── Secondary / Accent ──────────────────────────────────────────────────
  /// Mint-green accent — health & vitality
  static const Color secondary = Color(0xFF30D158); // Apple green
  static const Color secondaryLight = Color(0xFF5EE082);
  static const Color secondaryDark = Color(0xFF1FAB43);

  // ─── Tertiary ─────────────────────────────────────────────────────────────
  /// Soft lavender — calm, supportive actions
  static const Color tertiary = Color(0xFFBF5AF2); // Apple purple
  static const Color tertiaryLight = Color(0xFFD07DF5);
  static const Color tertiaryDark = Color(0xFF9B3DD6);

  // ─── Semantic ─────────────────────────────────────────────────────────────
  static const Color error = Color(0xFFFF453A); // Apple red
  static const Color warning = Color(0xFFFF9F0A); // Apple orange
  static const Color success = Color(0xFF30D158);
  static const Color info = Color(0xFF64D2FF); // Apple cyan

  // ─── Light Surface ────────────────────────────────────────────────────────
  static const Color lightBackground =
      Color(0xFFF2F2F7); // iOS system grouped bg
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFE5E5EA);
  static const Color lightCard = Color(0xFFFFFFFF);

  /// Glass overlay for light mode (white @ 60% opacity)
  static const Color lightGlass = Color(0x99FFFFFF);
  static const Color lightGlassBorder = Color(0x33000000);

  // ─── Dark Surface ─────────────────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF000000); // Pure OLED
  static const Color darkSurface = Color(0xFF1C1C1E); // iOS system bg
  static const Color darkSurfaceVariant = Color(0xFF2C2C2E);
  static const Color darkCard = Color(0xFF1C1C1E);

  /// Glass overlay for dark mode (white @ 10% opacity)
  static const Color darkGlass = Color(0x1AFFFFFF);
  static const Color darkGlassBorder = Color(0x33FFFFFF);

  // ─── Text ─────────────────────────────────────────────────────────────────
  static const Color lightTextPrimary = Color(0xFF000000);
  static const Color lightTextSecondary =
      Color(0xFF3C3C43); // 60% opacity equiv
  static const Color lightTextTertiary = Color(0xFF8E8E93);
  static const Color lightTextDisabled = Color(0xFFC7C7CC);

  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFEBEBF5);
  static const Color darkTextTertiary = Color(0xFF8E8E93);
  static const Color darkTextDisabled = Color(0xFF48484A);

  // ─── Divider / Border ─────────────────────────────────────────────────────
  static const Color lightDivider = Color(0xFFC6C6C8);
  static const Color darkDivider = Color(0xFF38383A);

  // ─── Gradients ────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0A84FF), Color(0xFF30D158)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradientLight = LinearGradient(
    colors: [Color(0xCCFFFFFF), Color(0x80FFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradientDark = LinearGradient(
    colors: [Color(0x26FFFFFF), Color(0x0DFFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const RadialGradient heroGradient = RadialGradient(
    colors: [Color(0xFF0A84FF), Color(0xFF000000)],
    center: Alignment.topCenter,
    radius: 1.2,
  );
}
