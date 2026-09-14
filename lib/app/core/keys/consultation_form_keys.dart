import 'package:flutter/widgets.dart';

/// Widget keys for writing up a consultation — the longest form in the app.
///
/// Its four tabs all live in one `Form`, so every field is in the tree whether
/// or not its tab is showing. That is what makes `validate()` cover the whole
/// document, and it is also why `find.text` cannot be trusted here: the same
/// words are on screen three times over, once per tab that is merely offstage.
abstract final class ConsultationFormKeys {
  static const screen = Key('consultation_form_screen');

  /// One of the four tabs, keyed by its own name.
  static Key tab(String name) => Key('consultation_form_tab_$name');

  // ── Visit ─────────────────────────────────────────────────────────────────
  static const patient = Key('consultation_form_patient');
  static const doctor = Key('consultation_form_doctor');
  static const visitDate = Key('consultation_form_visit_date');
  static Key visitType(String value) =>
      Key('consultation_form_visit_type_$value');

  // ── Vitals ────────────────────────────────────────────────────────────────
  static const temperature = Key('consultation_form_temperature');
  static const systolic = Key('consultation_form_systolic');
  static const diastolic = Key('consultation_form_diastolic');
  static const pulse = Key('consultation_form_pulse');
  static const respiratoryRate = Key('consultation_form_respiratory_rate');
  static const oxygenSaturation = Key('consultation_form_oxygen_saturation');
  static const weight = Key('consultation_form_weight');
  static const height = Key('consultation_form_height');

  /// The sentence over the observations. Keyed apart from the fields because
  /// the unit's colour and the worded warning are two different promises, and
  /// only one of them survives a colour-blind reader or a printed record.
  static const vitalsFlag = Key('consultation_form_vitals_flag');

  // ── Notes, diagnosis and plan ─────────────────────────────────────────────
  static const complaint = Key('consultation_form_complaint');
  static const history = Key('consultation_form_history');
  static const examination = Key('consultation_form_examination');
  static const diagnosis = Key('consultation_form_diagnosis');
  static const icdInput = Key('consultation_form_icd_input');
  static const icdAdd = Key('consultation_form_icd_add');
  static Key icdChip(String code) => Key('consultation_form_icd_$code');
  static const treatmentPlan = Key('consultation_form_plan');

  // ── Prescription ──────────────────────────────────────────────────────────
  static const prescriptionAdd = Key('consultation_form_prescription_add');
  static Key prescriptionDrug(int index) =>
      Key('consultation_form_prescription_drug_$index');
  static Key prescriptionDosage(int index) =>
      Key('consultation_form_prescription_dosage_$index');
  static Key prescriptionFrequency(int index) =>
      Key('consultation_form_prescription_frequency_$index');
  static Key prescriptionDuration(int index) =>
      Key('consultation_form_prescription_duration_$index');
  static Key prescriptionQuantity(int index) =>
      Key('consultation_form_prescription_quantity_$index');
  static Key prescriptionInstructions(int index) =>
      Key('consultation_form_prescription_instructions_$index');
  static Key prescriptionRemove(int index) =>
      Key('consultation_form_prescription_remove_$index');

  // ── Orders ────────────────────────────────────────────────────────────────
  /// The whole orders card. Absent — not disabled — for an account that can
  /// raise neither kind of request.
  static const orders = Key('consultation_form_orders');
  static const labAdd = Key('consultation_form_lab_add');
  static const imagingAdd = Key('consultation_form_imaging_add');
  static Key labTest(String id) => Key('consultation_form_lab_$id');
  static Key imagingExam(String id) => Key('consultation_form_imaging_$id');

  /// Raised when the consultation saved but one of the orders behind it did
  /// not — the record is safe, and the request that failed is named.
  static const ordersFailed = Key('consultation_form_orders_failed');
  static const ordersRetry = Key('consultation_form_orders_retry');

  // ── Follow-up ─────────────────────────────────────────────────────────────
  static const followUpDate = Key('consultation_form_follow_up_date');
  static const followUpInstructions =
      Key('consultation_form_follow_up_instructions');
  static const referredTo = Key('consultation_form_referred_to');
  static const referralReason = Key('consultation_form_referral_reason');
  static const notes = Key('consultation_form_notes');

  // ── The bar ───────────────────────────────────────────────────────────────
  static const save = Key('consultation_form_save');
  static const error = Key('consultation_form_error');
  static const noAccess = Key('consultation_form_no_access');
  static const discard = Key('consultation_form_discard');
  static const keepEditing = Key('consultation_form_keep_editing');
}
