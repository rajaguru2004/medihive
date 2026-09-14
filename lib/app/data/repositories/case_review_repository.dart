import 'package:get/get.dart' hide Response;

import '../models/case_review.dart';
import '../models/case_session.dart';
import '../models/drafts/case_taking_drafts.dart';
import '../network/dio_client.dart';
import '../network/endpoints.dart';
import '../services/data_bus.dart';
import '../utils/api_envelope.dart';

/// What the review announces on the [DataBus] when a case is sent.
abstract final class CaseReviewEntities {
  /// A submitted case changes what the patient's own dashboard should say.
  static const String caseSession = 'case-session';
}

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — reading the finished case back, correcting it, and sending it
///
/// Not a [CrudRepository]: there is no collection a patient can list. Every
/// route here reads the `patientId` off the bearer token and refuses a caller
/// who has none, so there is no shape of the request that asks about somebody
/// else's intake.
///
/// ## The correction path, and the gap it works around
///
/// `PATCH /sessions/:sessionId/facts/:factId` is the route written for a
/// correction: it writes a new fact, retires the old one, attributes the
/// result to `patient_correction`, and marks it `patient_confirmed` — the
/// patient corrected it themselves, so by definition they agree with it.
///
/// **The review document does not carry fact ids.** `RenderedItem` on the
/// server has `fieldPath`, `label`, `presence`, `display`, `source`,
/// `confidence`, `verification` and `documentId`, and no `id` — so a screen
/// that has only ever loaded the review has no `:factId` to PATCH. That is a
/// genuine hole in the API rather than something to route around quietly, and
/// it is worth closing server-side.
///
/// Until it is, [correctItem] uses the route it *can* address: a turn against
/// the named `fieldPath` with `modality: correction`. It is not a second
/// mechanism — `recordFact` supersedes the current unsuperseded fact for that
/// field inside the same transaction whichever door the correction came
/// through, so the append-only history is identical and the source still reads
/// `patient_correction`. The one thing it does differently is leave the new
/// fact `unverified` rather than `patient_confirmed`, which is why the screen
/// takes the fact id out of the response and uses the PATCH from then on.
///
/// The seam that would remove the first hop entirely is [knownFactId]: any
/// caller that already knows a field's fact id — the interview module learns
/// one from every turn it submits — can hand it over, and the correction goes
/// straight to the route written for it.
/// ─────────────────────────────────────────────────────────────────────────────
class CaseReviewRepository {
  const CaseReviewRepository();

  DioClient get _client => Get.find<DioClient>();

  // ── Reading ───────────────────────────────────────────────────────────────

  /// The interview this patient has open, or null when they have none.
  ///
  /// **200 with a null payload, not a 404.** "You have not started one" is an
  /// answer. Note that a *submitted* case is not open either, so this answers
  /// null once the case has been sent — which is why a screen that wants to
  /// say "you sent this" has to hold the session id it sent.
  Future<CaseSession?> currentSession() async {
    final response = await _client.get(Endpoints.caseSessionCurrent);
    final envelope = ApiEnvelope.of(response).orThrow();
    final object = envelope.object;
    return object.isEmpty ? null : CaseSession.fromJson(object);
  }

  /// One session by id, whatever state it is in.
  ///
  /// Unlike [currentSession] this reads a submitted case too, which is how the
  /// review screen renders a case that has already gone.
  Future<CaseSession> session(String sessionId) async {
    final response = await _client.get(Endpoints.caseSession(sessionId));
    return CaseSession.fromJson(ApiEnvelope.of(response).orThrow().object);
  }

  /// "Here is what we understood about you."
  ///
  /// Rendered by the engine with no model in the path, so it comes back
  /// immediately. [narrative] asks for a prose read-back as well and costs a
  /// model call — eight to twenty seconds on the hardware this runs on — so it
  /// is off unless somebody asked to be read to.
  Future<CaseReview> review(String sessionId, {bool narrative = false}) async {
    final response = await _client.get(
      Endpoints.caseSessionReview(sessionId),
      // Sent only when true. `ReviewQueryDto` declares the parameter, but a
      // request that never mentions it is one round trip the server does not
      // have to reason about.
      queryParameters: narrative ? const {'narrative': 'true'} : null,
    );
    return CaseReview.fromJson(ApiEnvelope.of(response).orThrow().object);
  }

  // ── Changing something ────────────────────────────────────────────────────

  /// Corrects one line of the case.
  ///
  /// [knownFactId] takes the route written for a correction. Without it the
  /// correction goes in as a turn against [fieldPath] — see the class comment
  /// for why that is the same write and not a second one — and the fact id it
  /// answers with is returned so the caller can take the direct route next
  /// time.
  Future<CaseFactCorrection> correctItem({
    required String sessionId,
    required String fieldPath,
    String? knownFactId,
    String? text,
    String? value,
  }) async {
    if (knownFactId != null && knownFactId.isNotEmpty) {
      final response = await _client.patch(
        Endpoints.caseSessionFact(sessionId, knownFactId),
        data: CaseFactCorrectionDraft(text: text, value: value).toUpdateJson(),
      );
      return CaseFactCorrection.fromJson(
        ApiEnvelope.of(response).orThrow().object,
      );
    }

    final turn = await _turn(
      sessionId,
      CaseTurnDraft(
        modality: CaseAnswerModality.correction,
        // Named explicitly and never left to the server's fallback. Without it
        // the answer is filed against whatever the last question asked was,
        // which on a review screen is a question from some other section
        // entirely — and an answer filed against the wrong field is worse than
        // a missing one, because it reads as a finding.
        fieldPath: fieldPath,
        text: text,
        value: value,
      ),
    );

    return CaseFactCorrection(
      factId: turn.accepted.factId ?? '',
      fieldPath: turn.accepted.fieldPath ?? fieldPath,
      presence: turn.accepted.presence,
      value: turn.accepted.value,
      needsPatientConfirmation: turn.accepted.needsPatientConfirmation,
    );
  }

  /// A tapped answer against one field — yes, no, "I don't know", or a skip.
  ///
  /// The token travels; the **state does not**. A tapped "I don't know" goes
  /// out as the reserved `not_sure`, which is a thing the patient pressed
  /// rather than a state the phone asserted, and `derivePresence` on the server
  /// reads it and decides. There is no request this app can make that says
  /// "this fact is unknown" — which is the property that keeps an uncertain
  /// answer from ever arriving as a denial.
  Future<CaseFactCorrection> answerChoice({
    required String sessionId,
    required String fieldPath,
    required CaseAnswerOption option,
  }) async {
    final turn = await _turn(
      sessionId,
      CaseTurnDraft.tapped(fieldPath: fieldPath, option: option),
    );
    return CaseFactCorrection(
      factId: turn.accepted.factId ?? '',
      fieldPath: fieldPath,
      presence: turn.accepted.presence,
      value: turn.accepted.value,
      needsPatientConfirmation: turn.accepted.needsPatientConfirmation,
    );
  }

  /// "I am not sure about this one."
  Future<CaseFactCorrection> markUnsure({
    required String sessionId,
    required String fieldPath,
  }) =>
      answerChoice(
        sessionId: sessionId,
        fieldPath: fieldPath,
        option: CaseAnswerOption.unsure,
      );

  Future<CaseTurnResult> _turn(String sessionId, CaseTurnDraft draft) async {
    final response = await _client.post(
      Endpoints.caseSessionTurns(sessionId),
      data: draft.toCreateJson(),
    );
    return CaseTurnResult.fromJson(ApiEnvelope.of(response).orThrow().object);
  }

  // ── Sending it ────────────────────────────────────────────────────────────

  /// Sends the finished case to the hospital.
  ///
  /// Writes a submission and attaches it to the patient record. It does **not**
  /// open a consultation, a queue entry or a screening: a submitted intake is a
  /// document waiting to be read, not an appointment nobody booked.
  ///
  /// A second call is a 409, not a second submission, and the message on it is
  /// already written for a patient.
  Future<CaseSubmissionReceipt> submit(String sessionId) async {
    final response = await _client.post(
      Endpoints.caseSessionSubmit(sessionId),
      data: const <String, dynamic>{},
    );
    final receipt = CaseSubmissionReceipt.fromJson(
      ApiEnvelope.of(response).orThrow().object,
    );

    // The patient's own dashboard is the screen that most needs to know, and
    // it is not the screen that made this call.
    if (Get.isRegistered<DataBus>()) {
      DataBus.to.changedRecord(CaseReviewEntities.caseSession);
    }
    return receipt;
  }
}
