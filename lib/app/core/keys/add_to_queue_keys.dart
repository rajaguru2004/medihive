import 'package:flutter/widgets.dart';

/// Widget keys for adding somebody to the queue.
abstract final class AddToQueueKeys {
  static const screen = Key('add_to_queue_screen');
  static const patientPicker = Key('add_to_queue_patient');
  static const doctorPicker = Key('add_to_queue_doctor');
  static const departmentPicker = Key('add_to_queue_department');
  static const acuityPicker = Key('add_to_queue_acuity');
  static const reasonField = Key('add_to_queue_reason');
  static const submit = Key('add_to_queue_submit');
  static const error = Key('add_to_queue_error');
}
