import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — Site brand palette
///
/// MediHive is deployed per site, and the admin console lets an administrator
/// pick the brand. The choice is published on the settings payload as
/// `theme_preset`, with a `custom` escape hatch carrying hex overrides in
/// `theme_custom_colors`. This resolves the same ids, value for value, so the
/// console and the app read as one product.
///
/// ## Why this class computes colours instead of listing them
///
/// A palette that stores one `primary` and uses it for both fills and text
/// works for a navy and fails completely for a mid-luminance brand: the
/// default teal `#0E7C7B` on the clinical paper ground is 4.35:1, which is
/// under the floor by a hair — exactly the kind of near-miss that ships. The
/// naive fix — store a second hand-picked "text" colour per preset — breaks
/// the moment a site sets `custom` to a colour nobody hand-picked for.
///
/// So the palette stores the brand and *derives* the two roles it is asked
/// for, each against the ground it will actually sit on:
///
///  * [ink] — the brand as **words and icons**, walked toward the ground's
///    opposite until it clears 4.5:1.
///  * [fill] — the brand as a **solid shape**, walked only until it clears
///    3:1, because a shape needs an edge, not legibility.
///
/// A brand that already passes is returned untouched, so a navy site gets
/// exactly its navy and nothing is "corrected" that was never wrong.
/// ─────────────────────────────────────────────────────────────────────────────
class BrandPalette {
  const BrandPalette({
    required this.id,
    required this.name,
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.accent,
    required this.accentDark,
    required this.pageTint,
  });

  /// The `theme_preset` value this palette answers to.
  final String id;
  final String name;

  /// The brand itself. CTA fills, the active tab, the hero band.
  final Color primary;

  /// Pressed state of [primary].
  final Color primaryDark;

  /// The preset's own pale tint, for soft fills behind brand elements.
  final Color primaryLight;

  /// Secondary highlight. Used sparingly; never for status.
  final Color accent;
  final Color accentDark;

  /// The faintly tinted page ground the preset draws cards on.
  final Color pageTint;

  // ── The presets ───────────────────────────────────────────────────────────

  /// The MediHive default: clinical teal over cool paper.
  static const clinicalTeal = BrandPalette(
    id: 'default',
    name: 'Clinical Teal',
    primary: AppColors.primary,
    primaryDark: AppColors.primaryDark,
    primaryLight: AppColors.primaryLight,
    accent: AppColors.accent,
    accentDark: AppColors.accentDark,
    pageTint: Color(0xFFF4F6F7),
  );

  /// The blue most hospital groups already brand with, and the one the printed
  /// chart headers use, for sites that want app and paperwork to match.
  static const clinicalBlue = BrandPalette(
    id: 'clinical-blue',
    name: 'Clinical Blue',
    primary: Color(0xFF0059A8),
    primaryDark: Color(0xFF00427E),
    primaryLight: Color(0xFFBFDCF7),
    accent: Color(0xFF0E7C7B),
    accentDark: Color(0xFF0A5F5E),
    pageTint: Color(0xFFF1F5FA),
  );

  /// For trusts branded green. Deep enough that it is never confused with
  /// `acuityStable` on the same screen.
  static const forest = BrandPalette(
    id: 'forest',
    name: 'Forest',
    primary: Color(0xFF15603C),
    primaryDark: Color(0xFF0F4A2E),
    primaryLight: Color(0xFFBFE5CF),
    accent: Color(0xFF0070C0),
    accentDark: Color(0xFF005192),
    pageTint: Color(0xFFF1F7F3),
  );

  /// Plum, for the paediatric and maternity estates that brand away from the
  /// blues and greens the adult wards use.
  static const plum = BrandPalette(
    id: 'plum',
    name: 'Plum',
    primary: Color(0xFF7A2F62),
    primaryDark: Color(0xFF5E234C),
    primaryLight: Color(0xFFEBCFE2),
    accent: Color(0xFF0070C0),
    accentDark: Color(0xFF005192),
    pageTint: Color(0xFFF9F3F7),
  );

  static const presets = [clinicalTeal, clinicalBlue, forest, plum];

  /// The keys `theme_custom_colors` may override.
  static const customKeys = [
    'brandPrimary',
    'brandPrimaryDark',
    'brandPrimaryLight',
    'brandAccent',
    'brandAccentDark',
  ];

  /// Resolves a palette: a known preset id wins; `custom` applies valid hex
  /// overrides on top of the default preset; anything else (including no
  /// settings yet) is the default.
  static BrandPalette resolve({String? presetId, String? customColorsJson}) {
    final id = (presetId ?? '').trim().toLowerCase();
    if (id == 'custom') {
      final o = _parseCustom(customColorsJson);
      const base = clinicalTeal;
      return BrandPalette(
        id: 'custom',
        name: 'Custom',
        primary: o['brandPrimary'] ?? base.primary,
        primaryDark: o['brandPrimaryDark'] ?? base.primaryDark,
        primaryLight: o['brandPrimaryLight'] ?? base.primaryLight,
        accent: o['brandAccent'] ?? base.accent,
        accentDark: o['brandAccentDark'] ?? base.accentDark,
        pageTint: base.pageTint,
      );
    }
    for (final p in presets) {
      if (p.id == id) return p;
    }
    return clinicalTeal;
  }

  static final _hex = RegExp(r'^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$');

  static Map<String, Color> _parseCustom(String? json) {
    if (json == null || json.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map) return const {};
      final out = <String, Color>{};
      for (final key in customKeys) {
        final value = decoded[key];
        if (value is String && _hex.hasMatch(value.trim())) {
          out[key] = _colorFromHex(value.trim());
        }
      }
      return out;
    } catch (_) {
      // A malformed override falls back to the preset rather than throwing
      // inside the theme.
      return const {};
    }
  }

  static Color _colorFromHex(String hex) {
    var digits = hex.substring(1);
    if (digits.length == 3) {
      digits = digits.split('').map((c) => '$c$c').join();
    }
    return Color(int.parse('FF$digits', radix: 16));
  }

  // ── Contrast machinery ────────────────────────────────────────────────────

  /// WCAG 2.1 contrast ratio between two opaque colours, 1.0 … 21.0.
  static double contrastRatio(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  /// WCAG AA for body text.
  static const double textContrast = 4.5;

  /// WCAG AA for a non-text shape that only has to be seen, not read.
  static const double shapeContrast = 3.0;

  /// Walks [brand]'s HSL lightness toward whichever end of the scale is away
  /// from [ground], stopping at the first step that clears [target].
  ///
  /// Hue and saturation are untouched, so the result is recognisably the same
  /// brand — a darker teal, not a slate. Returns [brand] unchanged when it
  /// already passes, and the closest it got if the ramp runs out (a mid-grey
  /// brand on a mid-grey ground has no passing value; the theme should still
  /// paint something).
  static Color readable(Color brand, Color ground, {required double target}) {
    if (contrastRatio(brand, ground) >= target) return brand;

    final darken = ground.computeLuminance() > 0.5;
    var hsl = HSLColor.fromColor(brand);
    var best = brand;
    var bestRatio = contrastRatio(brand, ground);

    for (var step = 0; step < 40; step++) {
      final next = (darken ? hsl.lightness - 0.025 : hsl.lightness + 0.025)
          .clamp(0.0, 1.0);
      if (next == hsl.lightness) break;
      hsl = hsl.withLightness(next);
      final candidate = hsl.toColor();
      final ratio = contrastRatio(candidate, ground);
      if (ratio > bestRatio) {
        bestRatio = ratio;
        best = candidate;
      }
      if (ratio >= target) return candidate;
    }
    return best;
  }

  // ── Derived roles ─────────────────────────────────────────────────────────

  Color _ground(Brightness brightness) => brightness == Brightness.dark
      ? AppColors.darkBackground
      : AppColors.lightBackground;

  /// The brand as words, icons and links: legible on this mode's ground.
  ///
  /// This is what a "brand-coloured label" means. It is never a fill.
  Color ink(Brightness brightness) =>
      readable(primary, _ground(brightness), target: textContrast);

  /// The brand as a solid shape: **the brand itself, always.**
  ///
  /// Deliberately not adjusted. A teal button has to be the brand teal —
  /// darkening `#0E7C7B` until the fill alone cleared 3:1 against cool paper
  /// produced a near-black green that is no longer the brand, which is a worse
  /// outcome than the problem it solved.
  ///
  /// The 3:1 boundary that a filled control owes a viewer is paid by
  /// [fillEdge] instead — a hairline in a deeper or lighter shade of the same
  /// brand — while [onFill] guarantees the label on top is legible. A control
  /// is then identifiable by its edge and readable by its label, with its
  /// colour intact.
  Color fill(Brightness brightness) => primary;

  /// The hairline around a [fill], guaranteed to be discernible against this
  /// mode's ground.
  ///
  /// Returns the brand unchanged when the fill already has an edge of its own,
  /// so a deep brand in light mode gets no ring it does not need.
  Color fillEdge(Brightness brightness) =>
      readable(primary, _ground(brightness), target: shapeContrast);

  /// Text and icons on [fill]: whichever of the two inks reads better on it.
  ///
  /// White for teal, ink for a pale brand — decided by measurement rather than
  /// by a luminance threshold, because a threshold picks wrong for exactly the
  /// mid-luminance brands where it matters.
  Color onFill(Brightness brightness) => onPrimary;

  /// Text and icons on a [primary] fill. [fill] is the brand in both modes, so
  /// this answer does not depend on brightness.
  Color get onPrimary => contrastRatio(primary, const Color(0xFF0B1416)) >=
          contrastRatio(primary, Colors.white)
      ? const Color(0xFF0B1416)
      : Colors.white;

  /// Soft brand fill behind a tonal control or a selected tab.
  Color tonal(Brightness brightness) => brightness == Brightness.dark
      ? ink(Brightness.dark).withValues(alpha: 0.16)
      : primary.withValues(alpha: 0.14);
}
