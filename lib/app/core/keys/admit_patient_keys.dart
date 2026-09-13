import 'package:flutter/widgets.dart';

/// Widget keys for admitting a patient.
abstract final class AdmitPatientKeys {
  static const screen = Key('admit_patient_screen');
  static const patientPicker = Key('admit_patient_patient');
  static const wardPicker = Key('admit_patient_ward');
  static const bedPicker = Key('admit_patient_bed');
  static const consultantPicker = Key('admit_patient_consultant');
  static const reasonField = Key('admit_patient_reason');
  static const acuityPicker = Key('admit_patient_acuity');
  static const submit = Key('admit_patient_submit');
  static const error = Key('admit_patient_error');
}
