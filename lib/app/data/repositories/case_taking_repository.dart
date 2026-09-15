import 'dart:typed_data';

import 'package:dio/dio.dart';
// `FormData` and `MultipartFile` are declared by both packages, and GetX's
// belong to its own HTTP client. Hidden here the way the two other multipart
// repositories hide them, so a part built with the wrong one cannot compile.
import 'package:get/get.dart' hide Response, FormData, MultipartFile;

import '../models/case_session.dart';
import '../models/drafts/case_taking_drafts.dart';
import '../network/dio_client.dart';
import '../network/endpoints.dart';
import '../services/audio_source.dart';
import '../utils/api_envelope.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the interview's side of the API
///
/// Not a [CrudRepository], and for the same reason `PatientPortalRepository` is
/// not one: there is no collection here. A patient has at most one open
/// interview, every route reads the `patientId` off the bearer token, and none
/// of them takes a patient id at all — so there is no list to page and no
/// record to address by somebody else's identifier.
///
/// ## What this layer refuses to do
///
/// It does not retry, it does not cache and it does not decide what a failure
/// means. A turn that fails is a turn the patient can try again; a screen that
/// silently re-posted one would file the same answer twice against an
/// append-only fact log, and two readings of one answer with no disagreement
/// between them is noise a clinician has to reconcile by hand.
/// ─────────────────────────────────────────────────────────────────────────────
class CaseTakingRepository {
  const CaseTakingRepository();

  DioClient get _client => Get.find<DioClient>();

  // ── The session ───────────────────────────────────────────────────────────

  /// Starts an interview, or hands back the one already open.
  ///
  /// 200 for both. `resumed` says which happened, and the app treats neither
  /// as an error: a patient who closed the phone mid-interview is carrying on,
  /// not recovering from a fault.
  Future<CaseSession> startOrResume(CaseSessionStartDraft draft) async {
    final response = await _client.post(
      Endpoints.caseSessions,
      data: draft.toCreateJson(),
    );
    return CaseSession.fromJson(ApiEnvelope.of(response).orThrow().object);
  }

  /// The interview this patient has open, or null.
  ///
  /// **Null is a success.** The route answers 200 with a null payload when
  /// there is no open session, so an empty object here means "you have not
  /// started one" rather than "the request failed" — and a caller that treated
  /// it as a failure would put a retry banner in front of a patient who simply
  /// has nothing in progress.
  Future<CaseSession?> current() async {
    final response = await _client.get(Endpoints.caseSessionCurrent);
    final payload = ApiEnvelope.of(response).orThrow().object;
    if (payload.isEmpty) return null;
    final session = CaseSession.fromJson(payload);
    return session.isEmpty ? null : session;
  }

  /// Where an interview has got to, and what it is asking.
  ///
  /// The current question comes off the server's turn log rather than from a
  /// fresh run of the selector, so re-reading a session hands back the question
  /// the patient is looking at instead of the one after it.
  Future<CaseSession> session(String sessionId) async {
    final response = await _client.get(Endpoints.caseSession(sessionId));
    return CaseSession.fromJson(ApiEnvelope.of(response).orThrow().object);
  }

  /// Records consent, or a refusal.
  ///
  /// A refusal abandons the session rather than leaving it open in a state
  /// where the next request could still ask a question.
  Future<CaseSession> recordConsent(
    String sessionId,
    CaseConsentDraft draft,
  ) async {
    final response = await _client.post(
      Endpoints.caseSessionConsent(sessionId),
      data: draft.toCreateJson(),
    );
    return CaseSession.fromJson(ApiEnvelope.of(response).orThrow().object);
  }

  // ── Answering ─────────────────────────────────────────────────────────────

  /// One answer in, the next question out.
  ///
  /// The response arrives in milliseconds because nothing on this path talks to
  /// a model: presence derivation, the safety rules and question selection are
  /// all pure and synchronous on the server. Anything the model has to read
  /// runs behind the response and lands as facts later, which `extraction`
  /// reports so the screen can say so quietly instead of blocking on it.
  Future<CaseTurnResult> submitTurn(
    String sessionId,
    CaseTurnDraft draft,
  ) async {
    final response = await _client.post(
      Endpoints.caseSessionTurns(sessionId),
      data: draft.toCreateJson(),
    );
    return CaseTurnResult.fromJson(ApiEnvelope.of(response).orThrow().object);
  }

  /// Corrects an answer already recorded.
  ///
  /// Returns the new fact's id alongside the one it superseded, because both
  /// are on the chart afterwards — the correction does not delete the first
  /// reading, it disagrees with it in writing.
  Future<CaseAcceptedAnswer> correctFact(
    String sessionId,
    String factId,
    CaseFactCorrectionDraft draft,
  ) async {
    final response = await _client.patch(
      Endpoints.caseSessionFact(sessionId, factId),
      data: draft.toUpdateJson(),
    );
    return CaseAcceptedAnswer.fromJson(
      ApiEnvelope.of(response).orThrow().object,
    );
  }

  // ── Voice ─────────────────────────────────────────────────────────────────

  /// Which languages this hospital can take an interview in.
  ///
  /// Throws like any other read, and the caller is expected to let it: the
  /// language screen ships its own catalogue and this only refines it, so a
  /// refusal here costs a patient nothing they can see. That is the opposite
  /// posture from [startOrResume], and deliberately — a list that cannot be
  /// fetched is a list the app already has, while a session that cannot be
  /// started is an interview that cannot happen.
  Future<List<CaseLanguage>> languages() async {
    final response = await _client.get(Endpoints.caseLanguages);
    return ApiEnvelope.of(response)
        .orThrow()
        .listOf(CaseLanguage.fromJson)
        .where((language) => !language.isEmpty)
        .toList();
  }

  /// Transcribes a recorded answer.
  ///
  /// Multipart under the field name `file`, which is what `FileInterceptor`
  /// binds. `contentType` is set explicitly on both the request and the part:
  /// Dio types a part it was given no type for as `application/octet-stream`,
  /// and the client's own default of `application/json` on the request sends a
  /// body no multipart parser can read.
  ///
  /// The language is sent as a form field rather than as a query parameter,
  /// because the DTO declares it — and `forbidNonWhitelisted` applies to a
  /// multipart body too.
  ///
  /// Throws like any other write. The caller's job is to read a refusal as
  /// "the microphone path is unavailable, carry on with the keyboard" rather
  /// than as an error worth stopping the interview for.
  Future<CaseTranscript> transcribe(
    RecordedAudio audio, {
    String? language,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        audio.bytes,
        filename: audio.filename,
        contentType: DioMediaType.parse(audio.mimeType),
      ),
      if (language != null && language.isNotEmpty) 'language': language,
    });

    final response = await _client.post(
      Endpoints.caseStt,
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
    return CaseTranscript.fromJson(ApiEnvelope.of(response).orThrow().object);
  }

  /// A question, read aloud.
  ///
  /// The mirror of [transcribe], and the reason it exists is the same one: a
  /// patient who is frightened, in pain, or holding a phone in one hand speaks
  /// better than they type — and a patient with long sight, low literacy, or a
  /// language they speak but do not read cannot use a question that only
  /// exists on the screen.
  ///
  /// Returns the WAV bytes. **Not an envelope** — this route answers
  /// `audio/wav` directly, which is why `ApiEnvelope` is not involved and
  /// `ResponseType.bytes` is set; the default JSON transform would take a
  /// binary body and hand back mojibake rather than fail, which is the worst
  /// of the available outcomes.
  ///
  /// Throws like any other read. The caller's job is to treat a refusal as
  /// "this question cannot be read aloud right now" and carry on — the
  /// question is already on screen before this is ever called, so there is
  /// nothing here worth interrupting an interview for.
  Future<Uint8List> speak(String text, {String? language}) async {
    final response = await _client.post(
      Endpoints.caseTts,
      data: {
        'text': text,
        if (language != null && language.isNotEmpty) 'language': language,
      },
      options: Options(responseType: ResponseType.bytes),
    );

    final data = response.data;
    if (data is Uint8List) return data;
    if (data is List<int>) return Uint8List.fromList(data);

    // A body that is neither is a route that has stopped answering audio —
    // most likely an HTML error page from something between here and the API.
    // Empty bytes read downstream as "nothing to play", which is the same
    // quiet degradation as a missing voice.
    return Uint8List(0);
  }
}
