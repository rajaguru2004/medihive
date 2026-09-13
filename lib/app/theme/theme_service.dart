import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/site_settings.dart';
import 'app_fonts.dart';
import 'app_theme.dart';
import 'brand_palette.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — Theme Service
///
/// Turns the site's branding (`theme_preset`, `theme_custom_colors`,
/// `theme_font`) into the app's `ThemeData`, with the smallest possible cost:
///
///  * **Resolve once, at boot.** [restore] reads the last applied brand and
///    face from local storage before the first frame, so a cold start paints
///    on-brand and never re-themes when the live settings arrive unchanged.
///  * **Apply only on change.** [adopt] computes a signature of the three keys
///    that matter; an unchanged signature returns before touching anything. A
///    change rebuilds the two themes once and hands them to GetX's root
///    controller.
///  * **No network.** Faces come from the bundled registry (`AppFontRegistry`).
///
/// Light/dark *mode* stays with `AppThemeController`; this owns what the two
/// modes are made of.
/// ─────────────────────────────────────────────────────────────────────────────
class ThemeService extends GetxService {
  static ThemeService get to => Get.find<ThemeService>();

  static const _kPreset = 'theme_snapshot_preset';
  static const _kCustomColors = 'theme_snapshot_custom_colors';
  static const _kFont = 'theme_snapshot_font';

  ThemeService() {
    _light = AppTheme.build(Brightness.light, brand: _brand);
    _dark = AppTheme.build(Brightness.dark, brand: _brand);
  }

  BrandPalette _brand = BrandPalette.clinicalTeal;
  AppFontFace _face = AppFontRegistry.fallback;
  String _signature = '';
  late ThemeData _light;
  late ThemeData _dark;

  BrandPalette get brand => _brand;
  AppFontFace get face => _face;
  ThemeData get lightTheme => _light;
  ThemeData get darkTheme => _dark;

  /// What [adopt] compares: the settings keys that change the theme, and
  /// nothing else, so an unrelated settings change never rebuilds a theme.
  static String signatureOf({
    String? preset,
    String? customColors,
    String? font,
  }) =>
      '${(preset ?? '').trim().toLowerCase()}|${customColors ?? ''}|'
      '${(font ?? '').trim().toLowerCase()}';

  /// Restores the last applied brand and face. Call before `runApp`: restoring
  /// after the first frame paints one frame in the default brand.
  ///
  /// Never throws — unreadable storage (or no plugin at all, in a bare widget
  /// test) means the defaults, which is what a first launch shows anyway.
  Future<void> restore() async {
    String? preset;
    String? customColors;
    String? font;
    try {
      final prefs = await SharedPreferences.getInstance();
      preset = prefs.getString(_kPreset);
      customColors = prefs.getString(_kCustomColors);
      font = prefs.getString(_kFont);
    } catch (e) {
      debugPrint('[ThemeService] snapshot restore failed: $e');
    }
    // Normalised to the server defaults, so a first launch whose live settings
    // are the defaults does not rebuild the theme it already has.
    _resolve(
      preset: preset ?? BrandPalette.clinicalTeal.id,
      customColors: customColors ?? '',
      font: font ?? AppFontRegistry.defaultId,
      force: true,
    );
  }

  /// Applies the live settings. Returns true when the theme actually changed.
  bool adopt(SiteSettings settings) {
    final changed = _resolve(
      preset: settings.themePreset,
      customColors: settings.themeCustomColors,
      font: settings.themeFont,
    );
    if (!changed) return false;
    _push();
    unawaited(_persist(settings));
    return true;
  }

  /// Rebuilds the themes for a new brand or face. [force] rebuilds even when
  /// the signature matches, which [restore] needs on its first run.
  bool _resolve({
    String? preset,
    String? customColors,
    String? font,
    bool force = false,
  }) {
    final signature = signatureOf(
      preset: preset,
      customColors: customColors,
      font: font,
    );
    if (!force && signature == _signature) return false;

    _signature = signature;
    _brand = BrandPalette.resolve(
      presetId: preset,
      customColorsJson: customColors,
    );
    _face = AppFontRegistry.resolve(font);
    AppFonts.useFamily(_face.family);
    _light = AppTheme.build(Brightness.light, brand: _brand);
    _dark = AppTheme.build(Brightness.dark, brand: _brand);
    return true;
  }

  /// Hands both themes to GetX.
  ///
  /// `Get.changeTheme` is not used on purpose: in get 4.7.3 it routes by
  /// brightness only once a dark theme has been set, so the first dark theme
  /// would land in the light slot.
  void _push() {
    final root = Get.rootController;
    root.theme = _light;
    root.darkTheme = _dark;
    root.update();
  }

  Future<void> _persist(SiteSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setString(_kPreset, settings.themePreset),
        prefs.setString(_kCustomColors, settings.themeCustomColors),
        prefs.setString(_kFont, settings.themeFont),
      ]);
    } catch (e) {
      // The theme is already on screen; failing to remember it costs one
      // re-theme on the next cold start, not a wrong screen now.
      debugPrint('[ThemeService] snapshot persist failed: $e');
    }
  }
}
