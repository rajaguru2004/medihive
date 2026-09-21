/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — a finished intake, as the clinician reading it sees it
///
/// The same document the patient sent, from the other side. Three differences
/// from `CaseReview`, and each one is the reason this is its own model rather
/// than a flag on that one:
///
///  1. **It is about somebody else.** Every field here belongs to a patient
///     the reader is not, so the row carries who — a name and an MRN — which
///     a patient's own view of their own case has no use for.
///
///  2. **It carries the rules that fired.** `CaseReviewSafety` holds a count
///     and a sentence, because §43 keeps a rule set's titles off a *patient's*
///     screen: those titles name syndromes, and a syndrome on a patient's
///     screen is a diagnosis nobody qualified made. The clinician is the
///     qualified reader. [IntakeRedFlag] is what the count was hiding.
///
///  3. **Nothing here is editable and there is no draft to go with it.** A
///     doctor holds `CASE_TAKING_READ` and deliberately nothing more — an
///     intake a clinician can rewrite stops being evidence of what the patient
///     said. There is no `toUpdateJson` in this file and there must not be.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import '../../modules/patient_portal/patient_entry.dart';
import 'case_review.dart';
import 'json.dart';
import 'patient_ref.dart';

/// One safety rule that fired on this case.
///
/// Read by a clinician and by nobody else. `title` is the rule's own wording
/// from the engine's rule set — `Possible acute coronary syndrome` — which is
/// exactly the string the patient's view of the same case refuses to show.
///
/// **The keys are the engine's, not this app's.** `TriggeredRule` in
/// `safety-engine.ts` sends `ruleId`, `clinicianSummary` and
/// `recommendedAction`; reading them as `id`, `rationale` and `action` — which
/// this model did — parses without error and loses all three: every flag gets
/// an empty id, and the two sentences that decide what happens next render as
/// absent. `patientMessage` is deliberately **not** read here: it is the
/// wording written for the patient's screen, and a clinician reading it in
/// place of the clinical summary is reading the wrong sentence.
class IntakeRedFlag {
  const IntakeRedFlag({
    this.id = '',
    this.title = '',
    this.severity = '',
    this.rationale,
    this.action,
  });

  /// `chest_pain_acs`. The rule's own identifier — and the key a widget for
  /// this flag is built with, so two rules firing at once do not collide on
  /// the empty string.
  final String id;

  final String title;

  /// `critical`, `urgent`, `advisory` — the engine's own ladder. Resolved for
  /// display through `CaseStatus`, never painted from a second table.
  final String severity;

  /// `clinicianSummary`: why it fired, in the rule's own words. The field
  /// `safety-rules.ts` describes as the one that may name the screen — "meets
  /// the ACS screening triad" — because a triage nurse needs to know which
  /// rule fired and why.
  final String? rationale;

  /// `recommendedAction`: what the rule asks somebody to do about it.
  final String? action;

  factory IntakeRedFlag.fromJson(Map<String, dynamic> json) => IntakeRedFlag(
        id: asString(json['ruleId']),
        title: asString(json['title']),
        severity: asString(json['severity']),
        rationale: asStringOrNull(json['clinicianSummary']),
        action: asStringOrNull(json['recommendedAction']),
      );
}

/// What the safety engine concluded, in the form a **clinician** may see.
class IntakeSafety {
  const IntakeSafety({
    this.highestSeverity = '',
    this.rulesetVersion = '',
    this.triggered = const [],
  });

  final String highestSeverity;

  /// Which rule set ran. On the record because a case read a year from now has
  /// to be read against the rules that actually ran on it, not the ones in the
  /// file today.
  final String rulesetVersion;

  final List<IntakeRedFlag> triggered;

  static const IntakeSafety none = IntakeSafety();

  bool get isEmpty => triggered.isEmpty;

  factory IntakeSafety.fromJson(Map<String, dynamic> json) => IntakeSafety(
        highestSeverity: asString(json['highestSeverity']),
        rulesetVersion: asString(json['rulesetVersion']),
        triggered: asModelList(json['triggered'], IntakeRedFlag.fromJson),
      );
}

/// One row in the list of intakes waiting to be read.
///
/// Deliberately narrower than [CaseIntake]: it is what a clinician scans by,
/// and a list row has no room for a rule. [triggeredCount] says "open this
/// one" and the rules themselves arrive with the case.
class IntakeSummary {
  const IntakeSummary({
    this.id = '',
    this.sessionId = '',
    this.patientId = '',
    this.submittedAt,
    this.percentComplete = 0,
    this.sectionCount = 0,
    this.missingCount = 0,
    this.highestSeverity = '',
    this.triggeredCount = 0,
    this.inputLanguage = '',
    this.outputLanguage = '',
    this.patient = const PatientRef(id: ''),
  });

  final String id;
  final String sessionId;
  final String patientId;
  final DateTime? submittedAt;
  final int percentComplete;
  final int sectionCount;

  /// How many applicable questions nobody answered. §36: shown, never
  /// omitted — a case that is 60% complete is a case with gaps in it, and the
  /// gaps are the part a clinician has to fill in person.
  final int missingCount;

  final String highestSeverity;
  final int triggeredCount;

  /// What the patient **spoke**, and what they were answered in. Both, because
  /// one cannot say what happened: a Tamil answer transcribed and rendered in
  /// English is a fact the clinician needs, and `language: ta` over an English
  /// transcript reads as a translation that never ran.
  final String inputLanguage;
  final String outputLanguage;

  final PatientRef patient;

  bool get isEmpty => id.isEmpty;

  /// True when the interview left questions unanswered.
  bool get hasGaps => missingCount > 0;

  /// True when at least one safety rule fired.
  bool get hasRedFlags => triggeredCount > 0;

  /// `Tamil`, not `ta` — and never `Ta`.
  ///
  /// The code is ambiguous to the person reading it (`ta` is Tamil here and
  /// Tagalog elsewhere), and this line exists so a clinician can decide
  /// whether to book an interpreter. `PatientLanguage` already holds the
  /// English names for exactly this — its own comment says "for a log or a
  /// doctor's view". An unknown code falls back to itself rather than to a
  /// guess.
  String get inputLanguageName => _nameOf(inputLanguage);
  String get outputLanguageName => _nameOf(outputLanguage);

  static String _nameOf(String code) =>
      PatientLanguage.tryFromCode(code)?.englishName ??
      (code.isEmpty ? '—' : code);

  /// Whether the patient answered in a language the case was not written in.
  ///
  /// Worth saying on the row rather than only in the case: a clinician about
  /// to see this person may need an interpreter in the room, and that is a
  /// decision made from the list.
  bool get wasInterpreted =>
      inputLanguage.isNotEmpty &&
      outputLanguage.isNotEmpty &&
      inputLanguage != outputLanguage;

  factory IntakeSummary.fromJson(Map<String, dynamic> json) => IntakeSummary(
        id: asString(json['id']),
        sessionId: asString(json['sessionId']),
        patientId: asString(json['patientId']),
        submittedAt: asDate(json['submittedAt']),
        percentComplete: asInt(json['percentComplete']),
        sectionCount: asInt(json['sectionCount']),
        missingCount: asInt(json['missingCount']),
        highestSeverity: asString(json['highestSeverity']),
        triggeredCount: asInt(json['triggeredCount']),
        inputLanguage: asString(json['inputLanguage']),
        outputLanguage: asString(json['outputLanguage']),
        patient: PatientRef.of(json['patient']),
      );
}

/// One intake, whole.
///
/// The sections and their items are the same shapes the patient's own review
/// screen reads — [CaseReviewSection] and [CaseReviewItem] — because they are
/// the same document. What is added is who it belongs to, the rules that
/// fired, and the plain-text rendering a clinician can read top to bottom
/// without tapping anything.
class CaseIntake {
  const CaseIntake({
    this.summary = const IntakeSummary(),
    this.sections = const [],
    this.missingInformation = const [],
    this.safety = IntakeSafety.none,
    this.text = '',
    this.rulesetVersion = '',
    this.consentVersion,
    this.renderedAt,
  });

  final IntakeSummary summary;
  final List<CaseReviewSection> sections;

  /// §36's list: every applicable question still unanswered, by field key.
  final List<String> missingInformation;

  final IntakeSafety safety;

  /// The whole case as text. What gets read aloud on a ward round, and what a
  /// clinician copies into a note.
  final String text;

  final String rulesetVersion;

  /// Which wording of the consent the patient agreed to. Null on a case sent
  /// before the interview recorded one.
  final String? consentVersion;

  final DateTime? renderedAt;

  static const CaseIntake empty = CaseIntake();

  bool get isEmpty => summary.isEmpty && sections.isEmpty;

  /// True when the row arrived but the document on it could not be read.
  ///
  /// The server defaults every field of `structuredCase` independently so a
  /// case written by an older build still opens as the parts this one
  /// understands — which means a document it understands *none* of comes back
  /// as a perfectly valid 200 with nothing in it. On screen that is
  /// indistinguishable from a patient who submitted an empty intake, and the
  /// first reading is a clinical statement about the patient. The screen says
  /// which it is instead.
  bool get isUnreadable =>
      !summary.isEmpty &&
      sections.isEmpty &&
      text.trim().isEmpty &&
      missingInformation.isEmpty &&
      safety.isEmpty;

  /// Every line with a value on it. The clinician's "what did they actually
  /// say".
  List<CaseReviewItem> get recordedItems => [
        for (final section in sections)
          for (final item in section.items)
            if (item.isRecorded) item,
      ];

  /// The questions this patient has not answered, in the registry's own
  /// wording rather than as field keys.
  List<CaseReviewItem> get outstandingItems => [
        for (final section in sections)
          for (final item in section.items)
            if (item.outstanding) item,
      ];

  factory CaseIntake.fromJson(Map<String, dynamic> json) => CaseIntake(
        // The card's fields arrive flattened alongside the document rather
        // than nested, so the same JSON parses as both.
        summary: IntakeSummary.fromJson(json),
        sections: asModelList(json['sections'], CaseReviewSection.fromJson),
        missingInformation: asStringList(json['missingInformation']),
        safety: IntakeSafety.fromJson(asMap(json['safety'])),
        text: asString(json['text']),
        rulesetVersion: asString(json['rulesetVersion']),
        consentVersion: asStringOrNull(json['consentVersion']),
        renderedAt: asDate(json['renderedAt']),
      );
}
