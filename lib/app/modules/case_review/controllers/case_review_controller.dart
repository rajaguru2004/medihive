import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/app_log.dart';
import '../../../core/i18n/patient_text.dart';
import '../../../data/models/case_review.dart';
import '../../../data/models/case_session.dart';
import '../../../data/models/patient_document.dart';
import '../../../data/repositories/case_review_repository.dart';
import '../../../data/repositories/patient_documents_repository.dart';
import '../../../data/services/patient_case_service.dart';
import '../../../data/utils/error_handler.dart';
import '../../../data/utils/load_state.dart';
import '../../../theme/app_bento_conversation.dart' show PatientAnswer;

/// One difference between a document and the record, with the document it came
/// from attached.
///
/// Carried together because the screen has to name both sides *and* say where
/// the document half came from — "your record says X, the prescription you sent
/// says Y" is only actionable if the patient can tell which prescription.
class ReviewContradiction {
  const ReviewContradiction({
    required this.documentId,
    required this.documentKind,
    required this.finding,
  });

  final String documentId;
  final DocumentKind documentKind;
  final DocumentContradiction finding;

  /// Stable across reloads, so a key aimed at one row keeps pointing at it.
  String get id => '$documentId.${finding.topic.wireValue}.'
      '${finding.documentValue.hashCode.toUnsigned(20)}';
}

/// "Here is what we understood about you."
///
/// The last screen before a case leaves the phone, and the one with the most
/// ways to be quietly wrong. Four things it is careful about:
///
///  * **Nothing here is a diagnosis (§43).** The engine's field registry has no
///    `diagnosis` field, the safety view carries a routing sentence and a
///    count rather than the rules that fired, and this controller has no code
///    that could assemble one. The property is structural.
///
///  * **The states stay separate.** An item's presence arrives as one of six
///    and is printed as one of six. There is no `?? false`, no `isEmpty` check
///    standing in for "the patient said no", and no branch that treats "nobody
///    asked" as an answer.
///
///  * **A contradiction is surfaced and never resolved (§20, §33).** Both
///    values are shown and neither is written anywhere. The app has no route
///    that could overwrite one with the other, and would not use it if it had.
///
///  * **A submitted case is read-only.** Every write on this screen is a 409
///    on the server once the case has gone, so the controls go rather than
///    being offered and refused.
class CaseReviewController extends GetxController with LoadStateMixin {
  CaseReviewController() {
    if (!Get.isRegistered<PatientCaseService>()) {
      Get.put(PatientCaseService(), permanent: true);
    }
  }

  final CaseReviewRepository _repository = const CaseReviewRepository();
  final PatientDocumentsRepository _documents =
      PatientDocumentsRepositories.instance;

  final Rx<CaseReview> review = CaseReview.empty.obs;

  /// Differences between what the patient's documents say and what the hospital
  /// already holds.
  ///
  /// Read off **all** of this patient's documents rather than only the ones
  /// attached to this interview. A contradiction is between a document and the
  /// record, and it is worth the patient's attention whichever sitting they
  /// happened to photograph it in — scoping it to the session would hide every
  /// finding from a prescription added from the dashboard.
  final RxList<ReviewContradiction> contradictions = <ReviewContradiction>[].obs;

  /// The interview this screen is showing.
  final RxString sessionId = ''.obs;

  /// Which line is being corrected, if any. One at a time.
  final RxnString editingField = RxnString();
  final TextEditingController correctionText = TextEditingController();

  /// Lines the patient has looked at and agreed with **on this device**.
  ///
  /// Held here rather than trusted as a server fact. Whether a line is
  /// confirmed *on the record* is `item.verification`, which only the server
  /// sets and which is what the row's wording follows; this set is the review
  /// pass's own bookkeeping, so the patient can see which lines they have got
  /// through. The two are never mixed: an unconfirmed value is never drawn
  /// like a confirmed one because a tap happened.
  final RxSet<String> checked = <String>{}.obs;

  final RxBool isSaving = false.obs;
  final RxBool isSubmitting = false.obs;
  final RxnString actionError = RxnString();

  PatientCaseService get _cases => PatientCaseService.to;

  /// The receipt for this case, once it has been sent.
  CaseSubmissionReceipt? get receipt => _cases.submission.value;

  @override
  void onReady() {
    super.onReady();
    unawaited(reload());
  }

  @override
  void onClose() {
    correctionText.dispose();
    super.onClose();
  }

  /// Resolves the session, reads the review, and looks for contradictions.
  ///
  /// **Not `refresh()`** — `GetxController` owns that name.
  Future<void> reload() async {
    await runGuarded(
      () async {
        final resolved = await _resolveSessionId();
        if (resolved.isEmpty) {
          review.value = CaseReview.empty;
          return;
        }
        sessionId.value = resolved;
        review.value = await _repository.review(resolved);
      },
      fallback: PatientText.couldNotLoadReview,
    );
    await _loadContradictions();
  }

  /// Which interview to show.
  ///
  /// The argument wins — the interview hands the id over when it finishes, and
  /// a case that has already been submitted is only reachable that way, because
  /// `sessions/current` finds open sessions and a submitted one is not open.
  /// Falling back to "the one you have open" is what makes this screen
  /// reachable from the dashboard.
  Future<String> _resolveSessionId() async {
    final arguments = Get.arguments;
    if (arguments is Map && arguments['sessionId'] != null) {
      return '${arguments['sessionId']}';
    }
    if (sessionId.value.isNotEmpty) return sessionId.value;

    final submitted = _cases.submission.value;
    if (submitted != null) return submitted.sessionId;

    final current = await _repository.currentSession();
    return current?.id ?? '';
  }

  /// A failure here must not blank the case.
  ///
  /// The review is the screen; the contradictions are an addition to it. A
  /// documents route that is slow or refused should cost the patient a warning
  /// they did not get, not the answers they came to check.
  Future<void> _loadContradictions() async {
    try {
      final documents = await _documents.mine();
      contradictions.value = [
        for (final document in documents)
          for (final finding
              in document.extraction?.contradictions ?? const <DocumentContradiction>[])
            ReviewContradiction(
              documentId: document.id,
              documentKind: document.kind,
              finding: finding,
            ),
      ];
    } catch (e, stack) {
      AppLog.error('$runtimeType', 'reading documents for contradictions', e,
          stack);
      contradictions.clear();
    }
  }

  // ── What is on screen ─────────────────────────────────────────────────────

  bool get isSubmitted => review.value.isSubmitted || receipt != null;

  /// Whether this screen may change anything.
  ///
  /// False once the case has gone. Every write would be a 409 with a sentence
  /// saying so, and a control that exists to be refused is a control that
  /// teaches somebody the screen is broken.
  bool get canEdit => !isSubmitted && sessionId.value.isNotEmpty;

  bool isChecked(String fieldPath) => checked.contains(fieldPath);

  // ── Changing a line ───────────────────────────────────────────────────────

  /// "Yes, that is right."
  ///
  /// Goes to the server **when this device knows which fact the line stands
  /// for** — the correction route marks a re-asserted value `patient_confirmed`
  /// and that is a real record of the patient agreeing. The review document
  /// carries no fact ids, so on a freshly opened screen there is usually
  /// nothing to address; the tap is then kept here instead, and the line's
  /// wording still follows the server's own `verification` rather than the tap.
  /// Claiming otherwise would be the one thing this screen must not do.
  Future<void> confirmItem(CaseReviewItem item) async {
    checked.add(item.fieldPath);
    if (!canEdit) return;

    final factId = _cases.factIdFor(
      sessionId: sessionId.value,
      fieldPath: item.fieldPath,
    );
    if (factId == null) return;

    await _write(() async {
      final result = await _repository.correctItem(
        sessionId: sessionId.value,
        fieldPath: item.fieldPath,
        knownFactId: factId,
        text: item.value ?? item.display,
      );
      _remember(result);
    });
  }

  void startCorrecting(CaseReviewItem item) {
    editingField.value = item.fieldPath;
    correctionText.text = item.value ?? '';
  }

  void cancelCorrecting() {
    editingField.value = null;
    correctionText.clear();
  }

  /// The patient's own wording, filed as a correction.
  Future<void> saveCorrection() async {
    final fieldPath = editingField.value;
    final text = correctionText.text.trim();
    if (fieldPath == null || text.isEmpty || !canEdit) return;

    await _write(() async {
      final result = await _repository.correctItem(
        sessionId: sessionId.value,
        fieldPath: fieldPath,
        knownFactId: _cases.factIdFor(
          sessionId: sessionId.value,
          fieldPath: fieldPath,
        ),
        text: text,
      );
      _remember(result);
      checked.add(fieldPath);
      cancelCorrecting();
    });
  }

  /// A tapped answer on a line nobody has settled — or on one the patient has
  /// changed their mind about.
  ///
  /// Four tiles, four different clinical facts. The token is what travels; the
  /// presence is derived on the server from it, and a "skip" carries its
  /// meaning in the modality rather than in a value, so a skipped question can
  /// never arrive as a denial.
  Future<void> answer(CaseReviewItem item, PatientAnswer answered) async {
    if (!canEdit) return;

    final option = switch (answered) {
      PatientAnswer.yes => CaseAnswerOption(
          token: CaseChoiceTokens.yes,
          label: PatientText.yes,
          modality: CaseAnswerModality.choice,
        ),
      PatientAnswer.no => CaseAnswerOption(
          token: CaseChoiceTokens.no,
          label: PatientText.no,
          modality: CaseAnswerModality.choice,
        ),
      PatientAnswer.unknown => CaseAnswerOption.unsure,
      PatientAnswer.skipped => CaseAnswerOption.skip,
    };

    await _write(() async {
      final result = await _repository.answerChoice(
        sessionId: sessionId.value,
        fieldPath: item.fieldPath,
        option: option,
      );
      _remember(result);
      checked.add(item.fieldPath);
    });
  }

  /// "I am not sure about this one." Kept as its own verb because it is the one
  /// answer that must never be folded into "no".
  Future<void> markUnsure(CaseReviewItem item) =>
      answer(item, PatientAnswer.unknown);

  void _remember(CaseFactCorrection result) {
    _cases.rememberFact(
      sessionId: sessionId.value,
      fieldPath: result.fieldPath,
      factId: result.factId,
    );
  }

  /// Runs a write, then re-reads the case so the screen shows what the server
  /// now holds rather than what the phone hoped it would.
  Future<void> _write(Future<void> Function() body) async {
    if (isSaving.value) return;
    isSaving.value = true;
    actionError.value = null;
    try {
      await body();
      review.value = await _repository.review(sessionId.value);
    } catch (e, stack) {
      AppLog.error('$runtimeType', 'changing an answer failed', e, stack);
      actionError.value =
          parseErrorMessage(e, PatientText.couldNotChangeAnswer);
    } finally {
      isSaving.value = false;
    }
  }

  // ── Sending it ────────────────────────────────────────────────────────────

  /// Sends the case to the hospital, and answers whether it arrived.
  ///
  /// Returns a bool so the view raises its toast only on success: a screen that
  /// congratulates somebody over a failed submission is a patient who walks
  /// into a consultation believing the doctor has read their history.
  Future<bool> submit() async {
    if (isSubmitting.value || !canEdit) return false;

    isSubmitting.value = true;
    actionError.value = null;
    try {
      final result = await _repository.submit(sessionId.value);
      _cases.recordSubmission(result);
      // Re-read, so the screen's own copy says `submitted` and the controls go.
      review.value = await _repository.review(sessionId.value);
      return true;
    } catch (e, stack) {
      AppLog.error('$runtimeType', 'submitting the case failed', e, stack);
      actionError.value = parseErrorMessage(e, PatientText.couldNotSendCase);
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }
}
