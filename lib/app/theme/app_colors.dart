import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — Centralised Color Palette
///
/// Design Language : Chart & Vitals — a flat, inset-grouped clinical surface
///                   lit by one cool brand colour.
/// Palette Concept : Clinical teal on cool paper (light) and on deep slate
///                   (dark), with a ledger blue for anything billed.
///
/// Light → cool paper ground, white inset surfaces, teal reserved for action
/// Dark  → deep slate ground, raised surfaces, teal lifts off them
///
/// The one rule that shapes everything below: **teal is the brand, never an
/// acuity.** A ward board shows patient state on every row — critical, urgent,
/// standard, stable — and a teal "stable" pill sitting beside a teal primary
/// button makes the brand unreadable as an affordance. Acuity colours
/// therefore live in their own ramp ([acuityCritical] … [acuityDischarged])
/// with no teal in it.
///
/// The second rule, particular to a clinical app: **red means one thing.**
/// Red is reserved for `acuityCritical` and for [error]. It is never a chart
/// series, never a decorative accent, and never a "delete" affordance that is
/// not actually destructive. On a ward board a clinician scans for red; every
/// red that is not a deteriorating patient costs that scan its meaning.
/// ─────────────────────────────────────────────────────────────────────────────
abstract class AppColors {
  // ── Brand ──────────────────────────────────────────────────────────────────
  /// Primary brand — clinical teal. Fills, the active tab, the hero band.
  static const Color primary = Color(0xFF0E7C7B);

  /// Pressed / active state of [primary].
  static const Color primaryDark = Color(0xFF0A5F5E);

  /// Pale wash, for soft fills behind brand elements.
  static const Color primaryLight = Color(0xFFCCE7E6);

  /// Teal darkened until it reads as text on the paper ground (5.5:1).
  ///
  /// Deep teal is closer to legible than the reference amber ever was, but
  /// `#0E7C7B` on `#F4F6F7` is 4.35:1 — under the floor by a hair, which is
  /// exactly the kind of near-miss that ships. Every brand-coloured *word* in
  /// light mode is this; every brand-coloured *fill* is [primary].
  /// `BrandPalette.ink` / `.fill` make that choice for you.
  static const Color primaryInk = Color(0xFF0A5F5E);

  /// Accent — ledger blue. Anything billed that is not a clinical state:
  /// charges, the billing rail, a link out to a bill.
  static const Color accent = Color(0xFF0070C0);
  static const Color accentDark = Color(0xFF005192);

  // ── Semantic ───────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF16A34A);

  /// Amber, deliberately *not* teal and deliberately *not* red — see the notes
  /// at the top of this file. A warning must be distinguishable from both the
  /// brand and a critical patient at a glance.
  static const Color warning = Color(0xFFB45309);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF0070C0);

  // ── Acuity ramp (clinical) ─────────────────────────────────────────────────
  //
  // Mirrors the triage and admission states the backend stores. No teal: these
  // sit inches from the primary button on every queue row and every bed tile.
  // Ordered by urgency, because that is the order a clinician reads them in.

  /// Deteriorating, or triaged as immediate. The only red on a ward board.
  static const Color acuityCritical = Color(0xFFDC2626);

  /// Triaged as urgent — seen soon, not now.
  static const Color acuityUrgent = Color(0xFFEA580C);

  /// The ordinary case: triaged, waiting, nothing flagged.
  static const Color acuityStandard = Color(0xFF0070C0);

  /// Non-urgent, or routine follow-up.
  static const Color acuityRoutine = Color(0xFF64748B);

  /// Observed and stable — the good outcome, still on the board.
  static const Color acuityStable = Color(0xFF16A34A);

  /// Off the board: discharged, transferred out, or cancelled.
  static const Color acuityDischarged = Color(0xFF94A3B8);

  /// Waiting on a clinician's sign-off — a screening submitted but not yet
  /// reviewed.
  ///
  /// Violet rather than the amber this state would naturally suggest: amber is
  /// [warning] here, and "waiting for review" is not a warning. It is a queue
  /// position.
  static const Color acuityReview = Color(0xFF7C3AED);

  // ── Bed states ─────────────────────────────────────────────────────────────
  //
  // A bed grid is read as a map, not as a list, so its states get fills rather
  // than pills — but they are still drawn from the acuity vocabulary so the
  // two views of one ward agree.

  /// Free and cleaned.
  static const Color bedVacant = Color(0xFF16A34A);

  /// Occupied by an admitted patient.
  static const Color bedOccupied = Color(0xFF0070C0);

  /// Reserved against a pending admission.
  static const Color bedReserved = Color(0xFF7C3AED);

  /// Out of service: cleaning, maintenance, or blocked.
  static const Color bedBlocked = Color(0xFF94A3B8);

  // ── Light Theme Surfaces ───────────────────────────────────────────────────
  /// Cool clinical paper. Not the warm paper of a ledger app and not pure
  /// white: a screen a clinician reads for a twelve-hour shift wants the glare
  /// off it, and a card needs somewhere to sit above.
  static const Color lightBackground = Color(0xFFF4F6F7);
  static const Color lightSurface = Color(0xFFFFFFFF);

  /// Translucent card fill, over the ground's ambient wash.
  static const Color lightGlass = Color(0xCCFFFFFF);
  static const Color lightGlassBorder = Color(0x33FFFFFF);

  /// Elevated card (second level).
  static const Color lightCardSurface = Color(0xF0FFFFFF);

  static const Color lightDivider = Color(0x1F0B1416);
  static const Color lightShadow = Color(0x140A1214);

  // ── Light Theme Text ───────────────────────────────────────────────────────
  static const Color lightTextPrimary = Color(0xFF0B1416);
  static const Color lightTextSecondary = Color(0xFF54605F);
  static const Color lightTextTertiary = Color(0xFF87918F);
  static const Color lightTextOnPrimary = Color(0xFFFFFFFF);

  // ── Dark Theme Surfaces ────────────────────────────────────────────────────
  /// Deep slate — not pure black, so a raised surface has somewhere to go, and
  /// so a night-shift screen does not smear on an OLED panel the way pure
  /// black does when it scrolls.
  static const Color darkBackground = Color(0xFF0C1114);
  static const Color darkSurface = Color(0xFF151B1F);

  static const Color darkGlass = Color(0xBF171E23);

  /// 8% white. A 20% edge (the light-theme value) reads as an outlined box on
  /// slate rather than as a frosted pane.
  static const Color darkGlassBorder = Color(0x14FFFFFF);

  static const Color darkCardSurface = Color(0xD91D252A);

  static const Color darkDivider = Color(0x40606B70);
  static const Color darkShadow = Color(0x66000000);

  // ── Dark Theme Text ────────────────────────────────────────────────────────
  static const Color darkTextPrimary = Color(0xFFE8EDEC);

  /// 7.5:1 on a dark card. Every subtitle and hint in the app is set in it, so
  /// this one value decides whether dark mode reads as designed or as dim.
  static const Color darkTextSecondary = Color(0xFFA7B0AF);

  /// 5.0:1 on a dark card — above the 4.5:1 floor this app holds itself to
  /// everywhere else, because a footnote on a ward board is still something a
  /// clinician has to read at arm's length.
  static const Color darkTextTertiary = Color(0xFF8B9593);
  static const Color darkTextOnPrimary = Color(0xFFFFFFFF);

  // ── Gradient Presets ──────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0E7C7B), Color(0xFF17A2A0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF0070C0), Color(0xFF00A3E0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// The good-outcome gradient, for a "stable" or "discharged today" hero
  /// figure.
  static const LinearGradient settledGradient = LinearGradient(
    colors: [Color(0xFF16A34A), Color(0xFF34D07F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkBackgroundGradient = LinearGradient(
    colors: [Color(0xFF0C1114), Color(0xFF121A1E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient lightBackgroundGradient = LinearGradient(
    colors: [Color(0xFFF4F6F7), Color(0xFFE9EDEE)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
