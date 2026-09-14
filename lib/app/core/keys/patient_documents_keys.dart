import 'package:flutter/widgets.dart';

/// Widget keys for the two document screens a patient sees: the list they add
/// to, and the review of one document that was read for them.
///
/// One file for both, the way `PatientPortalKeys` is one file for five: they
/// are one task. A patient photographs a prescription and then checks what was
/// read out of it, and a flow walking that has no business holding two key sets
/// to do it.
///
/// Most of these are per-field rather than per-index. A review screen's rows
/// come from an extraction, so their order is the document's and not the app's
/// — an assertion aimed at "the second row" is one that starts testing the
/// classifier the first time a prescription lists its medicines in a different
/// order.
abstract final class PatientDocumentsKeys {
  /// The way in, on the patient's dashboard.
  ///
  /// Keyed here rather than in `patient_portal_keys.dart` because it belongs to
  /// this feature: it is the documents module's only entry point, and a flow
  /// that walks from the dashboard into a document should not have to know
  /// which file the dashboard's own keys live in.
  static const Key openFromDashboard = Key('patient_documents_open');

  // ── The list ──────────────────────────────────────────────────────────────

  static const Key screen = Key('patient_documents_screen');
  static const Key list = Key('patient_documents_list');
  static const Key empty = Key('patient_documents_empty');
  static const Key error = Key('patient_documents_error');

  /// The one control on the screen that matters.
  static const Key add = Key('patient_documents_add');

  /// The three ways in, on the sheet [add] opens.
  static const Key addCamera = Key('patient_documents_add_camera');
  static const Key addGallery = Key('patient_documents_add_gallery');
  static const Key addPdf = Key('patient_documents_add_pdf');

  /// The bar that shows a real figure while a file is going up. Keyed because
  /// the assertion worth making is that a *figure* is on screen, not a spinner.
  static const Key uploadProgress = Key('patient_documents_upload_progress');

  /// Inline and persistent, never a toast: the refusal is attached to the file
  /// that was refused, and a size refusal has to stay readable long enough to
  /// act on.
  static const Key uploadError = Key('patient_documents_upload_error');

  static Key document(String id) => Key('patient_documents_row_$id');

  // ── One document, reviewed ────────────────────────────────────────────────

  static const Key review = Key('patient_document_review_screen');
  static const Key reviewError = Key('patient_document_review_error');

  /// The server's own sentence about this document — processing, duplicate,
  /// unreadable, awaiting review.
  ///
  /// Keyed rather than matched on words, because what it must *not* say is the
  /// part that matters: a test that matched on the copy would be the thing
  /// that let an engine's exception text through.
  static const Key message = Key('patient_document_review_message');

  /// §21: the same document twice is reported, not refused.
  static const Key duplicate = Key('patient_document_review_duplicate');

  /// The two measured numbers, each under its own name. Two keys because they
  /// are two measurements and the whole point is that they never merge.
  static const Key ocrConfidence = Key('patient_document_confidence_ocr');
  static const Key extractionConfidence =
      Key('patient_document_confidence_extraction');

  /// The original behind a signed URL.
  static const Key original = Key('patient_document_original');

  /// One extracted value, and the three things a patient can say about it.
  static Key value(String field) => Key('patient_document_value_$field');
  static Key confirmValue(String field) =>
      Key('patient_document_confirm_$field');
  static Key correctValue(String field) =>
      Key('patient_document_correct_$field');
  static Key unsureValue(String field) => Key('patient_document_unsure_$field');

  /// Where a corrected value is typed, and the control that keeps it.
  static const Key correctionField = Key('patient_document_correction_field');
  static const Key correctionSave = Key('patient_document_correction_save');

  /// A topic the document said nothing about — "This document does not mention
  /// allergies".
  ///
  /// Keyed per topic because the assertion this screen most needs is a
  /// negative one: that the allergies line is **this** sentence and not "no
  /// known allergies".
  static Key topic(String name) => Key('patient_document_topic_$name');

  /// The document-level confirmation, and the notice that replaces it when
  /// something on the screen has been marked wrong or uncertain.
  static const Key confirm = Key('patient_document_confirm');
  static const Key confirmBlocked = Key('patient_document_confirm_blocked');
}
