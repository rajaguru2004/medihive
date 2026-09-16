/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the four writes an interview makes
///
/// `main.ts` runs `whitelist` with `forbidNonWhitelisted`, so one key the DTO
/// does not declare is a 400 for the whole request — and a 400 on a turn is a
/// patient who answered a question and watched nothing happen.
///
/// Two keys are conspicuously absent from every body here, and their absence is
/// the point rather than an oversight:
///
///  * **`patientId` and `organizationId`** arrive from the bearer token. Sending
///    either is a 400, which is the server making tenant-hopping a syntax error
///    rather than a code review.
///
///  * **`presence`**. A client cannot post "this is unknown" any more than the
///    model can: `derivePresence` reads the patient's own words and decides, and
///    it is the only thing that does. A tapped "I don't know" reaches it as the
///    reserved token `not_sure` — a thing the patient pressed, not a state the
///    phone asserted. That distinction is what keeps an unanswered allergy
///    question from arriving as a denial.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import '../case_session.dart';
import 'draft_json.dart';

/// Start an interview, or resume the one already open.
///
/// DTO: `hms_v2/src/modules/case-taking/dto/case-taking.dto.ts`
/// (`StartCaseSessionDto`).
///
/// Every field is optional on the server and every one is sent anyway, except
/// the appointment: `kind` and `language` have defaults there, and a session
/// created on the server's default rather than on the patient's own answer is
/// a language nobody chose.
class CaseSessionStartDraft {
  const CaseSessionStartDraft({
    this.kind = 'new_consultation',
    this.language = 'en',
    this.appointmentId,
  });

  /// `new_consultation` or `follow_up`. Nothing else is accepted.
  final String kind;

  /// BCP-47-ish, from the language screen. Stored on the session rather than
  /// on the phone, so the doctor reading the transcript learns which language
  /// it was taken in.
  final String language;

  /// The appointment this intake is for, when there is one.
  final String? appointmentId;

  Map<String, dynamic> toCreateJson() => draftBody({
        'kind': kind,
        'language': language,
        'appointmentId': appointmentId,
      });
}

/// Consent, or a refusal.
///
/// DTO: `CaseConsentDto`. Both keys are required — `accepted: false` is a real
/// answer and is recorded as one, which is why it must survive `draftBody`
/// (it does: `false` is a value, never an absence).
class CaseConsentDraft {
  const CaseConsentDraft({
    required this.consentVersion,
    required this.accepted,
  });

  /// Which wording was agreed to. Consent is a moment rather than a flag: what
  /// somebody was shown matters as much as that they accepted it. Read off the
  /// session's `consent.requiredVersion`, never pinned in the app.
  final String consentVersion;

  final bool accepted;

  Map<String, dynamic> toCreateJson() => draftBody({
        'consentVersion': consentVersion,
        'accepted': accepted,
      });
}

/// One answer.
///
/// DTO: `SubmitTurnDto`.
///
/// [fieldPath] is sent even though the server can work it out from the last
/// question it asked. That is the whole reason it is here: a patient who taps
/// an answer on the frame the next question arrives would otherwise have it
/// filed against the wrong field, and an answer filed against the wrong field
/// is worse than a missing one because it reads as a finding.
class CaseTurnDraft {
  const CaseTurnDraft({
    required this.modality,
    this.fieldPath,
    this.text,
    this.value,
    this.transcriptConfidence,
    this.audioKey,
  });

  /// How the answer arrived. A tapped tile is `choice`, never `touch`.
  final CaseAnswerModality modality;

  /// The question being answered. Omitted for an opening narrative that
  /// belongs to no single field.
  final String? fieldPath;

  /// What they said or typed, **verbatim**. Never normalised, never
  /// title-cased, never trimmed of the hedge that makes it an uncertainty —
  /// "I think maybe three days" is read differently from "three days", and the
  /// difference is the server's to notice.
  final String? text;

  /// A tapped or numeric answer: the option token, including the reserved
  /// `not_sure` and `prefer_not_to_say`.
  final String? value;

  /// From the speech recogniser, 0…1. A real measurement.
  final double? transcriptConfidence;

  /// Where the recording was stored, when it was — so a doubtful
  /// transcription can be checked against what was actually said.
  final String? audioKey;

  /// A spoken answer, with the recogniser's own confidence attached.
  factory CaseTurnDraft.spoken({
    required String fieldPath,
    required String text,
    double? confidence,
    String? audioKey,
  }) =>
      CaseTurnDraft(
        modality: CaseAnswerModality.voice,
        fieldPath: fieldPath,
        text: text,
        transcriptConfidence: confidence,
        audioKey: audioKey,
      );

  /// A typed answer.
  factory CaseTurnDraft.typed({
    required String fieldPath,
    required String text,
  }) =>
      CaseTurnDraft(
        modality: CaseAnswerModality.text,
        fieldPath: fieldPath,
        text: text,
      );

  /// A tapped tile.
  ///
  /// [CaseAnswerModality.skip] carries its meaning in the modality and sends no
  /// value — the server derives `declined` from it. Every other tap sends the
  /// token, which for "I don't know" is `not_sure`: a thing the patient
  /// pressed, and the reason this app cannot accidentally file a denial.
  factory CaseTurnDraft.tapped({
    required String fieldPath,
    required CaseAnswerOption option,
  }) =>
      CaseTurnDraft(
        modality: option.modality,
        fieldPath: fieldPath,
        value: option.modality == CaseAnswerModality.skip ? null : option.token,
      );

  Map<String, dynamic> toCreateJson() => draftBody({
        'fieldPath': fieldPath,
        'modality': modality.wireValue,
        'text': text,
        'value': value,
        'transcriptConfidence': transcriptConfidence,
        'audioKey': audioKey,
      });
}

/// Correcting something already recorded.
///
/// DTO: `CorrectFactDto`. Writes a new fact and retires the old one; there is
/// no update, because the disagreement between the two readings is the part a
/// clinician needs.
class CaseFactCorrectionDraft {
  const CaseFactCorrectionDraft({this.modality, this.text, this.value});

  /// Defaults to `correction` on the server, which is what a correction is.
  final CaseAnswerModality? modality;

  final String? text;
  final String? value;

  Map<String, dynamic> toUpdateJson() => draftBody({
        'modality': modality?.wireValue,
        'text': text,
        'value': value,
      });
}

/// Asking for a pass into a live voice room.
///
/// DTO: `hms_v2/src/modules/case-taking/dto/case-taking.dto.ts`
/// (`VoiceTokenDto`) — **being written alongside this**, so the shape here is
/// the documented one rather than one that has been posted to a running
/// server. That is worth saying plainly, because `forbidNonWhitelisted` makes
/// a key the DTO has not declared a 400 for the whole request.
///
/// What makes that safe to ship ahead of the route is the same thing that
/// makes the feature optional: `CaseTakingController` reads a failure here —
/// a 400, a 404 on a site with no media server, a timeout — as "there is no
/// live conversation available", and the microphone goes on recording and
/// uploading through `POST /case-taking/stt` exactly as it did before. The
/// cost of guessing a field name wrong is a feature that does not appear, not
/// an interview that does not work.
///
/// The session is named because a room belongs to one interview. The two
/// language tags are sent because the agent has to be told what to listen for
/// before the patient speaks, and asking it to infer that from the audio is
/// how an answer given in Tamil comes back transcribed as English.
class CaseVoiceTokenDraft {
  const CaseVoiceTokenDraft({
    required this.sessionId,
    required this.inputLanguage,
    required this.outputLanguage,
  });

  final String sessionId;

  /// What the patient speaks. The only thing the language screen chooses.
  final String inputLanguage;

  /// What the interview answers in — English, under the current rule. Sent
  /// rather than assumed: the room should not have to guess what the questions
  /// it is helping with are written in.
  final String outputLanguage;

  Map<String, dynamic> toCreateJson() => draftBody({
        'sessionId': sessionId,
        'inputLanguage': inputLanguage,
        'outputLanguage': outputLanguage,
      });
}
