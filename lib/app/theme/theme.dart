import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'app_colors.dart';
import 'app_decorations.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

export 'app_colors.dart';
export 'app_decorations.dart';
export 'app_spacing.dart';
export 'app_text_styles.dart';
export 'app_theme.dart';

/// Convenience accessor — use [AppThemeController] via GetX to switch themes.
///
/// Single-import barrel:
///   import 'package:medihive/app/theme/theme.dart';
///
/// Then access helpers:
///   AppThemeX.isDark           → bool
///   AppThemeX.colors           → AppColors
///   AppThemeX.glassCard(...)   → BoxDecoration
class AppThemeX {
  AppThemeX._();

  static bool get isDark =>
      Get.isDarkMode || Theme.of(Get.context!).brightness == Brightness.dark;

  static BoxDecoration glassCard({BorderRadius? borderRadius}) =>
      AppDecorations.glassCard(isDark: isDark, borderRadius: borderRadius);

  static BoxDecoration glassPill() => AppDecorations.glassPill(isDark: isDark);
}

/// GetX controller — manages theme mode + persists preference.
class AppThemeController extends GetxController {
  final _themeMode = ThemeMode.system.obs;

  ThemeMode get themeMode => _themeMode.value;

  bool get isDark {
    if (_themeMode.value == ThemeMode.system) {
      return Get.isPlatformDarkMode;
    }
    return _themeMode.value == ThemeMode.dark;
  }

  @override
  void onInit() {
    super.onInit();
    // Optional: restore from GetStorage
    // _themeMode.value = ...
    _applySystemChrome();
  }

  void toggleTheme() {
    if (isDark) {
      setThemeMode(ThemeMode.light);
    } else {
      setThemeMode(ThemeMode.dark);
    }
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode.value = mode;
    Get.changeThemeMode(mode);
    _applySystemChrome();
  }

  void setDark(bool value) {
    setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
  }

  void _applySystemChrome() {
    // Handled via AppBarTheme.systemOverlayStyle in AppTheme
  }
}

/// GlassCard widget — ready-to-use frosted glass container.
///
/// Example:
///   GlassCard(
///     child: Text('Patient Info'),
///   )
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: margin,
      decoration: AppDecorations.glassCard(
        isDark: isDark,
        borderRadius: borderRadius ?? AppDecorations.borderLG,
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? AppDecorations.borderLG,
        child: Padding(
          padding: padding ??
              const EdgeInsets.symmetric(
                horizontal: AppSpacing.cardPaddingH,
                vertical: AppSpacing.cardPaddingV,
              ),
          child: child,
        ),
      ),
    );
  }
}

/// StatusBadge — colored pill for appointment/patient status.
///
/// Example:
///   StatusBadge(label: 'Critical', type: StatusType.error)
enum StatusType { success, warning, error, info, neutral }

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.type = StatusType.info,
    this.icon,
  });

  final String label;
  final StatusType type;
  final IconData? icon;

  Color _bg(bool isDark) {
    final base = switch (type) {
      StatusType.success => AppColors.success,
      StatusType.warning => AppColors.warning,
      StatusType.error => AppColors.error,
      StatusType.info => AppColors.info,
      StatusType.neutral =>
        isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
    };
    return base.withValues(alpha: isDark ? 0.2 : 0.15);
  }

  Color _fg() => switch (type) {
        StatusType.success => AppColors.success,
        StatusType.warning => AppColors.warning,
        StatusType.error => AppColors.error,
        StatusType.info => AppColors.info,
        StatusType.neutral => AppColors.primary,
      };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = _fg();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: _bg(isDark),
        borderRadius: AppDecorations.borderFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: fg, size: AppSpacing.iconXS),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: AppTextStyles.labelSmall(fg),
          ),
        ],
      ),
    );
  }
}
