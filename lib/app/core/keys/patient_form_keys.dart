import 'package:flutter/widgets.dart';

/// Widget keys for registering and editing a patient.
abstract final class PatientFormKeys {
  static const screen = Key('patient_form_screen');
  static const form = Key('patient_form');
  static const save = Key('patient_form_save');
  static const error = Key('patient_form_error');
  static const loadError = Key('patient_form_load_error');

  // ── Identity ──────────────────────────────────────────────────────────────
  static const firstName = Key('patient_form_first_name');
  static const middleName = Key('patient_form_middle_name');
  static const lastName = Key('patient_form_last_name');
  static const dateOfBirth = Key('patient_form_dob');
  static const bloodGroup = Key('patient_form_blood_group');

  /// One per option, because a segmented control is three targets in one
  /// widget and a test has to say which.
  static Key sex(String value) => Key('patient_form_sex_$value');

  // ── Contact ───────────────────────────────────────────────────────────────
  static const phonePrimary = Key('patient_form_phone_primary');
  static const phoneSecondary = Key('patient_form_phone_secondary');
  static const email = Key('patient_form_email');
  static const region = Key('patient_form_region');
  static const zone = Key('patient_form_zone');
  static const woreda = Key('patient_form_woreda');
  static const kebele = Key('patient_form_kebele');
  static const houseNumber = Key('patient_form_house_number');
  static const addressDescription = Key('patient_form_address_description');

  // ── Emergency contact ─────────────────────────────────────────────────────
  static const emergencyName = Key('patient_form_emergency_name');
  static const emergencyPhone = Key('patient_form_emergency_phone');
  static const emergencyRelationship = Key('patient_form_emergency_relation');

  // ── Insurance ─────────────────────────────────────────────────────────────
  static const hasInsurance = Key('patient_form_has_insurance');
  static const insuranceProvider = Key('patient_form_insurance_provider');
  static const insuranceId = Key('patient_form_insurance_id');
  static const insuranceExpiry = Key('patient_form_insurance_expiry');

  // ── Clinical ──────────────────────────────────────────────────────────────
  static const allergyField = Key('patient_form_allergy_field');
  static const allergyAdd = Key('patient_form_allergy_add');
  static const conditionField = Key('patient_form_condition_field');
  static const conditionAdd = Key('patient_form_condition_add');
  static const medicationField = Key('patient_form_medication_field');
  static const medicationAdd = Key('patient_form_medication_add');
  static const notes = Key('patient_form_notes');

  /// The status switch, on the edit form only — deactivating is not deleting.
  static const isActive = Key('patient_form_is_active');

  /// A chip in one of the three clinical lists, by list and value.
  static Key chip(String list, String value) =>
      Key('patient_form_chip_${list}_$value');

  // ── The unsaved-changes guard ─────────────────────────────────────────────
  static const discard = Key('patient_form_discard');
  static const keepEditing = Key('patient_form_keep_editing');
}
