import 'package:flutter/widgets.dart';

/// Widget keys for the global patient lookup.
abstract final class PatientSearchKeys {
  static const screen = Key('patient_search_screen');
  static const field = Key('patient_search_field');
  static const results = Key('patient_search_results');
  static const empty = Key('patient_search_empty');
  static const error = Key('patient_search_error');
  static const prompt = Key('patient_search_prompt');

  /// The recents block, and the control that empties it.
  static const recents = Key('patient_search_recents');
  static const clearRecents = Key('patient_search_clear_recents');

  static Key result(String id) => Key('patient_search_result_$id');
  static Key recent(String id) => Key('patient_search_recent_$id');
}
