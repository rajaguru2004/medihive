import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_decorations.dart';
import 'app_text_styles.dart';

/// MediHive centralized theme.
/// Usage:
///   GetMaterialApp(
///     theme: AppTheme.light,
///     darkTheme: AppTheme.dark,
///     themeMode: ThemeMode.system,
///   )
abstract class AppTheme {
  // ─── Light Theme ──────────────────────────────────────────────────────────
  static ThemeData get light => _build(isDark: false);

  // ─── Dark Theme ───────────────────────────────────────────────────────────
  static ThemeData get dark => _build(isDark: true);

  // ─────────────────────────────────────────────────────────────────────────
  static ThemeData _build({required bool isDark}) {
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final surfaceVariant =
        isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant;
    final onBg =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final onSurface =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final onSurfaceVariant =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final divider = isDark ? AppColors.darkDivider : AppColors.lightDivider;

    final colorScheme = ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      // Primary
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: isDark
          ? AppColors.primaryDark.withValues(alpha: 0.3)
          : AppColors.primaryLight.withValues(alpha: 0.15),
      onPrimaryContainer:
          isDark ? AppColors.primaryLight : AppColors.primaryDark,
      // Secondary
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: isDark
          ? AppColors.secondaryDark.withValues(alpha: 0.3)
          : AppColors.secondaryLight.withValues(alpha: 0.15),
      onSecondaryContainer:
          isDark ? AppColors.secondaryLight : AppColors.secondaryDark,
      // Tertiary
      tertiary: AppColors.tertiary,
      onTertiary: Colors.white,
      tertiaryContainer: isDark
          ? AppColors.tertiaryDark.withValues(alpha: 0.3)
          : AppColors.tertiaryLight.withValues(alpha: 0.15),
      onTertiaryContainer:
          isDark ? AppColors.tertiaryLight : AppColors.tertiaryDark,
      // Error
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: isDark
          ? AppColors.error.withValues(alpha: 0.2)
          : AppColors.error.withValues(alpha: 0.1),
      onErrorContainer: AppColors.error,
      // Surface
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: surfaceVariant,
      onSurfaceVariant: onSurfaceVariant,
      // Outline
      outline: divider,
      outlineVariant: isDark
          ? AppColors.darkDivider.withValues(alpha: 0.5)
          : AppColors.lightDivider.withValues(alpha: 0.5),
      // Scrim / Shadow
      scrim: Colors.black,
      shadow: Colors.black,
      // Inverse
      inverseSurface: isDark ? AppColors.lightSurface : AppColors.darkSurface,
      onInverseSurface:
          isDark ? AppColors.lightTextPrimary : AppColors.darkTextPrimary,
      inversePrimary: isDark ? AppColors.primaryLight : AppColors.primaryDark,
    );

    // ─── Base Text Theme ──────────────────────────────────────────────────
    final textTheme = GoogleFonts.interTextTheme(
      TextTheme(
        displayLarge: AppTextStyles.display1(onBg),
        displayMedium: AppTextStyles.display2(onBg),
        displaySmall: AppTextStyles.headlineLarge(onBg),
        headlineLarge: AppTextStyles.headlineLarge(onBg),
        headlineMedium: AppTextStyles.headlineMedium(onBg),
        headlineSmall: AppTextStyles.headlineSmall(onBg),
        titleLarge: AppTextStyles.titleLarge(onBg),
        titleMedium: AppTextStyles.titleMedium(onBg),
        titleSmall: AppTextStyles.titleSmall(onBg),
        bodyLarge: AppTextStyles.bodyLarge(onBg),
        bodyMedium: AppTextStyles.bodyMedium(onBg),
        bodySmall: AppTextStyles.bodySmall(onBg),
        labelLarge: AppTextStyles.labelLarge(onBg),
        labelMedium: AppTextStyles.labelMedium(onBg),
        labelSmall: AppTextStyles.labelSmall(onBg),
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: bg,
      textTheme: textTheme,
      primaryTextTheme: textTheme,

      // ─── AppBar ───────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: isDark
            ? AppColors.darkSurface.withValues(alpha: 0.85)
            : AppColors.lightSurface.withValues(alpha: 0.85),
        foregroundColor: onBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: AppTextStyles.titleLarge(onBg),
        iconTheme: IconThemeData(color: AppColors.primary, size: 24),
        actionsIconTheme: IconThemeData(color: AppColors.primary, size: 24),
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),

      // ─── Card ─────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppDecorations.borderLG,
          side: BorderSide(color: divider, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      // ─── Elevated Button ──────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: isDark
              ? AppColors.darkSurfaceVariant
              : AppColors.lightSurfaceVariant,
          disabledForegroundColor:
              isDark ? AppColors.darkTextDisabled : AppColors.lightTextDisabled,
          elevation: 0,
          shadowColor: Colors.transparent,
          textStyle: AppTextStyles.labelLarge(Colors.white),
          minimumSize: const Size(double.infinity, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const RoundedRectangleBorder(
            borderRadius: AppDecorations.borderMD,
          ),
        ),
      ),

      // ─── Outlined Button ──────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          textStyle: AppTextStyles.labelLarge(AppColors.primary),
          minimumSize: const Size(double.infinity, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const RoundedRectangleBorder(
            borderRadius: AppDecorations.borderMD,
          ),
        ),
      ),

      // ─── Text Button ──────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppTextStyles.labelLarge(AppColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: const RoundedRectangleBorder(
            borderRadius: AppDecorations.borderSM,
          ),
        ),
      ),

      // ─── FilledButton ─────────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          textStyle: AppTextStyles.labelLarge(Colors.white),
          minimumSize: const Size(double.infinity, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const RoundedRectangleBorder(
            borderRadius: AppDecorations.borderMD,
          ),
        ),
      ),

      // ─── Input / TextField ────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? AppColors.darkSurfaceVariant
            : AppColors.lightSurfaceVariant,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: AppDecorations.borderMD,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppDecorations.borderMD,
          borderSide: BorderSide(color: divider, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppDecorations.borderMD,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppDecorations.borderMD,
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppDecorations.borderMD,
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        hintStyle: AppTextStyles.bodyMedium(
          isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
        ),
        labelStyle: AppTextStyles.bodyMedium(onSurfaceVariant),
        floatingLabelStyle: AppTextStyles.labelMedium(AppColors.primary),
        prefixIconColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.focused)
              ? AppColors.primary
              : (isDark
                  ? AppColors.darkTextTertiary
                  : AppColors.lightTextTertiary),
        ),
        suffixIconColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.focused)
              ? AppColors.primary
              : (isDark
                  ? AppColors.darkTextTertiary
                  : AppColors.lightTextTertiary),
        ),
      ),

      // ─── Bottom Nav Bar ───────────────────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark
            ? AppColors.darkSurface.withValues(alpha: 0.9)
            : AppColors.lightSurface.withValues(alpha: 0.9),
        selectedItemColor: AppColors.primary,
        unselectedItemColor:
            isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: AppTextStyles.labelSmall(AppColors.primary),
        unselectedLabelStyle: AppTextStyles.labelSmall(
          isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
        ),
      ),

      // ─── Navigation Bar (M3) ──────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark
            ? AppColors.darkSurface.withValues(alpha: 0.9)
            : AppColors.lightSurface.withValues(alpha: 0.9),
        indicatorColor: AppColors.primary.withValues(alpha: 0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return IconThemeData(
            color: active
                ? AppColors.primary
                : (isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.lightTextTertiary),
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return AppTextStyles.labelSmall(
            active
                ? AppColors.primary
                : (isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.lightTextTertiary),
          );
        }),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),

      // ─── FAB ──────────────────────────────────────────────────────────────
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: AppDecorations.borderXL,
        ),
      ),

      // ─── Chip ─────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: isDark
            ? AppColors.darkSurfaceVariant
            : AppColors.lightSurfaceVariant,
        selectedColor: AppColors.primary.withValues(alpha: 0.15),
        disabledColor: isDark
            ? AppColors.darkSurfaceVariant.withValues(alpha: 0.5)
            : AppColors.lightSurfaceVariant.withValues(alpha: 0.5),
        labelStyle: AppTextStyles.labelMedium(onBg),
        secondaryLabelStyle: AppTextStyles.labelMedium(AppColors.primary),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: const StadiumBorder(),
        side: BorderSide(color: divider, width: 0.5),
        elevation: 0,
        pressElevation: 0,
      ),

      // ─── Dialog ───────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: AppDecorations.borderXL,
        ),
        titleTextStyle: AppTextStyles.titleLarge(onBg),
        contentTextStyle: AppTextStyles.bodyMedium(onSurfaceVariant),
      ),

      // ─── Bottom Sheet ─────────────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDecorations.radiusXL),
          ),
        ),
        modalBackgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        modalElevation: 0,
        dragHandleColor:
            isDark ? AppColors.darkDivider : AppColors.lightDivider,
        dragHandleSize: const Size(40, 4),
      ),

      // ─── Divider ──────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: divider,
        thickness: 0.5,
        space: 0,
      ),

      // ─── Switch ───────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? Colors.white
                : (isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.lightTextTertiary)),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.primary
                : (isDark
                    ? AppColors.darkSurfaceVariant
                    : AppColors.lightSurfaceVariant)),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      // ─── Checkbox ─────────────────────────────────────────────────────────
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: BorderSide(color: divider, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),

      // ─── Radio ────────────────────────────────────────────────────────────
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.primary
                : (isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.lightTextTertiary)),
      ),

      // ─── Slider ───────────────────────────────────────────────────────────
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: isDark
            ? AppColors.darkSurfaceVariant
            : AppColors.lightSurfaceVariant,
        thumbColor: AppColors.primary,
        overlayColor: AppColors.primary.withValues(alpha: 0.12),
        valueIndicatorColor: AppColors.primary,
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
      ),

      // ─── Progress Indicator ───────────────────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: Colors.transparent,
        circularTrackColor: Colors.transparent,
      ),

      // ─── Snack Bar ────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor:
            isDark ? AppColors.darkSurfaceVariant : const Color(0xFF1C1C1E),
        contentTextStyle: AppTextStyles.bodyMedium(Colors.white),
        actionTextColor: AppColors.primary,
        shape: const RoundedRectangleBorder(
          borderRadius: AppDecorations.borderMD,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      ),

      // ─── Tab Bar ──────────────────────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor:
            isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
        labelStyle: AppTextStyles.labelLarge(AppColors.primary),
        unselectedLabelStyle: AppTextStyles.labelLarge(
          isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
        ),
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
      ),

      // ─── List Tile ────────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: AppDecorations.borderMD,
        ),
        iconColor:
            isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        textColor: onBg,
        leadingAndTrailingTextStyle: AppTextStyles.labelMedium(
          isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
        ),
      ),

      // ─── Misc ─────────────────────────────────────────────────────────────
      splashFactory: NoSplash.splashFactory,
      highlightColor: AppColors.primary.withValues(alpha: 0.06),
      hoverColor: AppColors.primary.withValues(alpha: 0.04),
      focusColor: AppColors.primary.withValues(alpha: 0.08),
      disabledColor:
          isDark ? AppColors.darkTextDisabled : AppColors.lightTextDisabled,
      unselectedWidgetColor:
          isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
      iconTheme: IconThemeData(
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        size: 24,
      ),
      primaryIconTheme: const IconThemeData(
        color: AppColors.primary,
        size: 24,
      ),
    );
  }
}
