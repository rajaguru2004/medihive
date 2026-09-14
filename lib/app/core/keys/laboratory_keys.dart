import 'package:flutter/widgets.dart';

/// Widget keys for the whole laboratory: the worklist, an order, a result and
/// the catalogue behind them.
///
/// One namespace across six modules rather than six, because they are six
/// views of one workflow — an order number appears on the worklist row, again
/// on the order it opens, and again on the result form launched from it, so a
/// parallel set of keys per screen is how two views of one object drift until
/// a test passes against a screen nobody sees.
abstract final class LaboratoryKeys {
  // ── The worklist ──────────────────────────────────────────────────────────

  static const screen = Key('laboratory_screen');
  static const stats = Key('laboratory_stats');
  static const search = Key('laboratory_search');
  static const statusFilters = Key('laboratory_status_filters');
  static const priorityFilters = Key('laboratory_priority_filters');
  static const list = Key('laboratory_list');
  static const empty = Key('laboratory_empty');
  static const createOrder = Key('laboratory_create_order');
  static const openCatalog = Key('laboratory_open_catalog');
  static const listPane = Key('laboratory_list_pane');
  static const detailPane = Key('laboratory_detail_pane');
  static const paneOpen = Key('laboratory_pane_open');
  static const clearFilters = Key('laboratory_clear_filters');

  static Key row(String id) => Key('laboratory_row_$id');
  static Key filterOption(String field, String value) =>
      Key('laboratory_filter_${field}_$value');

  // ── A new order ───────────────────────────────────────────────────────────

  static const orderFormScreen = Key('lab_order_form_screen');
  static const orderPatient = Key('lab_order_form_patient');
  static const orderAddTests = Key('lab_order_form_add_tests');
  static const orderIndication = Key('lab_order_form_indication');
  static const orderDiagnosis = Key('lab_order_form_diagnosis');
  static const orderNotes = Key('lab_order_form_notes');
  static const orderSubmit = Key('lab_order_form_submit');

  static Key orderPriority(String priority) =>
      Key('lab_order_form_priority_$priority');

  /// A test already on the order being written.
  static Key orderTest(String testId) => Key('lab_order_form_test_$testId');

  /// One option of that test's own urgency control.
  static Key orderTestUrgency(String testId, String urgency) =>
      Key('lab_order_form_urgency_${testId}_$urgency');

  static Key orderRemoveTest(String testId) =>
      Key('lab_order_form_remove_$testId');

  /// A row in the catalogue sheet the order picks tests from.
  static Key catalogPick(String testId) => Key('lab_order_pick_$testId');
  static const catalogPickDone = Key('lab_order_pick_done');
  static Key catalogPickCategory(String category) =>
      Key('lab_order_pick_category_$category');

  // ── One order ─────────────────────────────────────────────────────────────

  static const orderDetailScreen = Key('lab_order_detail_screen');
  static const collectSample = Key('lab_order_collect');
  static const rejectSample = Key('lab_order_reject');
  static const completeOrder = Key('lab_order_complete');
  static const criticalBanner = Key('lab_order_critical_banner');
  static const accessionField = Key('lab_order_accession_field');
  static const accessionConfirm = Key('lab_order_accession_confirm');
  static const rejectReasonField = Key('lab_order_reject_reason');
  static const rejectConfirm = Key('lab_order_reject_confirm');

  /// The row for one ordered test, whether or not it has a result yet.
  static Key orderedTest(String testId) => Key('lab_order_test_$testId');
  static Key enterResult(String testId) => Key('lab_order_enter_result_$testId');
  static Key resultRow(String resultId) => Key('lab_result_$resultId');
  static Key verifyResult(String resultId) => Key('lab_result_verify_$resultId');

  // ── A result ──────────────────────────────────────────────────────────────

  static const resultFormScreen = Key('lab_result_form_screen');
  static const resultValue = Key('lab_result_form_value');
  static const resultUnit = Key('lab_result_form_unit');
  static const resultAbnormal = Key('lab_result_form_abnormal');
  static const resultCritical = Key('lab_result_form_critical');
  static const resultComment = Key('lab_result_form_comment');
  static const resultSubmit = Key('lab_result_form_submit');
  static const resultReference = Key('lab_result_form_reference');

  static Key resultFlag(String flag) => Key('lab_result_form_flag_$flag');

  // ── The catalogue ─────────────────────────────────────────────────────────

  static const catalogScreen = Key('lab_catalog_screen');
  static const catalogSearch = Key('lab_catalog_search');
  static const catalogFilter = Key('lab_catalog_filter');
  static const catalogAdd = Key('lab_catalog_add');
  static const catalogEmpty = Key('lab_catalog_empty');

  static Key catalogRow(String id) => Key('lab_catalog_row_$id');
  static Key catalogCategory(String category) =>
      Key('lab_catalog_category_$category');

  // ── A catalogue entry ─────────────────────────────────────────────────────

  static const testFormScreen = Key('lab_test_form_screen');
  static const testName = Key('lab_test_form_name');
  static const testCode = Key('lab_test_form_code');
  static const testCategory = Key('lab_test_form_category');
  static const testType = Key('lab_test_form_type');
  static const testSpecimen = Key('lab_test_form_specimen');
  static const testResultType = Key('lab_test_form_result_type');
  static const testUnit = Key('lab_test_form_unit');
  static const testRanges = Key('lab_test_form_ranges');
  static const testPrice = Key('lab_test_form_price');
  static const testTurnaround = Key('lab_test_form_turnaround');
  static const testPreparation = Key('lab_test_form_preparation');
  static const testActive = Key('lab_test_form_active');
  static const testSave = Key('lab_test_form_save');
}
