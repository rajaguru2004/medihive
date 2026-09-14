import 'package:get/get.dart';

import '../models/case_review.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — what the phone remembers about this patient's own case
///
/// Two small things the API cannot answer on its own, and nothing else.
///
/// ## 1. Which case was sent
///
/// `GET /case-taking/sessions/current` finds a session in `in_progress` or
/// `review`, so the moment a case is submitted it answers **null** — the same
/// answer it gives a patient who never started one. The dashboard has to tell
/// those two apart (§39: the dashboard shows the case as submitted), and the
/// only party that knows is the screen that pressed Send.
///
/// So the receipt is held here, in memory, for as long as this session lasts.
/// Deliberately not on disk: this is a summary of somebody's medical history,
/// the phone may be a hospital tablet, and the app's own rule is that case data
/// lives on the server with secure storage as the only exception. A patient who
/// force-quits the app loses the "we sent this" card and nothing else — the
/// submission itself is safe, and starting a new interview is the right next
/// action anyway.
///
/// ## 2. Which fact id belongs to which field
///
/// `PATCH /sessions/:sessionId/facts/:factId` is the route written for a
/// correction, and the review document does not carry fact ids — so a screen
/// that has only ever loaded the review cannot address it. Every *turn*
/// response does carry one, though, so anything that submits a turn can leave
/// the id here and the review screen picks it up. That is the seam between the
/// interview and the review: the interview module calls [rememberFact] after
/// each turn it accepts, the review reads [factIdFor], and neither imports the
/// other.
///
/// Scoped to the signed-in patient. `SessionManager.registerScoped` drops it on
/// sign-out, because a shared tablet handed to the next patient must not carry
/// the previous one's case with it.
/// ─────────────────────────────────────────────────────────────────────────────
class PatientCaseService extends GetxService {
  static PatientCaseService get to => Get.find<PatientCaseService>();

  /// The case this device sent, if it sent one.
  final Rxn<CaseSubmissionReceipt> submission = Rxn<CaseSubmissionReceipt>();

  /// `sessionId:fieldPath` → the id of the fact currently standing for it.
  ///
  /// Keyed on the session too, so a second interview cannot inherit the first
  /// one's ids and correct a fact that belongs to a case already sent.
  final Map<String, String> _facts = {};

  bool get hasSubmitted => submission.value != null;

  /// Records the receipt for a case just sent.
  void recordSubmission(CaseSubmissionReceipt receipt) {
    submission.value = receipt;
    // Every id learned during that interview is now pointing at facts on a
    // session the server will refuse to change. Dropped rather than left to
    // produce a 409 that reads to a patient as the app being broken.
    _facts.removeWhere((key, _) => key.startsWith('${receipt.sessionId}:'));
  }

  /// Notes which fact currently stands for [fieldPath].
  ///
  /// Called by anything that submits a turn or a correction. A later id
  /// replaces an earlier one, which is right: the fact chain is append-only
  /// and only the newest link is correctable — the server refuses a correction
  /// to a superseded row with a sentence saying so.
  void rememberFact({
    required String sessionId,
    required String fieldPath,
    required String factId,
  }) {
    if (sessionId.isEmpty || fieldPath.isEmpty || factId.isEmpty) return;
    _facts['$sessionId:$fieldPath'] = factId;
  }

  /// The fact id for a field, or null when this device has not seen one.
  ///
  /// Null is the ordinary case on a freshly opened review screen and is not a
  /// failure — `CaseReviewRepository.correctItem` has a route that works
  /// without it.
  String? factIdFor({required String sessionId, required String fieldPath}) =>
      _facts['$sessionId:$fieldPath'];

  /// Forgets everything. For a sign-out, and for a test that wants a clean
  /// slate without rebuilding the service.
  void clear() {
    submission.value = null;
    _facts.clear();
  }
}
