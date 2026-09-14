import 'package:flutter/widgets.dart';

/// Widget keys for the patient register.
///
/// The register is the one list in this app whose rows a test cannot name by
/// their text: a patient's name appears on the row, again on the hub it opens,
/// and a third time in the identity band of whatever the hub opens next.
abstract final class PatientsKeys {
  static const screen = Key('patients_screen');
  static const list = Key('patients_list');
  static const search = Key('patients_search');
  static const sortButton = Key('patients_sort_button');
  static const empty = Key('patients_empty');
  static const error = Key('patients_error');

  /// Absent, not disabled, for an account without `patients.create`.
  static const registerButton = Key('patients_register_button');

  /// Opens the global lookup.
  static const searchButton = Key('patients_search_button');

  /// The two halves of the tablet layout, so a flow can say which pane it
  /// means when the same row key exists in both.
  static const listPane = Key('patients_list_pane');
  static const detailPane = Key('patients_detail_pane');

  static Key row(String id) => Key('patients_row_$id');

  /// `all`, `active`, `inactive`.
  static Key statusFilter(String value) => Key('patients_status_$value');

  /// Keyed by the backend field the order sends, plus its direction — two
  /// orders on `createdAt` are two rows in the sheet.
  static Key sortOption(String field, {required bool descending}) =>
      Key('patients_sort_${field}_${descending ? 'desc' : 'asc'}');
}
