import 'package:flutter/widgets.dart';

/// Widget keys for imaging: the worklist, an order and its report, and the
/// exam catalogue.
///
/// One file for six screens because they are six views of one study — an order
/// named on the worklist must be the same order on the detail and the same
/// order on the report form. A parallel set per module is how two views of one
/// record drift until a test passes against a screen nobody sees.
abstract final class RadiologyKeys {
  // ── Worklist ──────────────────────────────────────────────────────────────
  static const screen = Key('radiology_screen');
  static const stats = Key('radiology_stats');

  /// The critical-findings banner. Absent — not empty — when nothing is
  /// critical, so its presence is itself the assertion.
  static const critical = Key('radiology_critical_banner');

  static const search = Key('radiology_search');
  static const statusFilters = Key('radiology_status_filters');
  static const urgencyFilters = Key('radiology_urgency_filters');
  static const list = Key('radiology_list');
  static const empty = Key('radiology_empty');
  static const error = Key('radiology_error');

  /// The worklist with nothing on it because this account may not read
  /// imaging. Its own key, because "no orders" and "not your module" are
  /// different answers and a test must not accept one for the other.
  static const locked = Key('radiology_locked');

  static const newOrder = Key('radiology_new_order');
  static const openCatalog = Key('radiology_open_catalog');

  static const listPane = Key('radiology_list_pane');
  static const detailPane = Key('radiology_detail_pane');

  static Key order(String id) => Key('radiology_order_$id');
  static Key statusFilter(String status) => Key('radiology_status_$status');
  static Key urgencyFilter(String urgency) => Key('radiology_urgency_$urgency');

  // ── Order form ────────────────────────────────────────────────────────────
  static const orderForm = Key('radiology_order_form_screen');
  static const orderPatient = Key('radiology_order_patient');
  static const orderExam = Key('radiology_order_exam');
  static const orderUrgency = Key('radiology_order_urgency');
  static const orderIndication = Key('radiology_order_indication');
  static const orderDiagnosis = Key('radiology_order_diagnosis');
  static const orderHistory = Key('radiology_order_history');
  static const orderNotes = Key('radiology_order_notes');

  /// The notice raised when the chosen exam needs contrast. Preparation
  /// changes, so it is a banner rather than a line in the exam's subtitle.
  static const orderContrast = Key('radiology_order_contrast');

  static const orderSubmit = Key('radiology_order_submit');
  static const orderFormError = Key('radiology_order_form_error');
  static const orderFormLoadError = Key('radiology_order_form_load_error');
  static Key orderUrgencyOption(String urgency) =>
      Key('radiology_order_urgency_$urgency');

  // ── Order detail ──────────────────────────────────────────────────────────
  static const orderDetail = Key('radiology_order_detail_screen');

  /// The detail's own critical banner. A key of its own rather than sharing
  /// the worklist's: on a two-pane window both screens are mounted at once,
  /// and one key on two widgets makes every `findsOneWidget` about it fail.
  static const orderCritical = Key('radiology_order_critical_banner');
  static const orderDetailError = Key('radiology_order_detail_error');
  static const orderDetailLocked = Key('radiology_order_detail_locked');
  static const orderTimeline = Key('radiology_order_timeline');

  static const actionSchedule = Key('radiology_action_schedule');
  static const actionStart = Key('radiology_action_start');
  static const actionPerformed = Key('radiology_action_performed');
  static const actionCancel = Key('radiology_action_cancel');
  static const actionReport = Key('radiology_action_report');
  static const actionUpload = Key('radiology_action_upload');

  static const scheduleDate = Key('radiology_schedule_date');
  static const scheduleConfirm = Key('radiology_schedule_confirm');
  static const cancelReason = Key('radiology_cancel_reason');
  static const cancelConfirm = Key('radiology_cancel_confirm');

  static const images = Key('radiology_images');
  static Key image(String url) => Key('radiology_image_$url');

  // ── Report form ───────────────────────────────────────────────────────────
  static const reportForm = Key('radiology_report_form_screen');
  static const reportTechnique = Key('radiology_report_technique');
  static const reportFindings = Key('radiology_report_findings');
  static const reportImpression = Key('radiology_report_impression');
  static const reportRecommendations = Key('radiology_report_recommendations');

  static const reportCritical = Key('radiology_report_critical');
  static const reportCriticalText = Key('radiology_report_critical_text');
  static const reportNotifiedTo = Key('radiology_report_notified_to');

  static const reportComparison = Key('radiology_report_comparison');
  static const reportComparisonNotes =
      Key('radiology_report_comparison_notes');

  static const reportStatus = Key('radiology_report_status');
  static Key reportStatusOption(String status) =>
      Key('radiology_report_status_$status');

  /// Only on screen while an already-final report is being changed. The field
  /// is the record of why a signed read was altered.
  static const reportAmendment = Key('radiology_report_amendment');

  static const reportSave = Key('radiology_report_save');
  static const reportFormError = Key('radiology_report_form_error');

  // ── Catalogue ─────────────────────────────────────────────────────────────
  static const catalog = Key('radiology_catalog_screen');
  static const catalogSearch = Key('radiology_catalog_search');
  static const catalogAdd = Key('radiology_catalog_add');
  static const catalogEmpty = Key('radiology_catalog_empty');
  static Key exam(String id) => Key('radiology_exam_$id');

  // ── Exam form ─────────────────────────────────────────────────────────────
  static const examForm = Key('radiology_exam_form_screen');
  static const examName = Key('radiology_exam_name');
  static const examCode = Key('radiology_exam_code');
  static const examCategory = Key('radiology_exam_category');
  static const examBodyPart = Key('radiology_exam_body_part');
  static const examModality = Key('radiology_exam_modality');
  static const examPrice = Key('radiology_exam_price');
  static const examDuration = Key('radiology_exam_duration');
  static const examContrast = Key('radiology_exam_contrast');
  static const examPreparation = Key('radiology_exam_preparation');
  static const examSave = Key('radiology_exam_save');
  static const examFormError = Key('radiology_exam_form_error');
}
