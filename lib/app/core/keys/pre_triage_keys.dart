import 'package:flutter/widgets.dart';

/// Widget keys for the pre-triage board and one screening's detail.
abstract final class PreTriageKeys {
  static const screen = Key('pre_triage_screen');
  static const list = Key('pre_triage_list');
  static const search = Key('pre_triage_search');
  static const filters = Key('pre_triage_filters');
  static const newScreening = Key('pre_triage_new');
  static const empty = Key('pre_triage_empty');
  static const error = Key('pre_triage_error');

  static Key row(String id) => Key('pre_triage_row_$id');
  static Key filter(String id) => Key('pre_triage_filter_$id');

  // ── Detail ────────────────────────────────────────────────────────────────
  static const detail = Key('pre_triage_detail_screen');
  static const detailVitals = Key('pre_triage_detail_vitals');
  static const detailEdit = Key('pre_triage_detail_edit');
  static const detailConvert = Key('pre_triage_detail_convert');
  static const detailError = Key('pre_triage_detail_error');
}
