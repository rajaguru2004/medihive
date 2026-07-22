import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Glass decoration helpers — Apple visionOS / iOS 18 style.
abstract class AppDecorations {
  // ─── Border Radius Tokens ─────────────────────────────────────────────────
  static const double radiusXS = 6;
  static const double radiusSM = 10;
  static const double radiusMD = 14;
  static const double radiusLG = 20;
  static const double radiusXL = 28;
  static const double radiusFull = 999;

  static const BorderRadius borderXS =
      BorderRadius.all(Radius.circular(radiusXS));
  static const BorderRadius borderSM =
      BorderRadius.all(Radius.circular(radiusSM));
  static const BorderRadius borderMD =
      BorderRadius.all(Radius.circular(radiusMD));
  static const BorderRadius borderLG =
      BorderRadius.all(Radius.circular(radiusLG));
  static const BorderRadius borderXL =
      BorderRadius.all(Radius.circular(radiusXL));
  static const BorderRadius borderFull =
      BorderRadius.all(Radius.circular(radiusFull));

  // ─── Glass Card ───────────────────────────────────────────────────────────
  static BoxDecoration glassCard({
    required bool isDark,
    BorderRadius? borderRadius,
    double blurSigma = 20,
  }) =>
      BoxDecoration(
        gradient:
            isDark ? AppColors.glassGradientDark : AppColors.glassGradientLight,
        borderRadius: borderRadius ?? borderLG,
        border: Border.all(
          color:
              isDark ? AppColors.darkGlassBorder : AppColors.lightGlassBorder,
          width: 0.5,
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.8),
                  blurRadius: 0,
                  offset: const Offset(0, 1),
                  spreadRadius: -1,
                ),
              ],
      );

  /// Frosted pill decoration (chips, badges)
  static BoxDecoration glassPill({required bool isDark}) => BoxDecoration(
        color: isDark ? AppColors.darkGlass : AppColors.lightGlass,
        borderRadius: borderFull,
        border: Border.all(
          color:
              isDark ? AppColors.darkGlassBorder : AppColors.lightGlassBorder,
          width: 0.5,
        ),
      );

  // ─── Elevation Shadows ────────────────────────────────────────────────────
  static List<BoxShadow> elevation1(bool isDark) => [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.3)
              : Colors.black.withValues(alpha: 0.06),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> elevation2(bool isDark) => [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.4)
              : Colors.black.withValues(alpha: 0.1),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> elevation3(bool isDark) => [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.5)
              : Colors.black.withValues(alpha: 0.14),
          blurRadius: 32,
          offset: const Offset(0, 12),
        ),
      ];
}
