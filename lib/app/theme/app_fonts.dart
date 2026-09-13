import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — Fonts
///
/// The site chooses the app's face in the web portal (`theme_font`), from
/// the same ten-entry registry the web ships. Every face is bundled as an
/// asset, so there is **no runtime HTTP fetch**: the `google_fonts` package
/// downloads font files on demand, which stalls the raster thread the first
/// time each screen renders on a fresh release install.
///
/// The active family is a single static read. `ThemeService` sets it once at
/// boot (from the persisted snapshot) and again only when the live settings
/// name a different face; nothing about it runs per frame.
/// ─────────────────────────────────────────────────────────────────────────────

/// One selectable face, mirroring the web registry id for id.
class AppFontFace {
  const AppFontFace({
    required this.id,
    required this.label,
    required this.family,
    required this.assets,
  });

  /// The `theme_font` value.
  final String id;
  final String label;

  /// The `family` declared in `pubspec.yaml`.
  final String family;

  /// The bundled files, for the test harness's `FontLoader`.
  final List<String> assets;
}

/// The web's font registry, with the same ids and default.
abstract class AppFontRegistry {
  static const inter = AppFontFace(
    id: 'inter',
    label: 'Inter',
    family: 'Inter',
    assets: ['assets/fonts/Inter.ttf'],
  );
  static const montserrat = AppFontFace(
    id: 'montserrat',
    label: 'Montserrat',
    family: 'Montserrat',
    assets: ['assets/fonts/Montserrat.ttf'],
  );
  static const poppins = AppFontFace(
    id: 'poppins',
    label: 'Poppins',
    family: 'Poppins',
    assets: [
      'assets/fonts/Poppins-Regular.ttf',
      'assets/fonts/Poppins-Medium.ttf',
      'assets/fonts/Poppins-SemiBold.ttf',
      'assets/fonts/Poppins-Bold.ttf',
    ],
  );
  static const roboto = AppFontFace(
    id: 'roboto',
    label: 'Roboto',
    family: 'Roboto',
    assets: ['assets/fonts/Roboto.ttf'],
  );
  static const openSans = AppFontFace(
    id: 'open-sans',
    label: 'Open Sans',
    family: 'Open Sans',
    assets: ['assets/fonts/OpenSans.ttf'],
  );
  static const lato = AppFontFace(
    id: 'lato',
    label: 'Lato',
    family: 'Lato',
    assets: ['assets/fonts/Lato-Regular.ttf', 'assets/fonts/Lato-Bold.ttf'],
  );
  static const nunito = AppFontFace(
    id: 'nunito',
    label: 'Nunito',
    family: 'Nunito',
    assets: ['assets/fonts/Nunito.ttf'],
  );
  static const workSans = AppFontFace(
    id: 'work-sans',
    label: 'Work Sans',
    family: 'Work Sans',
    assets: ['assets/fonts/WorkSans.ttf'],
  );
  static const dmSans = AppFontFace(
    id: 'dm-sans',
    label: 'DM Sans',
    family: 'DM Sans',
    assets: ['assets/fonts/DMSans.ttf'],
  );
  static const manrope = AppFontFace(
    id: 'manrope',
    label: 'Manrope',
    family: 'Manrope',
    assets: ['assets/fonts/Manrope.ttf'],
  );

  static const faces = [
    inter,
    montserrat,
    poppins,
    roboto,
    openSans,
    lato,
    nunito,
    workSans,
    dmSans,
    manrope,
  ];

  /// The default face.
  ///
  /// Montserrat, the client's face. It survives contact with a ledger because
  /// every figure in this app is set through [AppFonts.numeric], which asks
  /// for `tnum` explicitly — Montserrat ships that feature, so a column of
  /// totals still lines up even though its proportional digits do not.
  ///
  /// It is a variable font whose default instance is Thin (see [weightAxis]),
  /// which is only safe because nothing here draws text without a weight.
  static const defaultId = 'montserrat';

  /// The default face. Also what a `custom` Google Font resolves to: a face
  /// that is not bundled cannot be drawn without a network fetch, which is the
  /// cost this registry exists to avoid.
  static AppFontFace get fallback => montserrat;

  /// Resolves like the web's `getFont`: a known id wins, anything else (blank,
  /// unknown, `custom`) is the default.
  static AppFontFace resolve(String? id) {
    final key = (id ?? '').trim().toLowerCase();
    for (final face in faces) {
      if (face.id == key) return face;
    }
    return fallback;
  }
}

abstract class AppFonts {
  static String _family = AppFontRegistry.fallback.family;

  /// The family every text style is built with right now.
  static String get family => _family;

  /// Switches the active family. Called by `ThemeService` only, and only when
  /// the resolved face changes; the theme is rebuilt in the same step.
  static void useFamily(String family) {
    _family = family;
  }

  /// The app's text style, in whichever face the site chose.
  static TextStyle text({
    TextStyle? textStyle,
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    Color? backgroundColor,
    double? letterSpacing,
    double? wordSpacing,
    double? height,
    FontStyle? fontStyle,
    TextDecoration? decoration,
    Color? decorationColor,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
  }) {
    final base = textStyle ?? const TextStyle();
    final weight = fontWeight ?? base.fontWeight ?? FontWeight.w400;
    return base.copyWith(
      fontFamily: _family,
      fontSize: fontSize,
      fontWeight: weight,
      fontVariations: weightAxis(weight),
      color: color,
      backgroundColor: backgroundColor,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      height: height,
      fontStyle: fontStyle,
      decoration: decoration,
      decorationColor: decorationColor,
      shadows: shadows,
      fontFeatures: fontFeatures,
    );
  }

  /// The same style with tabular figures, for anything that ticks or lines up
  /// in a column. Every money column in this app uses it.
  static TextStyle numeric({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) =>
      text(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// The `wght` axis for a weight.
  ///
  /// Flutter does not map [FontWeight] onto a variable font's weight axis by
  /// itself, and declaring a `weight:` beside the asset in `pubspec.yaml` only
  /// says which file answers for that weight — it does not move the axis. A
  /// variable face therefore draws at its own default instance however heavy a
  /// [FontWeight] the style names.
  ///
  /// That default instance is not 400 for half the registry: Montserrat's is
  /// Thin (100), Nunito's and Manrope's are ExtraLight (200). Since Montserrat
  /// is now the app default, this is the single line standing between the
  /// whole app and hairline body copy — which is why [text] and [textTheme]
  /// both apply it unconditionally rather than only when a caller asks for a
  /// weight. Static faces (Poppins, Lato) ignore the axis and pick their
  /// weight file as usual.
  static List<FontVariation> weightAxis(FontWeight weight) =>
      [FontVariation('wght', weight.value.toDouble())];

  /// Rebrands every style in a base text theme to the active family, with the
  /// weight axis each style already names.
  static TextTheme textTheme([TextTheme? base]) {
    final b = (base ?? const TextTheme()).apply(fontFamily: _family);
    TextStyle? axis(TextStyle? s) =>
        s?.copyWith(fontVariations: weightAxis(s.fontWeight ?? FontWeight.w400));
    return b.copyWith(
      displayLarge: axis(b.displayLarge),
      displayMedium: axis(b.displayMedium),
      displaySmall: axis(b.displaySmall),
      headlineLarge: axis(b.headlineLarge),
      headlineMedium: axis(b.headlineMedium),
      headlineSmall: axis(b.headlineSmall),
      titleLarge: axis(b.titleLarge),
      titleMedium: axis(b.titleMedium),
      titleSmall: axis(b.titleSmall),
      bodyLarge: axis(b.bodyLarge),
      bodyMedium: axis(b.bodyMedium),
      bodySmall: axis(b.bodySmall),
      labelLarge: axis(b.labelLarge),
      labelMedium: axis(b.labelMedium),
      labelSmall: axis(b.labelSmall),
    );
  }
}
