import 'package:flutter/widgets.dart';

/// Widget keys for the two-step screening form and its edit variant.
///
/// One file for three screens because they are one form: step two validates
/// against what step one collected, and the edit screen reuses both. Keeping
/// their keys together is what stops the three drifting apart.
abstract final class ScreeningKeys {
  // ── Step 1: who ───────────────────────────────────────────────────────────
  static const step1 = Key('screening_step1_screen');
  static const nameField = Key('screening_name');
  static const lastNameField = Key('screening_last_name');
  static const ageField = Key('screening_age');
  static const sexPicker = Key('screening_sex');

  /// One per segment of [sexPicker]. A segmented control is three targets in
  /// one widget, and a test that taps it by position breaks the day a site
  /// adds a fourth.
  static Key sexOption(String value) => Key('screening_sex_$value');
  static const phoneField = Key('screening_phone');
  static const mrnField = Key('screening_mrn');
  static const step1Next = Key('screening_step1_next');

  // ── Step 2: what ──────────────────────────────────────────────────────────
  static const step2 = Key('screening_step2_screen');
  static const complaintField = Key('screening_complaint');
  static const acuityPicker = Key('screening_acuity');
  static const temperatureField = Key('screening_temperature');
  static const pulseField = Key('screening_pulse');
  static const bpSystolicField = Key('screening_bp_systolic');
  static const bpDiastolicField = Key('screening_bp_diastolic');
  static const spo2Field = Key('screening_spo2');
  static const respiratoryField = Key('screening_respiratory');
  static const notesField = Key('screening_notes');
  static const step2Back = Key('screening_step2_back');
  static const submit = Key('screening_submit');
  static const error = Key('screening_error');

  // ── Edit ──────────────────────────────────────────────────────────────────
  static const edit = Key('screening_edit_screen');
  static const editSave = Key('screening_edit_save');
}
