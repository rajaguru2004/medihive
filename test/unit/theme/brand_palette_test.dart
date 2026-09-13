import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medihive/app/theme/theme.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — `BrandPalette`
///
/// The palette derives its two brand roles instead of storing them, which means
/// a site can set `custom` to a colour nobody hand-picked for and still get
/// legible words. These tests hold that promise to its arithmetic: the ratio is
/// the WCAG one, the walk stops at a passing value, and the walk stays on the
/// brand's hue so a darker teal never arrives as a slate.
/// ─────────────────────────────────────────────────────────────────────────────
void main() {
  const white = Color(0xFFFFFFFF);
  const black = Color(0xFF000000);

  /// The hue of a colour, for asserting that a lightness walk left it alone.
  double hueOf(Color color) => HSLColor.fromColor(color).hue;

  group('contrastRatio', () {
    test('black on white is the WCAG maximum of 21:1', () {
      expect(BrandPalette.contrastRatio(black, white), closeTo(21, 1e-9));
    });

    test('a colour against itself is 1:1', () {
      expect(
        BrandPalette.contrastRatio(AppColors.primary, AppColors.primary),
        closeTo(1, 1e-9),
      );
      expect(BrandPalette.contrastRatio(white, white), closeTo(1, 1e-9));
    });

    test('reads the same in either order', () {
      // The formula divides the lighter by the darker, so a caller never has to
      // remember which argument is the ground.
      expect(
        BrandPalette.contrastRatio(black, white),
        closeTo(BrandPalette.contrastRatio(white, black), 1e-9),
      );
    });
  });

  group('readable', () {
    test('returns the brand untouched when it already clears the target', () {
      // A navy site gets exactly its navy. Nothing is "corrected" that was
      // never wrong — identity, not merely an equal value.
      final result = BrandPalette.readable(
        black,
        white,
        target: BrandPalette.textContrast,
      );
      expect(result, same(black));
    });

    test('walks a failing brand until it clears the target on a light ground',
        () {
      // Pale amber on white is 1.5:1 — the kind of brand a marketing deck
      // hands over and a form label then disappears into.
      const paleAmber = Color(0xFFFFE066);
      expect(
        BrandPalette.contrastRatio(paleAmber, white),
        lessThan(BrandPalette.textContrast),
      );

      final ink = BrandPalette.readable(
        paleAmber,
        white,
        target: BrandPalette.textContrast,
      );

      expect(
        BrandPalette.contrastRatio(ink, white),
        greaterThanOrEqualTo(BrandPalette.textContrast),
      );
      // Still the same brand, one shade deeper: hue is what a viewer recognises
      // a brand by, and the walk only ever moves lightness.
      expect(hueOf(ink), closeTo(hueOf(paleAmber), 1.0));
    });

    test('walks a failing brand the other way on a dark ground', () {
      // The direction is chosen from the ground, not from the brand: the same
      // teal has to get darker on paper and lighter on slate.
      final ink = BrandPalette.readable(
        AppColors.primary,
        AppColors.darkBackground,
        target: BrandPalette.textContrast,
      );

      expect(
        BrandPalette.contrastRatio(ink, AppColors.darkBackground),
        greaterThanOrEqualTo(BrandPalette.textContrast),
      );
      expect(
        HSLColor.fromColor(ink).lightness,
        greaterThan(HSLColor.fromColor(AppColors.primary).lightness),
      );
      expect(hueOf(ink), closeTo(hueOf(AppColors.primary), 1.0));
    });

    test('stops at 3:1 when that is all a shape was asked for', () {
      // A fill edge owes a viewer an edge, not legibility, so it must not be
      // walked as far as a word would be.
      const paleAmber = Color(0xFFFFE066);
      final edge = BrandPalette.readable(
        paleAmber,
        white,
        target: BrandPalette.shapeContrast,
      );
      final ink = BrandPalette.readable(
        paleAmber,
        white,
        target: BrandPalette.textContrast,
      );

      expect(
        BrandPalette.contrastRatio(edge, white),
        greaterThanOrEqualTo(BrandPalette.shapeContrast),
      );
      expect(
        HSLColor.fromColor(edge).lightness,
        greaterThan(HSLColor.fromColor(ink).lightness),
      );
    });

    test('returns the closest it got when no lightness passes', () {
      // A mid-grey brand on a mid-grey ground has no passing value at all. The
      // theme still has to paint something, so the walk hands back its best
      // attempt rather than the failing original.
      const midGrey = Color(0xFF808080);
      final result = BrandPalette.readable(
        midGrey,
        midGrey,
        target: BrandPalette.textContrast,
      );

      expect(
        BrandPalette.contrastRatio(result, midGrey),
        lessThan(BrandPalette.textContrast),
      );
      expect(
        BrandPalette.contrastRatio(result, midGrey),
        greaterThan(BrandPalette.contrastRatio(midGrey, midGrey)),
      );
    });
  });

  group('ink and fill, for the default clinical teal', () {
    const teal = BrandPalette.clinicalTeal;

    test('fill is the brand itself, in both modes', () {
      // Deliberately unadjusted: darkening `#0E7C7B` until the fill alone
      // cleared 3:1 produced a near-black green that is no longer the brand.
      expect(teal.fill(Brightness.light), AppColors.primary);
      expect(teal.fill(Brightness.dark), AppColors.primary);
    });

    test('ink clears 4.5:1 on the light ground', () {
      expect(
        BrandPalette.contrastRatio(
          teal.ink(Brightness.light),
          AppColors.lightBackground,
        ),
        greaterThanOrEqualTo(BrandPalette.textContrast),
      );
    });

    test('ink clears 4.5:1 on the dark ground', () {
      // The mode that catches a palette out: the brand is chosen against paper,
      // and teal on deep slate is 3.7:1 before the walk.
      expect(
        BrandPalette.contrastRatio(
          teal.ink(Brightness.dark),
          AppColors.darkBackground,
        ),
        greaterThanOrEqualTo(BrandPalette.textContrast),
      );
    });

    test('ink stays on the brand hue in both modes', () {
      expect(
        HSLColor.fromColor(teal.ink(Brightness.light)).hue,
        closeTo(HSLColor.fromColor(AppColors.primary).hue, 1.0),
      );
      expect(
        HSLColor.fromColor(teal.ink(Brightness.dark)).hue,
        closeTo(HSLColor.fromColor(AppColors.primary).hue, 1.0),
      );
    });
  });

  group('resolve', () {
    test('a known preset id returns that preset', () {
      for (final preset in BrandPalette.presets) {
        expect(BrandPalette.resolve(presetId: preset.id), same(preset));
      }
    });

    test('the id is matched case- and whitespace-insensitively', () {
      // It arrives from a settings document an administrator typed into.
      expect(
        BrandPalette.resolve(presetId: '  FOREST '),
        same(BrandPalette.forest),
      );
      expect(
        BrandPalette.resolve(presetId: 'Clinical-Blue'),
        same(BrandPalette.clinicalBlue),
      );
    });

    test('custom applies every valid hex override on top of the default', () {
      final palette = BrandPalette.resolve(
        presetId: 'custom',
        customColorsJson: '{'
            '"brandPrimary":"#123456",'
            '"brandPrimaryDark":"#0a1b2c",'
            '"brandPrimaryLight":"#abc",'
            '"brandAccent":"#FF8800",'
            '"brandAccentDark":"#884400"'
            '}',
      );

      expect(palette.id, 'custom');
      expect(palette.primary, const Color(0xFF123456));
      expect(palette.primaryDark, const Color(0xFF0A1B2C));
      // Three digits expand to six, the way CSS reads them.
      expect(palette.primaryLight, const Color(0xFFAABBCC));
      expect(palette.accent, const Color(0xFFFF8800));
      expect(palette.accentDark, const Color(0xFF884400));
    });

    test('custom keeps the default for any key it did not override', () {
      final palette = BrandPalette.resolve(
        presetId: 'custom',
        customColorsJson: '{"brandPrimary":"#123456"}',
      );

      expect(palette.primary, const Color(0xFF123456));
      expect(palette.primaryDark, BrandPalette.clinicalTeal.primaryDark);
      expect(palette.accent, BrandPalette.clinicalTeal.accent);
      // The page tint is never a custom key, so it always comes from the base.
      expect(palette.pageTint, BrandPalette.clinicalTeal.pageTint);
    });

    test('malformed custom JSON falls back rather than throwing in the theme',
        () {
      // This runs inside `ThemeService` before the first frame. A throw here is
      // a site that cannot start because somebody fat-fingered a settings row.
      for (final broken in <String?>[
        '{not json',
        '[]',
        '"a string"',
        '',
        '   ',
        null,
      ]) {
        final palette =
            BrandPalette.resolve(presetId: 'custom', customColorsJson: broken);
        expect(palette.id, 'custom', reason: 'input: $broken');
        expect(palette.primary, BrandPalette.clinicalTeal.primary,
            reason: 'input: $broken');
      }
    });

    test('a custom value that is not a hex colour is ignored, not guessed', () {
      final palette = BrandPalette.resolve(
        presetId: 'custom',
        customColorsJson: '{'
            '"brandPrimary":"rebeccapurple",'
            '"brandAccent":"#0059A8",'
            '"brandAccentDark":42'
            '}',
      );

      expect(palette.primary, BrandPalette.clinicalTeal.primary);
      expect(palette.accent, const Color(0xFF0059A8));
      expect(palette.accentDark, BrandPalette.clinicalTeal.accentDark);
    });

    test('an unknown id and no settings at all are both the default preset',
        () {
      // A site provisioned before a preset existed, and a cold start before the
      // first settings fetch lands, are the same case: paint the default.
      expect(
        BrandPalette.resolve(presetId: 'mauve'),
        same(BrandPalette.clinicalTeal),
      );
      expect(BrandPalette.resolve(), same(BrandPalette.clinicalTeal));
      expect(
        BrandPalette.resolve(presetId: null, customColorsJson: '{}'),
        same(BrandPalette.clinicalTeal),
      );
      // Custom colours without `custom` selected are not applied by accident.
      expect(
        BrandPalette.resolve(
          presetId: '',
          customColorsJson: '{"brandPrimary":"#123456"}',
        ),
        same(BrandPalette.clinicalTeal),
      );
    });
  });
}
