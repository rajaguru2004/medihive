/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the intake a clinician opens, in fixtures
///
/// The other side of `case_review_fixtures.dart`. That file is the patient
/// writing and sending a case; this is a doctor reading one that was sent, and
/// the difference the fixtures have to carry is what the two are allowed to
/// see:
///
///   * the patient's own review answers with `safety.triggeredCount` and no
///     rules, because §43 keeps a rule set's titles off their screen;
///   * this one answers with `safety.triggered`, titles and all, because the
///     clinician is the qualified reader and a count they cannot open is not
///     a safety net.
///
/// A flow that could not tell those apart would pass on either, which is why
/// the red flag here has a real title and a real severity rather than a
/// placeholder.
///
/// The patient is Ifeoma Balogun, `p-1`, who is `p-1` in `world.dart` and on
/// the clinic board and in the portal fixtures too — so a flow can walk from
/// her own screen to a clinician's view of the same document and find the same
/// facts on both.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import '../../fakes/fake_api.dart';

/// The intake on Ifeoma Balogun's chart.
const String kIntakeId = 'sub-1';

/// The rule that fired on it. A real title, because the assertion worth making
/// is that a clinician sees the rule and the patient does not.
const String kIntakeRedFlagId = 'acs-suspicion';
const String kIntakeRedFlagTitle = 'Possible acute coronary syndrome';

/// The two sentences a clinician acts on: why the rule fired, and what to do.
/// Both were silently absent while the model read the wrong keys.
const String kIntakeRedFlagSummary =
    'Meets the ACS screening triad: central pain, radiation, diaphoresis.';
const String kIntakeRedFlagAction = 'Assess before the routine queue.';

/// The question nobody answered. §36: printed on the clinician's screen too —
/// silence is not a negative finding for the doctor either.
const String kIntakeUnansweredLabel = 'Does the pain go anywhere else?';

/// What the patient said, and what the case was written in. Different, so the
/// "answered in Tamil" line has something to say.
const String kIntakeInputLanguage = 'ta';
const String kIntakeOutputLanguage = 'en';

/// Registers the two clinician-facing routes. Called from `World.install`.
void installCaseIntakeFixtures(FakeApi api, {bool withIntake = true}) {
  final rows = withIntake ? [_summary] : const <Map<String, Object?>>[];

  api.on('GET', '/api/case-taking/submissions', (request) {
    final patientId = request.query['patientId'];
    final matching = [
      for (final row in rows)
        if (patientId == null || patientId.isEmpty || row['patientId'] == patientId)
          row,
    ];

    return FakeResponse.page(
      matching,
      page: 1,
      limit: 20,
      total: matching.length,
    );
  });

  // Registered after the listing, which is how `FakeApi` resolves a literal
  // and a parameterised sibling: later registrations win, so `:submissionId`
  // has to come second or it would swallow nothing — the collection path is
  // one segment shorter — but the order is stated here anyway, because the
  // day somebody adds `/submissions/recent` it will matter.
  api.on('GET', '/api/case-taking/submissions/:submissionId', (request) {
    final id = request.pathParams['submissionId'] ?? '';
    if (!withIntake || id != kIntakeId) {
      return FakeResponse.fail(
        404,
        'That intake could not be found.',
        errorCode: 'CASE_SESSION_NOT_FOUND',
      );
    }
    return FakeResponse.ok(_document);
  });
}

/// The list row: a header and never the case.
const Map<String, Object?> _summary = {
  'id': kIntakeId,
  'sessionId': 'sess-1',
  'patientId': 'p-1',
  'submittedAt': '2026-03-12T08:40:00.000Z',
  'percentComplete': 80,
  'sectionCount': 2,
  'missingCount': 1,
  'highestSeverity': 'urgent',
  'triggeredCount': 2,
  'inputLanguage': kIntakeInputLanguage,
  'outputLanguage': kIntakeOutputLanguage,
  'patient': {
    'id': 'p-1',
    'mrn': '10421',
    'firstName': 'Ifeoma',
    'lastName': 'Balogun',
    'dateOfBirth': '1991-04-12T00:00:00.000Z',
    'gender': 'Female',
  },
};

/// The whole document: the card's fields flattened alongside the case, which
/// is the shape the route answers with so the same JSON parses as both.
const Map<String, Object?> _document = {
  ..._summary,
  'rulesetVersion': '2026.09.1',
  'consentVersion': 'v1',
  'renderedAt': '2026-03-12T08:39:00.000Z',
  'missingInformation': ['hpi.radiation'],
  'sections': [
    {
      'section': 'chief_complaint',
      'title': 'What brought you in',
      'percentComplete': 100,
      'outstanding': <String>[],
      'items': [
        {
          'fieldPath': 'chief_complaint.symptom',
          'label': 'Main concern',
          'presence': 'recorded',
          'display': 'Pain in the middle of my chest',
          'presenceText': 'Recorded',
          'value': 'Pain in the middle of my chest',
          'source': 'patient_voice',
          'confidence': 0.84,
          'verification': 'patient_confirmed',
          'outstanding': false,
        },
      ],
    },
    {
      'section': 'hpi',
      'title': 'Your symptoms',
      'percentComplete': 60,
      'outstanding': ['hpi.radiation'],
      'items': [
        // A denial is a finding — "denies fever" is something a clinician
        // writes down — and it must not render as a blank on this screen
        // either.
        {
          'fieldPath': 'hpi.associated.fever',
          'label': 'Any fever?',
          'presence': 'none',
          'display': 'None reported',
          'presenceText': 'None reported',
          'value': null,
          'source': 'patient_choice',
          'verification': 'patient_confirmed',
          'outstanding': false,
        },
        // §36: the question nobody reached.
        {
          'fieldPath': 'hpi.radiation',
          'label': kIntakeUnansweredLabel,
          'presence': 'not_assessed',
          'display': 'Not assessed',
          'presenceText': 'Not assessed',
          'value': null,
          'outstanding': true,
        },
      ],
    },
  ],
  'safety': {
    'rulesetVersion': '2026.09.1',
    'highestSeverity': 'urgent',
    // **The engine's key names, not convenient ones.** `TriggeredRule` in
    // `safety-engine.ts` sends `ruleId`, `clinicianSummary` and
    // `recommendedAction`; a fixture that wrote `id`/`rationale`/`action`
    // invented a contract the server does not have, and the app's model was
    // written against the fixture — so both tiers agreed with each other and
    // neither agreed with the API. `patientMessage` is on the wire too and is
    // here to prove the clinician's screen does **not** print it in place of
    // the clinical summary.
    'triggered': [
      {
        'ruleId': kIntakeRedFlagId,
        'ruleVersion': 1,
        'title': kIntakeRedFlagTitle,
        'severity': 'urgent',
        'patientMessage': 'Please tell the desk you are here as soon as you '
            'arrive.',
        'clinicianSummary': kIntakeRedFlagSummary,
        'recommendedAction': kIntakeRedFlagAction,
        'matched': <Map<String, Object?>>[],
      },
      // A second rule, because one flag cannot show that two of them get
      // distinct keys — and an empty `ruleId` on both is a duplicate-key
      // exception rather than a missing sentence.
      {
        'ruleId': 'breathlessness_at_rest',
        'ruleVersion': 1,
        'title': 'Breathlessness at rest',
        'severity': 'advisory',
        'patientMessage': 'Tell the desk if this gets worse while you wait.',
        'clinicianSummary': 'Reported breathless at rest without exertion.',
        'recommendedAction': 'Check oxygen saturation at triage.',
        'matched': <Map<String, Object?>>[],
      },
    ],
  },
  'text': 'Chief Complaint\n  Main concern: Pain in the middle of my chest',
};
