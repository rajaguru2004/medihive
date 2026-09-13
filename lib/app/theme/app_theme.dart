import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_fonts.dart';
import 'brand_palette.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — ThemeData definitions
///
/// One builder for both modes, fed the site's [BrandPalette] and the active
/// face in [AppFonts]. `ThemeService` calls it once at boot and again only
/// when the site's branding changes; nothing here runs per frame.
///
/// Light → cool paper ground, white surfaces, the true brand as primary.
/// Dark  → deep ink ground, raised slate surfaces, the brand as it reads there.
///
/// Component themes are set here and only here. A widget that reaches for
/// `style:` to restate what this file already says is a defect — it is how two
/// button heights end up on one screen.
/// ─────────────────────────────────────────────────────────────────────────────
abstract class AppTheme {
  // ── Shared radius / elevation constants ───────────────────────────────────
  static const double radiusSmall = 10.0;
  static const double radiusMedium = 16.0;
  static const double radiusLarge = 24.0;
  static const double radiusXL = 32.0;

  static const double elevationNone = 0.0;
  static const double elevationLow = 2.0;
  static const double elevationMedium = 6.0;
  static const double elevationHigh = 12.0;

  /// The minimum tap target on both platforms. Android's Material guidance is
  /// 48 dp, Apple's HIG is 44 pt; 48 satisfies both.
  static const double minTapTarget = 48.0;

  /// The default site brand, for code paths that run before settings exist.
  static ThemeData get light =>
      build(Brightness.light, brand: BrandPalette.clinicalTeal);

  static ThemeData get dark =>
      build(Brightness.dark, brand: BrandPalette.clinicalTeal);

  static ThemeData build(Brightness brightness, {required BrandPalette brand}) {
    final isDark = brightness == Brightness.dark;
    final base = isDark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);

    // Two different derivations of one brand: `fill` for shapes, `ink` for
    // words. For a mid-luminance brand like the default teal these are
    // genuinely different colours — see BrandPalette's class doc.
    final primary = brand.fill(brightness);
    final onPrimary = brand.onFill(brightness);
    // The hairline that gives a brand fill a discernible boundary without
    // changing the brand. See BrandPalette.fillEdge.
    final primaryEdge = brand.fillEdge(brightness);
    final ink = brand.ink(brightness);
    final tonal = brand.tonal(brightness);

    final ground =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final textTertiary =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
    final divider = isDark ? AppColors.darkDivider : AppColors.lightDivider;
    final glassBorder =
        isDark ? AppColors.darkGlassBorder : AppColors.lightGlassBorder;
    final cardSurface =
        isDark ? AppColors.darkCardSurface : AppColors.lightCardSurface;
    final shadow = isDark ? AppColors.darkShadow : AppColors.lightShadow;

    return base.copyWith(
      brightness: brightness,
      scaffoldBackgroundColor: ground,
      primaryColor: primary,
      textTheme: AppFonts.textTheme(base.textTheme).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),

      // ── ColorScheme ───────────────────────────────────────────────────────
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: tonal,
        onPrimaryContainer: ink,
        secondary: brand.accent,
        onSecondary: Colors.white,
        secondaryContainer: isDark
            ? const Color(0xFF0B3A5C)
            : const Color(0xFFD6EBFA),
        onSecondaryContainer:
            isDark ? const Color(0xFF9ED2F5) : AppColors.accentDark,
        tertiary: AppColors.acuityReview,
        onTertiary: Colors.white,
        surface: surface,
        onSurface: textPrimary,
        surfaceContainerHighest: cardSurface,
        onSurfaceVariant: textSecondary,
        outline: divider,
        outlineVariant: glassBorder,
        shadow: shadow,
        scrim: isDark ? const Color(0x99000000) : const Color(0x40000000),
        error: AppColors.error,
        onError: Colors.white,
      ),

      // ── AppBar ────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: ground,
        foregroundColor: textPrimary,
        elevation: elevationNone,
        scrolledUnderElevation: elevationNone,
        shadowColor: shadow,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppFonts.text(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.2,
        ),
        centerTitle: true,
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),

      // ── Card ──────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: surface,
        shadowColor: shadow,
        elevation: elevationNone,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: BorderSide(color: divider, width: 0.5),
        ),
      ),

      // ── Buttons ───────────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          side: BorderSide(color: primaryEdge, width: 1),
          disabledBackgroundColor: primary.withValues(alpha: 0.35),
          disabledForegroundColor: onPrimary.withValues(alpha: 0.6),
          elevation: elevationNone,
          shadowColor: Colors.transparent,
          minimumSize: const Size(0, minTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: AppFonts.text(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          side: BorderSide(color: primaryEdge, width: 1),
          disabledBackgroundColor: primary.withValues(alpha: 0.35),
          disabledForegroundColor: onPrimary.withValues(alpha: 0.6),
          elevation: elevationNone,
          minimumSize: const Size(0, minTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: AppFonts.text(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: BorderSide(color: ink.withValues(alpha: 0.5), width: 1.5),
          minimumSize: const Size(0, minTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: AppFonts.text(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(0, minTapTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
          textStyle: AppFonts.text(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      // ── InputDecoration ───────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFFEBEFF0),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: divider, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: divider, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: ink, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        hintStyle: AppFonts.text(fontSize: 16, color: textTertiary),
        labelStyle: AppFonts.text(fontSize: 14, color: textSecondary),
        errorStyle: AppFonts.text(fontSize: 12, color: AppColors.error),
      ),

      // ── Navigation ────────────────────────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: ink,
        unselectedItemColor: textTertiary,
        elevation: elevationNone,
        type: BottomNavigationBarType.fixed,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: tonal,
        surfaceTintColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: ink, size: 24);
          }
          return IconThemeData(color: textTertiary, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppFonts.text(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: ink,
            );
          }
          return AppFonts.text(fontSize: 12, color: textTertiary);
        }),
      ),

      // ── Chip ──────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFEBEFF0),
        selectedColor: tonal,
        side: BorderSide(color: divider, width: 0.5),
        labelStyle: AppFonts.text(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
      ),

      // ── Surfaces that float ───────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: elevationHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXL),
        ),
        titleTextStyle: AppFonts.text(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        contentTextStyle: AppFonts.text(fontSize: 15, color: textSecondary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: elevationNone,
        showDragHandle: true,
        dragHandleColor: textTertiary.withValues(alpha: 0.4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXL)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.darkCardSurface : const Color(0xFF2A241A),
        contentTextStyle: AppFonts.text(fontSize: 14, color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
      ),

      // ── Misc ──────────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: divider,
        thickness: 0.5,
        space: 0.5,
      ),
      iconTheme: IconThemeData(color: textSecondary, size: 22),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: ink,
        linearTrackColor: divider,
        circularTrackColor: Colors.transparent,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? onPrimary : Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? primary
                : (isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : const Color(0xFFDDD7CC))),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: textSecondary,
        titleTextStyle: AppFonts.text(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        subtitleTextStyle: AppFonts.text(fontSize: 13, color: textSecondary),
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
