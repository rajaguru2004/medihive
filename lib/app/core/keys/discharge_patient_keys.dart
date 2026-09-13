import 'package:flutter/widgets.dart';

/// Widget keys for discharging a patient.
abstract final class DischargePatientKeys {
  static const screen = Key('discharge_patient_screen');
  static const summaryField = Key('discharge_summary');
  static const outcomePicker = Key('discharge_outcome');
  static const dateField = Key('discharge_date');
  static const followUpField = Key('discharge_follow_up');
  static const submit = Key('discharge_submit');
  static const confirm = Key('discharge_confirm');
  static const error = Key('discharge_error');
}
