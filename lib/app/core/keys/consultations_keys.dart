import 'package:flutter/widgets.dart';

/// Widget keys for consultations.
abstract final class ConsultationsKeys {
  static const screen = Key('consultations_screen');
  static const list = Key('consultations_list');
  static const search = Key('consultations_search');
  static const filters = Key('consultations_filters');

  /// The way into a new write-up. Absent for an account that may only read,
  /// which is why a flow needs a key to assert it is not there.
  static const createButton = Key('consultations_create');

  static const empty = Key('consultations_empty');
  static const error = Key('consultations_error');

  static Key row(String id) => Key('consultations_row_$id');
}
