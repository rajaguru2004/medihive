import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_fonts.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — Centralised Typography
///
/// One scale, eleven steps, borrowed from Apple's HIG because it is the scale
/// both target platforms' users already read at:
///
///   largeTitle 34 → title1 28 → title2 22 → title3 20 → headline 17
///   → body 17 → callout 16 → subheadline 15 → footnote 13
///   → caption1 12 → caption2 11
///
/// Each step exists in a light and a dark variant, differing only in colour,
/// so a widget picks by brightness and never hand-mixes a text colour.
///
/// Figures are the exception worth knowing about: use [vital], [money] or
/// [AppFonts.numeric] for anything that lines up in a column or ticks. A
/// proportional `7` is narrower than a `0` in every face in the registry, so a
/// column of observations set in body text visibly shivers as it refreshes —
/// and a heart rate that shivers is a heart rate a clinician reads twice.
/// ─────────────────────────────────────────────────────────────────────────────
abstract class AppTextStyles {
  // ── Light theme ───────────────────────────────────────────────────────────
  static TextStyle lightLargeTitle({FontWeight weight = FontWeight.w700}) =>
      AppFonts.text(
        fontSize: 34,
        fontWeight: weight,
        color: AppColors.lightTextPrimary,
        letterSpacing: -0.5,
      );

  static TextStyle lightTitle1({FontWeight weight = FontWeight.w700}) =>
      AppFonts.text(
        fontSize: 28,
        fontWeight: weight,
        color: AppColors.lightTextPrimary,
        letterSpacing: -0.3,
      );

  static TextStyle lightTitle2({FontWeight weight = FontWeight.w600}) =>
      AppFonts.text(
        fontSize: 22,
        fontWeight: weight,
        color: AppColors.lightTextPrimary,
        letterSpacing: -0.2,
      );

  static TextStyle lightTitle3({FontWeight weight = FontWeight.w600}) =>
      AppFonts.text(
        fontSize: 20,
        fontWeight: weight,
        color: AppColors.lightTextPrimary,
      );

  static TextStyle lightHeadline({FontWeight weight = FontWeight.w600}) =>
      AppFonts.text(
        fontSize: 17,
        fontWeight: weight,
        color: AppColors.lightTextPrimary,
      );

  static TextStyle lightBody({FontWeight weight = FontWeight.w400}) =>
      AppFonts.text(
        fontSize: 17,
        fontWeight: weight,
        color: AppColors.lightTextPrimary,
      );

  static TextStyle lightCallout({FontWeight weight = FontWeight.w400}) =>
      AppFonts.text(
        fontSize: 16,
        fontWeight: weight,
        color: AppColors.lightTextSecondary,
      );

  static TextStyle lightSubheadline({FontWeight weight = FontWeight.w400}) =>
      AppFonts.text(
        fontSize: 15,
        fontWeight: weight,
        color: AppColors.lightTextSecondary,
      );

  static TextStyle lightFootnote({FontWeight weight = FontWeight.w400}) =>
      AppFonts.text(
        fontSize: 13,
        fontWeight: weight,
        color: AppColors.lightTextTertiary,
      );

  static TextStyle lightCaption1({FontWeight weight = FontWeight.w400}) =>
      AppFonts.text(
        fontSize: 12,
        fontWeight: weight,
        color: AppColors.lightTextTertiary,
      );

  static TextStyle lightCaption2({FontWeight weight = FontWeight.w400}) =>
      AppFonts.text(
        fontSize: 11,
        fontWeight: weight,
        color: AppColors.lightTextTertiary,
        letterSpacing: 0.06,
      );

  // ── Dark theme ────────────────────────────────────────────────────────────
  static TextStyle darkLargeTitle({FontWeight weight = FontWeight.w700}) =>
      AppFonts.text(
        fontSize: 34,
        fontWeight: weight,
        color: AppColors.darkTextPrimary,
        letterSpacing: -0.5,
      );

  static TextStyle darkTitle1({FontWeight weight = FontWeight.w700}) =>
      AppFonts.text(
        fontSize: 28,
        fontWeight: weight,
        color: AppColors.darkTextPrimary,
        letterSpacing: -0.3,
      );

  static TextStyle darkTitle2({FontWeight weight = FontWeight.w600}) =>
      AppFonts.text(
        fontSize: 22,
        fontWeight: weight,
        color: AppColors.darkTextPrimary,
        letterSpacing: -0.2,
      );

  static TextStyle darkTitle3({FontWeight weight = FontWeight.w600}) =>
      AppFonts.text(
        fontSize: 20,
        fontWeight: weight,
        color: AppColors.darkTextPrimary,
      );

  static TextStyle darkHeadline({FontWeight weight = FontWeight.w600}) =>
      AppFonts.text(
        fontSize: 17,
        fontWeight: weight,
        color: AppColors.darkTextPrimary,
      );

  static TextStyle darkBody({FontWeight weight = FontWeight.w400}) =>
      AppFonts.text(
        fontSize: 17,
        fontWeight: weight,
        color: AppColors.darkTextPrimary,
      );

  static TextStyle darkCallout({FontWeight weight = FontWeight.w400}) =>
      AppFonts.text(
        fontSize: 16,
        fontWeight: weight,
        color: AppColors.darkTextSecondary,
      );

  static TextStyle darkSubheadline({FontWeight weight = FontWeight.w400}) =>
      AppFonts.text(
        fontSize: 15,
        fontWeight: weight,
        color: AppColors.darkTextSecondary,
      );

  static TextStyle darkFootnote({FontWeight weight = FontWeight.w400}) =>
      AppFonts.text(
        fontSize: 13,
        fontWeight: weight,
        color: AppColors.darkTextTertiary,
      );

  static TextStyle darkCaption1({FontWeight weight = FontWeight.w400}) =>
      AppFonts.text(
        fontSize: 12,
        fontWeight: weight,
        color: AppColors.darkTextTertiary,
      );

  static TextStyle darkCaption2({FontWeight weight = FontWeight.w400}) =>
      AppFonts.text(
        fontSize: 11,
        fontWeight: weight,
        color: AppColors.darkTextTertiary,
        letterSpacing: 0.06,
      );

  // ── Figures ───────────────────────────────────────────────────────────────

  /// A money figure: tabular, tight, and weighted to carry a row. Billing
  /// screens only — a clinical figure is [vital].
  ///
  /// [size] 28 and up is a hero total; 17 is a list row; 13 is a sub-line.
  static TextStyle money(
    Brightness brightness, {
    double size = 17,
    FontWeight weight = FontWeight.w700,
    Color? color,
  }) =>
      AppFonts.numeric(
        fontSize: size,
        fontWeight: weight,
        color: color ??
            (brightness == Brightness.dark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary),
        letterSpacing: size >= 28 ? -1.0 : -0.2,
        height: 1.05,
      );

  /// An observation: a heart rate, a temperature, a bed count, a wait time.
  ///
  /// Tabular like [money], and for the same reason, but never the money
  /// weight: a figure a clinician acts on is set in the primary ink at the
  /// weight of the row it sits in, so the *colour* is free to carry acuity.
  /// A vital rendered bold **and** red reads as two alarms.
  ///
  /// [size] 28 and up is a hero count; 17 is a card figure; 13 is a sub-line.
  static TextStyle vital(
    Brightness brightness, {
    double size = 17,
    FontWeight weight = FontWeight.w600,
    Color? color,
  }) =>
      AppFonts.numeric(
        fontSize: size,
        fontWeight: weight,
        color: color ??
            (brightness == Brightness.dark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary),
        letterSpacing: size >= 28 ? -0.9 : -0.2,
        height: 1.05,
      );

  /// The unit beside a [vital] — `bpm`, `°C`, `beds`, `min`.
  ///
  /// Always a step down and always tertiary: the number is the reading, the
  /// unit is the label on the axis. Set at the same weight as the figure it
  /// follows, so the pair reads as one object rather than as a figure with a
  /// tag stuck on it.
  static TextStyle unit(
    Brightness brightness, {
    double size = 13,
    Color? color,
  }) =>
      AppFonts.text(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color ??
            (brightness == Brightness.dark
                ? AppColors.darkTextTertiary
                : AppColors.lightTextTertiary),
        letterSpacing: 0,
        height: 1.05,
      );

  /// An all-caps micro label above a figure or a group. The only place in the
  /// app where letter-spacing is opened up.
  static TextStyle overline(
    Brightness brightness, {
    Color? color,
  }) =>
      AppFonts.text(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: color ??
            (brightness == Brightness.dark
                ? AppColors.darkTextTertiary
                : AppColors.lightTextTertiary),
        letterSpacing: 0.7,
      );
}
