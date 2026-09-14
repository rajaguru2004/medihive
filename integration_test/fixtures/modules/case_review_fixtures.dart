/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — "here is what we understood about you", in fixtures
///
/// The review document the engine renders, the corrections a patient makes to
/// it, and the submission it becomes.
///
/// Installed by `World.install` for every flow rather than only this module's:
/// the review route is reachable from the patient's own dashboard, and
/// `AppHarness.dispose` fails any test that touches an endpoint nothing
/// answered. A module that registers its routes only in its own flow leaves
/// that landmine for every flow that renders the same path.
///
/// ## Why this fixture holds state
///
/// Because a correction is not a read. The behaviour the screen has to get
/// right is that changing a line **re-labels** it — it stops being attributed
/// to the recogniser that first heard it and starts being attributed to the
/// patient — and a stateless fixture that answered the same review document
/// every time would let a screen pass that showed the correction and lost it.
///
/// Four server behaviours are reproduced, and flattening any one would let the
/// corresponding defect through:
///
///   * **Six presences, not two.** One line is a recorded value, one is the
///     patient denying something, one is them not knowing, and one is a
///     question nobody has asked. A fixture carrying only values and blanks
///     would let a screen pass that collapsed "I don't know" into "no".
///
///   * **`display` is always printable, and `presenceText` always says which.**
///     The engine never emits a value for a fact that has none.
///
///   * **A correction supersedes rather than updates**, and it reaches the
///     server through either door. `recordFact` retires the standing fact for
///     that field inside one transaction whether the change arrived as
///     `PATCH .../facts/:factId` or as a turn with `modality: correction`, so
///     both handlers here change the same line and both hand back a fact id.
///
///   * **Submitting is once.** A second `POST /submit` is a 409 with a sentence
///     already written for a patient, not a second submission.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:medihive/app/core/app_clock.dart';

import '../../fakes/fake_api.dart';

/// The interview the review flows read back. The same session id the interview
/// fixtures use, because it is the same interview.
const String kReviewSessionId = 'cs-1';

/// The line a correction is made to, and what it says before and after.
const String kDurationField = 'hpi.duration';
const String kDurationBefore = 'Three days';
const String kDurationAfter = 'Six days';

/// The line nobody has answered. §36 prints it rather than omitting it — an
/// omitted line reads as nothing to report.
const String kUnansweredField = 'hpi.radiation';
const String kUnansweredLabel = 'Does the pain spread anywhere?';

/// The line the patient said they did not know. Never folded into a denial.
const String kUnsureField = 'family.any_relevant';

/// The line the patient denied. A *finding* — "denies fever" is something a
/// clinician writes down — and a different fact from silence.
const String kDeniedField = 'hpi.associated.fever';

/// The opening line, and the one a red-flag rule would be about.
const String kComplaintField = 'chief_complaint.symptom';
const String kComplaintValue = 'Pain in the middle of my chest';

/// Registers the review, the two doors a correction can arrive through, and the
/// submission.
///
/// State is per install, so one flow's corrections are invisible to the next in
/// the same file — and later registrations win, so a flow installing this again
/// starts from a clean case.
void installCaseReviewFixtures(FakeApi api) {
  final lines = _initialLines();
  String? submittedAt;
  var facts = 0;

  /// Applies a change to one line and hands back the fact it created.
  ///
  /// One function for both doors, because on the server it is one path: a
  /// correction and a tapped answer both go through `recordFact`, which
  /// supersedes the standing fact for that field inside a transaction.
  Map<String, Object?> apply(
    String fieldPath, {
    required String modality,
    String? value,
    String? text,
  }) {
    final line = lines[fieldPath];
    if (line == null) {
      return {'presence': 'not_assessed', 'value': null, 'factId': null};
    }

    facts++;
    final factId = 'fact-$facts';

    // The engine's own rule order, in miniature: uncertainty before negation,
    // because nearly every English way of saying "I don't know" contains a
    // negation and the obvious order silently turns every "I'm not sure" into
    // an asserted "no".
    switch (value) {
      case 'not_sure':
        line
          ..presence = 'unknown'
          ..display = 'Patient unsure'
          ..value = null
          ..source = 'patient_choice'
          ..verification = 'unverified'
          ..outstanding = false;
      case 'prefer_not_to_say':
        line
          ..presence = 'declined'
          ..display = 'Prefer not to answer'
          ..value = null
          ..source = 'patient_choice'
          ..verification = 'unverified'
          ..outstanding = false;
      case 'no':
        line
          ..presence = 'none'
          ..display = 'None reported'
          ..value = null
          ..source = 'patient_choice'
          ..verification = 'unverified'
          ..outstanding = false;
      case 'yes':
        line
          ..presence = 'recorded'
          ..display = 'Yes'
          ..value = 'yes'
          ..source = 'patient_choice'
          ..verification = 'unverified'
          ..outstanding = false;
      default:
        if (modality == 'skip') {
          // A skip carries its meaning in the modality rather than in a value,
          // and it is recorded as a refusal — never as a blank, so a clinician
          // can see the question was put and not answered.
          line
            ..presence = 'declined'
            ..display = 'Prefer not to answer'
            ..value = null
            ..source = 'patient_choice'
            ..verification = 'unverified'
            ..outstanding = false;
        } else if ((text ?? '').trim().isNotEmpty) {
          line
            ..presence = 'recorded'
            ..display = text!.trim()
            ..value = text.trim()
            // A correction the patient made themselves is theirs, and is
            // confirmed by them by definition.
            ..source = 'patient_correction'
            ..verification = 'patient_confirmed'
            ..outstanding = false;
        }
    }

    return {
      'fieldPath': fieldPath,
      'presence': line.presence,
      'value': line.value,
      'reason': 'extracted_value',
      'needsPatientConfirmation': false,
      'factId': factId,
    };
  }

  api.on('GET', '/api/case-taking/sessions/:sessionId/review', (request) {
    return FakeResponse.ok(
      _review(
        sessionId: request.pathParams['sessionId'] ?? kReviewSessionId,
        lines: lines,
        submitted: submittedAt != null,
      ),
    );
  });

  // The route written for a correction. Reachable once this device knows which
  // fact a line stands for — which it learns from the response to any turn.
  api.on('PATCH', '/api/case-taking/sessions/:sessionId/facts/:factId',
      (request) {
    final accepted = apply(
      // The review document carries no fact ids, so the app addresses this
      // route only for a line it has already changed once. `kDurationField` is
      // that line in these flows.
      kDurationField,
      modality: 'correction',
      text: (request.jsonBody['text'] ?? '').toString(),
      value: (request.jsonBody['value'] ?? '').toString().isEmpty
          ? null
          : request.jsonBody['value'].toString(),
    );
    return FakeResponse.ok({
      ...accepted,
      'supersededFactId': request.pathParams['factId'],
    });
  });

  // The other door: a turn against a named field. Same write on the server,
  // which is why the same `apply` runs behind it.
  api.on('POST', '/api/case-taking/sessions/:sessionId/turns', (request) {
    final body = request.jsonBody;
    final fieldPath = (body['fieldPath'] ?? '').toString();
    final accepted = apply(
      fieldPath,
      modality: (body['modality'] ?? 'text').toString(),
      value: body['value']?.toString(),
      text: body['text']?.toString(),
    );

    return FakeResponse.ok({
      'turnId': 'turn-review-${accepted['factId']}',
      'sessionId': request.pathParams['sessionId'] ?? kReviewSessionId,
      'accepted': accepted,
      'extraction': {
        'queued': false,
        'reason': 'engine read the answer without a model',
      },
      // The review screen is past the questions, so there is no next one. Not
      // an error: `interviewStatus` is what tells the two apart.
      'nextQuestion': null,
      'interviewStatus': 'complete',
      'progress': {
        'expected': lines.length,
        'addressed': lines.values.where((l) => !l.outstanding).length,
        'percent': 80,
        'complete': false,
        'sections': const <Object>[],
      },
      'redFlags': const <Object>[],
      'patientMessage': null,
      'serverTimeMs': 6,
    });
  });

  api.on('POST', '/api/case-taking/sessions/:sessionId/submit', (request) {
    if (submittedAt != null) {
      // Once. The sentence is the server's own and is already written for a
      // patient — the app shows it rather than inventing a second wording.
      return FakeResponse.fail(
        409,
        'This case has already been sent to the hospital.',
        errorCode: 'CASE_SESSION_ALREADY_SUBMITTED',
      );
    }
    submittedAt = AppClock.now().toIso8601String();

    return FakeResponse.ok({
      'submissionId': 'sub-1',
      'sessionId': request.pathParams['sessionId'] ?? kReviewSessionId,
      'patientId': 'p-1',
      'submittedAt': submittedAt,
      'percentComplete': 80,
      'sectionCount': 3,
      'missingInformation': [kUnansweredField],
      'safety': {
        'rulesetVersion': '2026.09.1',
        'highestSeverity': 'none',
        'patientMessage': null,
        'triggeredCount': 0,
      },
      'structuredCase': const <String, Object?>{},
    });
  });
}

/// One line of the case, mutable so a correction can be seen to land.
class _Line {
  _Line({
    required this.section,
    required this.sectionTitle,
    required this.label,
    required this.presence,
    required this.display,
    this.value,
    this.source,
    this.confidence,
    this.outstanding = false,
  });

  final String section;
  final String sectionTitle;
  final String label;

  String presence;
  String display;
  String? value;
  String? source;
  double? confidence;

  /// Never set at construction. Only a write moves it, which is the point:
  /// a line is unverified until somebody says otherwise.
  String verification = 'unverified';
  bool outstanding;

  Map<String, Object?> toJson(String fieldPath) => {
        'fieldPath': fieldPath,
        'label': label,
        'presence': presence,
        // Always printable: the value when there is one, the presence's own
        // wording otherwise. The renderer throws rather than print a blank.
        'display': display,
        'presenceText': _presenceLabel(presence),
        'value': value,
        'source': source,
        'confidence': confidence,
        'verification': verification,
        'outstanding': outstanding,
      };
}

/// The engine's own wording, per presence. Keyed by presence so that two states
/// cannot end up sharing a sentence.
String _presenceLabel(String presence) => switch (presence) {
      'recorded' => 'Recorded',
      'none' => 'None reported',
      'unknown' => 'Patient unsure',
      'not_applicable' => 'Not applicable',
      'declined' => 'Prefer not to answer',
      _ => 'Not assessed',
    };

/// Five lines across three sections, chosen so that four of the six presences
/// are on screen at once.
Map<String, _Line> _initialLines() => {
      kComplaintField: _Line(
        section: 'chief_complaint',
        sectionTitle: 'What brought you in',
        label: 'Main concern',
        presence: 'recorded',
        display: kComplaintValue,
        value: kComplaintValue,
        source: 'patient_voice',
        // A real measurement from the speech recogniser — 0.84 is what a round
        // trip through Piper and back through Whisper actually returned on the
        // hardware this was built against.
        confidence: 0.84,
      ),
      kDurationField: _Line(
        section: 'hpi',
        sectionTitle: 'How it has been',
        label: 'How long',
        presence: 'recorded',
        display: kDurationBefore,
        value: kDurationBefore,
        source: 'patient_voice',
        confidence: 0.84,
      ),
      kDeniedField: _Line(
        section: 'hpi',
        sectionTitle: 'How it has been',
        label: 'Fever',
        presence: 'none',
        display: 'None reported',
        source: 'patient_choice',
      ),
      kUnansweredField: _Line(
        section: 'hpi',
        sectionTitle: 'How it has been',
        label: kUnansweredLabel,
        presence: 'not_assessed',
        display: 'Not assessed',
        outstanding: true,
      ),
      kUnsureField: _Line(
        section: 'family',
        sectionTitle: 'Your family',
        label: 'Family history',
        presence: 'unknown',
        display: 'Patient unsure',
        source: 'patient_choice',
      ),
    };

Map<String, Object?> _review({
  required String sessionId,
  required Map<String, _Line> lines,
  required bool submitted,
}) {
  final order = ['chief_complaint', 'hpi', 'family'];
  final sections = [
    for (final key in order)
      if (lines.values.any((line) => line.section == key))
        {
          'section': key,
          'title':
              lines.values.firstWhere((l) => l.section == key).sectionTitle,
          'percentComplete': 80,
          'outstanding': [
            for (final entry in lines.entries)
              if (entry.value.section == key && entry.value.outstanding)
                entry.key,
          ],
          'items': [
            for (final entry in lines.entries)
              if (entry.value.section == key) entry.value.toJson(entry.key),
          ],
        },
  ];

  return {
    'sessionId': sessionId,
    'status': submitted ? 'submitted' : 'review',
    'revision': 7,
    'percentComplete': 80,
    // Field keys, which is what the engine flattens. The screen renders the
    // items' own labels instead, because `hpi.radiation` is the right shape for
    // a machine and the wrong one for a patient.
    'missingInformation': [
      for (final entry in lines.entries)
        if (entry.value.outstanding) entry.key,
    ],
    'sections': sections,
    'text': 'Chief Complaint\n  Main concern: $kComplaintValue',
    // Null unless somebody asked to be read to: drafting it costs a model call,
    // and the structured document is what §34 actually requires.
    'narrative': null,
    'safety': {
      'rulesetVersion': '2026.09.1',
      'highestSeverity': 'none',
      'patientMessage': null,
      'triggeredCount': 0,
    },
  };
}
