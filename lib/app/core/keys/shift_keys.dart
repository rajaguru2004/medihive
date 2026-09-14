import 'package:flutter/widgets.dart';

/// Widget keys for the shift board — the role-shaped half of the dashboard.
///
/// Separate from `HomeKeys`, which carries the shell's keys and the board's
/// original census anchors. The two files are owned by different streams, and
/// a key added to the wrong one is a merge conflict in the file every flow
/// test imports.
///
/// The band keys are built from a [ShiftSection] id rather than from a
/// position. A board is capped at four bands and which four an account gets
/// depends on its access map, so "the second band" is a different band for a
/// nurse and for a receptionist — and a test that counted positions would
/// assert about whichever one happened to be there.
abstract final class ShiftKeys {
  // ── Freshness ─────────────────────────────────────────────────────────────

  /// "Updated 14:20", under the header.
  static const updatedAt = Key('shift_updated_at');

  /// The notice a failed silent refresh raises over numbers that are still
  /// on screen.
  static const stale = Key('shift_stale');

  // ── Figures and charts ────────────────────────────────────────────────────

  /// The grid of eight. `Figure` is a data class rather than a widget and
  /// carries no key of its own, so a test names a cell by the word on it and
  /// scopes the search to this grid.
  static const figures = Key('shift_figures');

  static const revenue = Key('shift_revenue');
  static const appointmentChart = Key('shift_chart_appointments');
  static const queueChart = Key('shift_chart_queue');

  // ── Quick actions ─────────────────────────────────────────────────────────

  static const quickActions = Key('shift_quick_actions');

  static Key quickAction(String id) => Key('shift_action_$id');

  // ── Bands ─────────────────────────────────────────────────────────────────

  static Key band(String id) => Key('shift_band_$id');

  /// The five states a band can be in, each keyed, because "the band is there"
  /// and "the band is showing what it is for" are different assertions — a
  /// skeleton, a refusal and a list all satisfy the first.
  static Key bandLoading(String id) => Key('shift_band_${id}_loading');
  static Key bandEmpty(String id) => Key('shift_band_${id}_empty');
  static Key bandError(String id) => Key('shift_band_${id}_error');
  static Key bandLocked(String id) => Key('shift_band_${id}_locked');

  static Key bandRow(String band, String row) => Key('shift_row_${band}_$row');

  // ── The board's tail ──────────────────────────────────────────────────────

  static const upcoming = Key('shift_upcoming');
  static const recentPatients = Key('shift_recent_patients');

  static Key appointment(String id) => Key('shift_appointment_$id');
  static Key patient(String id) => Key('shift_patient_$id');
}
