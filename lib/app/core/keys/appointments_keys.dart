import 'package:flutter/widgets.dart';

/// Widget keys for the appointments board.
abstract final class AppointmentsKeys {
  static const screen = Key('appointments_screen');
  static const list = Key('appointments_list');
  static const search = Key('appointments_search');
  static const filters = Key('appointments_filters');
  static const datePicker = Key('appointments_date');
  static const createButton = Key('appointments_create');
  static const empty = Key('appointments_empty');
  static const error = Key('appointments_error');

  static Key row(String id) => Key('appointments_row_$id');
  static Key filter(String id) => Key('appointments_filter_$id');
}
