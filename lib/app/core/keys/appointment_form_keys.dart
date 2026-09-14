import 'package:flutter/widgets.dart';

/// Widget keys for the booking form — the screen that creates an appointment
/// and the screen that edits one, which are the same screen.
///
/// `find.text` cannot drive this form: "Today" is on the date sheet and on the
/// clinic board behind it, and every slot in the time sheet is four characters
/// that also appear in the list underneath.
abstract final class AppointmentFormKeys {
  static const screen = Key('appointment_form_screen');

  static const patient = Key('appointment_form_patient');
  static const doctor = Key('appointment_form_doctor');
  static const date = Key('appointment_form_date');
  static const time = Key('appointment_form_time');
  static const complaint = Key('appointment_form_complaint');
  static const notes = Key('appointment_form_notes');

  static const save = Key('appointment_form_save');

  /// The inline failure above the save bar — a refused write, or a server that
  /// rejected the booking.
  static const error = Key('appointment_form_error');

  /// Shown instead of the save bar when this account may not write here.
  static const noAccess = Key('appointment_form_no_access');

  /// One slot in the time sheet. Keyed by its stored `"HH:mm"`, which is also
  /// what the request carries — so a flow asserting the payload and a flow
  /// choosing the slot are naming the same thing.
  static Key slot(String time) => Key('appointment_form_slot_$time');

  static Key duration(int minutes) =>
      Key('appointment_form_duration_$minutes');

  static Key type(String value) => Key('appointment_form_type_$value');
}
