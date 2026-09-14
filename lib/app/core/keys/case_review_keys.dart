import 'package:flutter/widgets.dart';

/// Widget keys for "here is what we understood about you" — the last screen a
/// patient sees before their case goes to the hospital.
///
/// Keyed per **field path** rather than per index. The lines on this screen
/// come from the engine's field registry in the registry's own order, and that
/// order changes with the patient: a question that does not apply is not
/// rendered, so "the third row" is a different question for a different
/// person. `hpi.duration` is `hpi.duration` for everybody.
abstract final class CaseReviewKeys {
  /// §39, on the patient's own dashboard: what has happened to their case.
  ///
  /// Present for an interview still open and for one already sent, because
  /// those are the two states the dashboard has to be able to tell apart — and
  /// the second is the one `sessions/current` cannot answer, since a submitted
  /// case is no longer open.
  static const Key dashboardCard = Key('case_review_dashboard_card');
  static const Key openFromDashboard = Key('case_review_dashboard_open');

  static const Key screen = Key('case_review_screen');
  static const Key error = Key('case_review_error');

  /// The two sentences above everything else: what this screen is, and — §43 —
  /// that none of it is a diagnosis.
  static const Key intro = Key('case_review_intro');
  static const Key disclaimer = Key('case_review_disclaimer');

  /// The red flag, when one fired. The same routing sentence the interview
  /// shows, because the rule set's own titles name syndromes.
  static const Key safety = Key('case_review_safety');

  static const Key progress = Key('case_review_progress');

  static Key section(String key) => Key('case_review_section_$key');

  /// One line of the case, and the three things a patient can say about it.
  ///
  /// Three and not two. "I am not sure" is a different clinical fact from
  /// "that is wrong", and a screen that offers only confirm and correct makes
  /// somebody choose between two answers that are both untrue.
  static Key item(String fieldPath) => Key('case_review_item_$fieldPath');
  static Key confirmItem(String fieldPath) =>
      Key('case_review_confirm_$fieldPath');
  static Key correctItem(String fieldPath) =>
      Key('case_review_correct_$fieldPath');
  static Key unsureItem(String fieldPath) =>
      Key('case_review_unsure_$fieldPath');

  static const Key correctionField = Key('case_review_correction_field');
  static const Key correctionSave = Key('case_review_correction_save');

  /// §36's list: every applicable question still unanswered, printed rather
  /// than omitted, because an omitted line reads as nothing to report.
  static const Key missing = Key('case_review_missing');

  /// §33 / §20: a difference between what the patient said and what the
  /// hospital already holds. Both sides on screen, neither overwritten.
  static const Key contradictions = Key('case_review_contradictions');
  static Key contradiction(String id) => Key('case_review_contradiction_$id');

  /// Sending it, and the screen that says it has gone.
  static const Key submit = Key('case_review_submit');
  static const Key submitted = Key('case_review_submitted');
  static const Key submitError = Key('case_review_submit_error');

  /// The banner on a case that has already gone, where every control on the
  /// screen would be a 409.
  static const Key locked = Key('case_review_locked');
}
