/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — "here is what we understood about you", as the phone reads it
///
/// `GET /api/case-taking/sessions/:sessionId/review` renders the finished case
/// with no model anywhere in the path: the engine walks the clinical state and
/// writes a line for every field that applies to this patient, answered or
/// not. This file parses that, and three of its properties are the reason the
/// review screen can be trusted at all:
///
///  * **[CaseReviewItem.display] is always safe to print.** The renderer never
///    emits a value for a fact that has none — an unanswered question arrives
///    as the words "Not assessed", not as an empty string — and
///    [CaseReviewItem.presenceText] repeats the presence explicitly so a
///    client cannot render a blank where "Patient unsure" belongs.
///
///  * **The four states stay four.** [FactPresence] has six members and the
///    screen keeps every one of them distinct. A `none` is the patient saying
///    no; a `notAssessed` is nobody having asked. Collapsing them is how a
///    chart acquires an allergy history that was never taken.
///
///  * **Nothing here is a diagnosis.** There is no field on any of these
///    classes that could hold one: the engine's field registry deliberately
///    has no `diagnosis`, the safety view carries a routing sentence and a
///    count rather than the rules that fired, and §43 is satisfied
///    structurally rather than by everybody remembering.
///
/// [CaseReviewItem] carries **no fact id**, because the server's review
/// document does not send one. That is a real constraint on the correction
/// path rather than an oversight here — see `CaseReviewRepository.correctItem`
/// for what the app does about it.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'case_session.dart';
import 'json.dart';

/// Who asserted a fact.
///
/// Every member is somebody asserting something. There is deliberately no
/// `inferred` or `assumed` — the server's union has nowhere to put that lie
/// either, and a client that invented one would be the only party in the
/// system claiming the app decided something.
enum CaseFactSource {
  patientVoice,
  patientText,
  patientChoice,

  /// The patient changed an answer. Outranks whatever it replaced.
  patientCorrection,

  /// Read out of a document the patient handed over.
  uploadedDocument,

  /// Carried over from what the hospital already held, rather than asked.
  existingRecord,

  clinicianConfirmed;

  /// An unrecognised token reads as [patientText] — the weakest attribution
  /// that is still true of a case session. Never [clinicianConfirmed], which
  /// would put somebody else's name on the patient's own words.
  static CaseFactSource resolve(String? raw) => switch ((raw ?? '').trim()) {
        'patient_voice' => patientVoice,
        'patient_choice' => patientChoice,
        'patient_correction' => patientCorrection,
        'uploaded_document' => uploadedDocument,
        'existing_record' => existingRecord,
        'clinician_confirmed' => clinicianConfirmed,
        _ => patientText,
      };
}

/// Whether anybody has said "yes, that is right" about a fact.
///
/// Tracked apart from confidence, and that separation is the point: a
/// confidence is a measurement of a machine, and a verification is a person
/// taking responsibility. §17.
enum CaseVerification {
  unverified,
  patientConfirmed,
  clinicianConfirmed,
  disputed;

  /// Unrecognised reads as [unverified]. A token this build cannot read is not
  /// a confirmation it can claim.
  static CaseVerification resolve(String? raw) => switch ((raw ?? '').trim()) {
        'patient_confirmed' => patientConfirmed,
        'clinician_confirmed' => clinicianConfirmed,
        'disputed' => disputed,
        _ => unverified,
      };

  /// Whether a person has agreed with this line.
  ///
  /// The one question the review screen's styling is allowed to ask. An
  /// unconfirmed value must never be drawn like a confirmed one, and this is
  /// the only thing that decides which it is — never a local tap that has not
  /// reached the server.
  bool get isConfirmed =>
      this == patientConfirmed || this == clinicianConfirmed;
}

/// One line of the finished case.
class CaseReviewItem {
  const CaseReviewItem({
    required this.fieldPath,
    required this.label,
    required this.presence,
    required this.display,
    required this.presenceText,
    this.value,
    this.source = CaseFactSource.patientText,
    this.confidence,
    this.verification = CaseVerification.unverified,
    this.documentId,
    this.outstanding = false,
  });

  /// The registry key — `hpi.duration`. What a correction names.
  final String fieldPath;

  /// The question, in the words the registry gives it.
  final String label;

  final FactPresence presence;

  /// Always safe to print: the value when [presence] is recorded, and the
  /// presence's own wording otherwise.
  final String display;

  /// The presence spelled out, whatever [display] happens to hold. Sent
  /// separately by the server so a client cannot render a blank where "Patient
  /// unsure" belongs.
  final String presenceText;

  /// The raw value, when there is one. For a figure the screen must not
  /// ellipsise.
  final String? value;

  final CaseFactSource source;

  /// 0…1, **for display only**. Nothing gates on it. A benchmark against the
  /// local model returned exactly 0.95 on every fact in a run, including the
  /// one it got flatly wrong, and a threshold over a constant is a coin toss
  /// wearing a lab coat.
  final double? confidence;

  final CaseVerification verification;

  /// Set when this line came out of a document, so the screen can offer the
  /// original.
  final String? documentId;

  /// §36: this question applies to this patient and has not been answered.
  final bool outstanding;

  /// Whether there is a value here at all — the only state a patient can
  /// sensibly confirm or correct.
  bool get isRecorded => presence == FactPresence.recorded;

  factory CaseReviewItem.fromJson(Map<String, dynamic> json) => CaseReviewItem(
        fieldPath: asString(json['fieldPath']),
        label: asString(json['label']),
        presence: FactPresence.resolve(asString(json['presence'])),
        display: asString(json['display']),
        presenceText: asString(json['presenceText']),
        value: asStringOrNull(json['value']),
        source: CaseFactSource.resolve(asString(json['source'])),
        confidence:
            json['confidence'] == null ? null : asDouble(json['confidence']),
        verification: CaseVerification.resolve(asString(json['verification'])),
        documentId: asStringOrNull(json['documentId']),
        outstanding: asBool(json['outstanding']),
      );
}

/// One section of the case — the chief complaint, the history, the allergies.
class CaseReviewSection {
  const CaseReviewSection({
    required this.section,
    required this.title,
    this.percentComplete = 0,
    this.outstanding = const [],
    this.items = const [],
  });

  final String section;
  final String title;
  final int percentComplete;

  /// The field keys in this section nobody has answered.
  final List<String> outstanding;

  final List<CaseReviewItem> items;

  factory CaseReviewSection.fromJson(Map<String, dynamic> json) =>
      CaseReviewSection(
        section: asString(json['section']),
        title: asString(json['title']),
        percentComplete: asInt(json['percentComplete']),
        outstanding: asStringList(json['outstanding']),
        items: asModelList(json['items'], CaseReviewItem.fromJson),
      );
}

/// What the safety rules concluded, in the form a **patient** may see.
///
/// A count, not the rules. The patient is told to go to the front desk; the
/// clinical summaries go to the front desk, not to them — a rule set's own
/// titles name syndromes, and a syndrome on a patient's screen is a diagnosis
/// nobody qualified made.
class CaseReviewSafety {
  const CaseReviewSafety({
    this.highestSeverity = '',
    this.patientMessage,
    this.triggeredCount = 0,
  });

  static const CaseReviewSafety none = CaseReviewSafety();

  final String highestSeverity;

  /// The single sentence to put in front of the patient, from the most severe
  /// rule that fired. Null when nothing fired.
  final String? patientMessage;

  final int triggeredCount;

  bool get hasFired => triggeredCount > 0 && (patientMessage ?? '').isNotEmpty;

  factory CaseReviewSafety.fromJson(Map<String, dynamic> json) =>
      CaseReviewSafety(
        highestSeverity: asString(json['highestSeverity']),
        patientMessage: asStringOrNull(json['patientMessage']),
        triggeredCount: asInt(json['triggeredCount']),
      );
}

/// The whole review document.
class CaseReview {
  const CaseReview({
    this.sessionId = '',
    this.status = '',
    this.revision = 0,
    this.percentComplete = 0,
    this.missingInformation = const [],
    this.sections = const [],
    this.narrative,
    this.safety = CaseReviewSafety.none,
  });

  static const CaseReview empty = CaseReview();

  final String sessionId;

  /// `in_progress`, `review`, `submitted`, `abandoned`. Once it is
  /// `submitted` every write on this screen is a 409 on the server, so the
  /// screen stops offering them.
  final String status;

  final int revision;
  final int percentComplete;

  /// §36's list, flattened: every applicable question still unanswered.
  /// **Printed, never omitted** — an omitted line reads as nothing to report.
  final List<String> missingInformation;

  final List<CaseReviewSection> sections;

  /// The optional prose read-back. Costs a model call, so it is only present
  /// when the screen asked for it.
  final String? narrative;

  final CaseReviewSafety safety;

  bool get isEmpty => sessionId.isEmpty && sections.isEmpty;

  bool get isSubmitted => status == 'submitted';

  /// Every line with a value on it, across every section.
  List<CaseReviewItem> get recordedItems => [
        for (final section in sections)
          for (final item in section.items)
            if (item.isRecorded) item,
      ];

  /// §36's list, with the questions' own wording on it.
  ///
  /// [missingInformation] carries the same set as bare field keys —
  /// `hpi.radiation` — which is the right shape for a machine and the wrong
  /// one for a patient. The items carry the label the registry gives each
  /// question, so this is what goes on screen and the key list is what a test
  /// counts against.
  List<CaseReviewItem> get outstandingItems => [
        for (final section in sections)
          for (final item in section.items)
            if (item.outstanding) item,
      ];

  factory CaseReview.fromJson(Map<String, dynamic> json) => CaseReview(
        sessionId: asString(json['sessionId']),
        status: asString(json['status']),
        revision: asInt(json['revision']),
        percentComplete: asInt(json['percentComplete']),
        missingInformation: asStringList(json['missingInformation']),
        sections: asModelList(json['sections'], CaseReviewSection.fromJson),
        // Deliberately not defaulted to the structured `text` rendering. A
        // narrative the patient did not ask for would be a model's prose
        // presented as the app's own summary.
        narrative: asStringOrNull(json['narrative']),
        safety: CaseReviewSafety.fromJson(asMap(json['safety'])),
      );
}

/// What comes back from a correction.
///
/// A correction writes a **new** fact and retires the old one; it is never an
/// update, because the disagreement between what was first understood and what
/// the patient then said is the part a clinician needs.
class CaseFactCorrection {
  const CaseFactCorrection({
    required this.factId,
    this.supersededFactId,
    this.fieldPath = '',
    this.presence = FactPresence.notAssessed,
    this.value,
    this.needsPatientConfirmation = false,
  });

  final String factId;
  final String? supersededFactId;
  final String fieldPath;
  final FactPresence presence;
  final String? value;

  /// True when the derivation itself wants checking — a hedged answer that
  /// was read as a value. The screen leaves the line marked as needing a look
  /// rather than treating the correction as settled.
  final bool needsPatientConfirmation;

  factory CaseFactCorrection.fromJson(Map<String, dynamic> json) =>
      CaseFactCorrection(
        factId: asString(json['factId']),
        supersededFactId: asStringOrNull(json['supersededFactId']),
        fieldPath: asString(json['fieldPath']),
        presence: FactPresence.resolve(asString(json['presence'])),
        value: asStringOrNull(json['value']),
        needsPatientConfirmation: asBool(json['needsPatientConfirmation']),
      );
}

/// The receipt for a case that has been sent to the hospital.
///
/// The submission is stored apart from the session on the server because the
/// session keeps moving and what the doctor opened must stay exactly what the
/// doctor opened. This is the part of it the phone keeps.
class CaseSubmissionReceipt {
  const CaseSubmissionReceipt({
    required this.submissionId,
    required this.sessionId,
    this.submittedAt,
    this.percentComplete = 0,
    this.sectionCount = 0,
    this.missingInformation = const [],
    this.safety = CaseReviewSafety.none,
  });

  final String submissionId;
  final String sessionId;
  final DateTime? submittedAt;
  final int percentComplete;
  final int sectionCount;

  /// Carried on the receipt as well as in the case, so the screen that says
  /// "sent" can also say what was not asked. §36 applies after submission too.
  final List<String> missingInformation;

  final CaseReviewSafety safety;

  bool get isEmpty => submissionId.isEmpty;

  factory CaseSubmissionReceipt.fromJson(Map<String, dynamic> json) =>
      CaseSubmissionReceipt(
        submissionId: asString(json['submissionId']),
        sessionId: asString(json['sessionId']),
        submittedAt: asDate(json['submittedAt']),
        percentComplete: asInt(json['percentComplete']),
        sectionCount: asInt(json['sectionCount']),
        missingInformation: asStringList(json['missingInformation']),
        safety: CaseReviewSafety.fromJson(asMap(json['safety'])),
      );
}
