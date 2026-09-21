/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — an interview, in fixtures
///
/// Ifeoma Balogun is `p-1` in this world, and this is her telling somebody what
/// is wrong. The eight questions below are the real registry's, in the real
/// selector's order — chief complaint, then the history of the present illness,
/// then the two sections that are asked of every patient regardless of
/// complaint. A made-up question list would have been easier to write and would
/// have proved nothing about the screen that has to render the real one.
///
/// ## Why this fixture holds state
///
/// An interview is a sequence, and a stateless `POST /turns` that answered with
/// the same question every time would let a screen pass that never advanced.
/// So the fake walks the script: it remembers which question is on the table,
/// answers with the next one, and counts progress the way the server counts it.
///
/// Three server behaviours are reproduced because the screen's design depends
/// on each of them, and a fixture that flattened any of them would let the
/// corresponding defect through:
///
///   * **the next question is in the turn's own response**, with no second
///     request and no wait — which is the whole reason the interview is usable
///     on hardware where the model takes twenty seconds;
///   * **`extraction.queued`** is true for an answer too long to be read by the
///     phrase lists alone, so the "still reading that" mark has something real
///     to appear on;
///   * **presence is derived, not asserted**. A tapped "I don't know" comes
///     back as `unknown`, a tapped "No" on a yes/no question comes back as
///     `none`, and nothing the client sends can produce the other one.
///
/// The safety rule here is deliberately cruder than the real engine's: it fires
/// on one answer rather than on the whole clinical state. What it reproduces is
/// the *response shape* a fired rule has — a flag with a message and no title,
/// no rule id and no clinician summary — because that shape is what the screen
/// is allowed to render, and the rule set itself is the backend's to test.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:medihive/app/core/app_clock.dart';

import '../../fakes/fake_api.dart';

/// The session every flow in this world resumes into.
const String kCaseSessionId = 'cs-1';

/// The consent wording the server says it is asking for. The app must read this
/// off the session rather than shipping its own constant — which wording
/// somebody agreed to is a fact about the session.
const String kCaseConsentVersion = '2026.09.1';

/// One question, as the registry defines it.
class CaseFixtureQuestion {
  const CaseFixtureQuestion({
    required this.fieldPath,
    required this.section,
    required this.label,
    required this.kind,
    required this.prompt,
    this.choices = const <String>[],
  });

  final String fieldPath;
  final String section;
  final String label;
  final String kind;
  final String prompt;
  final List<String> choices;
}

/// The script. Eight questions, in the order the selector would pick them:
/// section order dominates, so nothing from the allergies section can jump
/// ahead of the chief complaint however heavily it is weighted.
const List<CaseFixtureQuestion> kCaseScript = [
  CaseFixtureQuestion(
    fieldPath: 'chief_complaint.symptom',
    section: 'chief_complaint',
    label: 'Main concern',
    kind: 'text',
    prompt: 'What is bothering you the most today?',
  ),
  CaseFixtureQuestion(
    fieldPath: 'hpi.duration',
    section: 'hpi',
    label: 'Duration',
    kind: 'duration',
    prompt: 'How long have you had this problem? For example: three days, or '
        'two weeks.',
  ),
  CaseFixtureQuestion(
    fieldPath: 'hpi.onset',
    section: 'hpi',
    label: 'Onset',
    kind: 'choice',
    prompt: 'Did this start suddenly, all at once, or did it build up slowly '
        'over time?',
    choices: ['sudden', 'gradual', 'woke_up_with_it'],
  ),
  CaseFixtureQuestion(
    fieldPath: 'hpi.severity',
    section: 'hpi',
    label: 'Severity (0-10)',
    kind: 'scale',
    prompt: 'On a scale of nothing at all to the worst you can imagine, where '
        'would you put it right now? Zero to ten.',
    choices: ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10'],
  ),
  CaseFixtureQuestion(
    fieldPath: 'hpi.associated.breathlessness',
    section: 'hpi',
    label: 'Breathlessness',
    kind: 'boolean',
    prompt: 'Have you been short of breath with this? You can answer yes or '
        'no.',
  ),
  CaseFixtureQuestion(
    fieldPath: 'hpi.associated.sweating',
    section: 'hpi',
    label: 'Sweating',
    kind: 'boolean',
    prompt: 'Have you been sweating more than usual with this? You can answer '
        'yes or no.',
  ),
  CaseFixtureQuestion(
    fieldPath: 'allergies.reported',
    section: 'allergies',
    label: 'Allergies',
    kind: 'boolean',
    prompt: 'Do you have any allergies — to a medicine, a food, or anything '
        'else? You can answer yes or no.',
  ),
  CaseFixtureQuestion(
    fieldPath: 'family.any_relevant',
    section: 'family',
    label: 'Family history',
    kind: 'boolean',
    prompt: 'Does anyone in your close family have a long-term illness? You '
        'can answer yes or no.',
  ),
];

/// The one sentence a fired rule is allowed to put in front of a patient.
///
/// A routing instruction, and nothing that names a condition. What the patient
/// described may be a heart attack or may be indigestion; the app is not the
/// thing that decides, and a sentence that guesses is either a diagnosis nobody
/// qualified made or a false alarm that teaches the next patient to ignore the
/// notice.
const String kCaseRedFlagMessage =
    "Some of what you've described needs to be seen quickly. Please tell the "
    'front desk.';

/// Registers the interview.
///
/// State is per install, so one flow's half-finished interview is invisible to
/// the next flow in the same file — and a flow that wants a different one
/// installs its own over the top, because later registrations win.
///
/// [from] starts the interview part-way through [kCaseScript], which is what a
/// patient who answered three questions yesterday comes back to. Walking to the
/// allergies question by answering six others would test the six rather than
/// the one, and would take six round trips to say so.
///
/// [resumed] is what `POST /sessions` reports. Set it with [from] to reproduce
/// the case the resume requirement is actually about: the app was killed, the
/// server still holds the interview, and the phone has to render a position it
/// did not compute.
void installCaseTakingFixtures(
  FakeApi api, {
  int from = 0,
  bool resumed = false,
}) {
  final interview = _Interview(index: from.clamp(0, kCaseScript.length))
    ..started = resumed
    ..consented = resumed;

  // Start or resume. 200 for both; `resumed` says which, and neither is an
  // error — from the patient's side both are "carry on".
  api.on('POST', '/api/case-taking/sessions', (_) {
    final carryingOn = resumed || interview.started;
    return FakeResponse.ok(interview.session(resumed: carryingOn));
  });

  api.on('GET', '/api/case-taking/sessions/current', (_) {
    // A patient who has not started one gets a 200 with nothing in it, not a
    // 404. "You have no interview open" is an answer.
    return FakeResponse.ok(interview.started ? interview.session() : null);
  });

  api.on('GET', '/api/case-taking/sessions/:sessionId', (_) {
    return FakeResponse.ok(interview.session());
  });

  api.on('POST', '/api/case-taking/sessions/:sessionId/consent', (request) {
    final body = request.jsonBody;
    interview.consented = body['accepted'] == true;
    interview.consentVersion = (body['consentVersion'] ?? '').toString();
    return FakeResponse.ok(interview.session());
  });

  api.on('POST', '/api/case-taking/sessions/:sessionId/turns', (request) {
    return FakeResponse.ok(interview.answer(request.jsonBody));
  });

  api.on('PATCH', '/api/case-taking/sessions/:sessionId/facts/:factId',
      (request) {
    return FakeResponse.ok({
      'factId': 'fact-corrected',
      'supersededFactId': request.pathParams['factId'],
      'fieldPath': 'chief_complaint.symptom',
      'presence': 'recorded',
      'value': (request.jsonBody['text'] ?? '').toString(),
      'reason': 'extracted_value',
      'needsPatientConfirmation': false,
    });
  });

  // What this hospital's sidecar can work in.
  //
  // Not the app's catalogue echoed back. The list is deliberately *shorter*
  // than the twelve the app ships, because the property worth reproducing is
  // that the server narrows: a fixture that returned all twelve would pass
  // identically against a screen that ignored the response. Odia is on it with
  // `canSpeak: false`, which is the live sidecar's actual shape — Piper has an
  // Odia voice and `faster-whisper` has no Odia model.
  api.on('GET', '/api/case-taking/languages', (_) {
    return FakeResponse.ok(const [
      {'code': 'en', 'canSpeak': true, 'canHear': true},
      {'code': 'hi', 'canSpeak': true, 'canHear': true},
      {'code': 'ta', 'canSpeak': true, 'canHear': true},
      {'code': 'or', 'canSpeak': false, 'canHear': true},
    ]);
  });

  // Speech in, words out. The confidence is a real measurement on the live
  // path, so it is a plausible one here — 0.84 is what a round trip through
  // Piper and back through Whisper actually returned on this hardware.
  api.on('POST', '/api/case-taking/stt', (_) {
    return FakeResponse.ok({
      'text': kSpokenAnswer,
      'confidence': 0.84,
      'language': 'en',
      'segments': const <Object>[],
      'durationMs': 750,
      'available': true,
    });
  });

  // Words in, speech out - and unlike every other route here, not an envelope.
  //
  // `POST /case-taking/tts` answers `audio/wav` bytes directly
  // (`case-taking.controller.ts` sets the content type and sends the buffer),
  // because the player is handed bytes rather than a URL: the audio sits
  // behind a bearer token and a JSON body, which no bare audio player sends.
  // A fixture returning JSON here would be testing a contract the server does
  // not have.
  //
  // This route is reached without anybody asking for it. Every question is
  // read aloud when the session's output language has a voice, so the
  // interview calls it on its own and a suite with no fixture for it fails
  // whole flows on the unstubbed-endpoint check rather than on anything the
  // flow was written to prove.
  //
  // The bytes are a real, minimal WAV header describing zero samples: enough
  // that a player handed them has something well-formed to reject or ignore,
  // and short enough to read. Nothing plays in a test - `SpeechPlayer` is
  // stubbed at its own seam - so the content beyond the header is not what is
  // under test here.
  api.on('POST', '/api/case-taking/tts', (_) {
    return FakeResponse.binary(kSilentWav, contentType: 'audio/wav');
  });
}

/// A well-formed WAV that is silent, for the read-aloud fixture.
///
/// 44 bytes: the canonical RIFF/WAVE header for 8 kHz mono 16-bit PCM with a
/// zero-length data chunk. Written out rather than base64-decoded so that what
/// it is stays legible at the call site.
const List<int> kSilentWav = <int>[
  0x52, 0x49, 0x46, 0x46, // "RIFF"
  0x24, 0x00, 0x00, 0x00, // chunk size: 36 + 0 bytes of data
  0x57, 0x41, 0x56, 0x45, // "WAVE"
  0x66, 0x6d, 0x74, 0x20, // "fmt "
  0x10, 0x00, 0x00, 0x00, // fmt chunk size: 16
  0x01, 0x00, // PCM
  0x01, 0x00, // mono
  0x40, 0x1f, 0x00, 0x00, // 8000 Hz
  0x80, 0x3e, 0x00, 0x00, // byte rate: 8000 * 1 * 16/8
  0x02, 0x00, // block align
  0x10, 0x00, // 16 bits per sample
  0x64, 0x61, 0x74, 0x61, // "data"
  0x00, 0x00, 0x00, 0x00, // no samples
];

/// What the transcriber hears in this world.
///
/// Two sentences, deliberately: the server treats an answer with a sentence
/// boundary in it as a narrative rather than a reply, so this is the answer
/// that makes the engine harvest a second field out of one utterance. It used
/// to be described as the answer that makes `extraction.queued` true; nothing
/// is queued any more, because the harvest finishes before the response is
/// built.
const String kSpokenAnswer =
    'I have had a pain in the middle of my chest since Tuesday. It is worse '
    'when I walk up the stairs.';

/// The scripted interview.
class _Interview {
  _Interview({this.index = 0});

  bool started = false;
  bool consented = false;
  String consentVersion = kCaseConsentVersion;

  /// Which question is on the table. Equal to [kCaseScript.length] once there
  /// is nothing left to ask.
  int index;

  int turns = 0;
  bool redFlagRaised = false;
  bool breathless = false;

  bool get isFinished => index >= kCaseScript.length;

  Map<String, Object?> session({bool resumed = false}) {
    started = true;
    return {
      'id': kCaseSessionId,
      'patientId': 'p-1',
      'kind': 'new_consultation',
      'language': 'en',
      'status': isFinished ? 'review' : 'in_progress',
      'consent': {
        'given': consented,
        'givenAt': consented ? AppClock.now().toIso8601String() : null,
        'version': consented ? consentVersion : null,
        'requiredVersion': kCaseConsentVersion,
      },
      'startedAt': AppClock.now().toIso8601String(),
      'lastActiveAt': AppClock.now().toIso8601String(),
      'submittedAt': null,
      'progress': _progress(),
      'interviewStatus': isFinished ? 'complete' : 'ready',
      'currentQuestion': _question(),
      'answeredCount': index,
      'outstanding': [
        for (final question in kCaseScript.skip(index).take(5))
          question.fieldPath,
      ],
      'redFlags': redFlagRaised ? [_flag()] : const <Object>[],
      'patientMessage': redFlagRaised ? kCaseRedFlagMessage : null,
      'resumed': resumed,
    };
  }

  /// One answer in, the next question out — in this response and no other.
  Map<String, Object?> answer(Map<String, dynamic> body) {
    final fieldPath = (body['fieldPath'] ?? '').toString();
    final modality = (body['modality'] ?? '').toString();
    final value = body['value']?.toString();
    final text = (body['text'] ?? '').toString();

    final answered = index < kCaseScript.length ? kCaseScript[index] : null;
    final presence = _presenceOf(
      modality: modality,
      value: value,
      text: text,
      kind: answered?.kind ?? 'text',
    );

    if (fieldPath == 'hpi.associated.breathlessness' && value == 'yes') {
      breathless = true;
    }
    // Crude next to the real safety engine, which evaluates the whole clinical
    // state after every answer. What it reproduces is the shape of a fired
    // rule, which is all the screen is allowed to see.
    final firedNow = !redFlagRaised &&
        breathless &&
        fieldPath == 'hpi.associated.sweating' &&
        value == 'yes';
    if (firedNow) redFlagRaised = true;

    index++;
    turns++;

    return {
      'turnId': 'turn-$turns',
      'sessionId': kCaseSessionId,
      'accepted': {
        'fieldPath': fieldPath.isEmpty ? null : fieldPath,
        'presence': presence,
        'value': presence == 'recorded' ? (value ?? text) : null,
        'reason': _reasonOf(presence),
        'needsPatientConfirmation': false,
        'factId': presence == 'not_assessed' ? null : 'fact-$turns',
      },
      'extraction': {
        'queued': _queues(text),
        'reason': _queues(text)
            ? 'answer is longer than the question'
            : 'engine read the answer without a model',
      },
      'nextQuestion': _question(),
      'interviewStatus': isFinished ? 'complete' : 'ready',
      'progress': _progress(),
      'redFlags': firedNow ? [_flag()] : const <Object>[],
      'patientMessage': redFlagRaised ? kCaseRedFlagMessage : null,
      // The number the whole design is built around. Milliseconds, because
      // nothing on this path talks to a model.
      'serverTimeMs': 7,
    };
  }

  Map<String, Object?>? _question() {
    if (isFinished) return null;
    final question = kCaseScript[index];
    return {
      'fieldPath': question.fieldPath,
      'section': question.section,
      'label': question.label,
      'kind': question.kind,
      'choices': question.choices,
      'prompt': question.prompt,
      'remaining': kCaseScript.length - index,
    };
  }

  Map<String, Object?> _progress() {
    final expected = kCaseScript.length;
    final addressed = index.clamp(0, expected);
    return {
      'expected': expected,
      'addressed': addressed,
      'percent': (addressed * 100 / expected).round(),
      'complete': addressed >= expected,
      'sections': [
        {
          'section': 'chief_complaint',
          'title': 'Chief Complaint',
          'expected': 1,
          'addressed': addressed >= 1 ? 1 : 0,
          'percent': addressed >= 1 ? 100 : 0,
          'complete': addressed >= 1,
          'outstanding': const <String>[],
        },
      ],
    };
  }

  Map<String, Object?> _flag() => {
        'id': 'flag-1',
        'severity': 'critical',
        // `message` only. No title, no rule id, no clinician summary — the
        // server's patient view sends none of those, and the rule set's own
        // title for this screen names the syndrome.
        'message': kCaseRedFlagMessage,
        'triggeredAt': AppClock.now().toIso8601String(),
      };

  /// The engine's own rule order, in miniature: refusal, then uncertainty, then
  /// negation, then affirmation, then value. Any other order collapses one
  /// state into a more confident one — which for the second and third is
  /// exactly the "I don't know" that becomes a "no".
  String _presenceOf({
    required String modality,
    required String? value,
    required String text,
    required String kind,
  }) {
    if (modality == 'skip') return 'declined';
    if (modality == 'choice') {
      if (value == 'not_sure') return 'unknown';
      if (value == 'prefer_not_to_say') return 'declined';
      if (value == 'no' && kind == 'boolean') return 'none';
      return 'recorded';
    }
    final said = text.toLowerCase();
    if (said.contains("don't know") || said.contains('not sure')) {
      return 'unknown';
    }
    if (said.trim() == 'no' || said.startsWith('no ')) return 'none';
    return text.trim().isEmpty ? 'not_assessed' : 'recorded';
  }

  String _reasonOf(String presence) => switch (presence) {
        'unknown' => 'uncertainty_choice',
        'none' => 'negation_choice',
        'declined' => 'explicit_skip',
        'recorded' => 'extracted_value',
        _ => 'no_value_extracted',
      };

  /// Short enough that the phrase lists can read it on their own, or long
  /// enough that it goes to the model. A sentence boundary is disqualifying by
  /// itself: two sentences are two things said, and the second is rarely about
  /// the question.
  bool _queues(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.length > 120) return true;
    return RegExp(r'[.!?]\s+\S').hasMatch(trimmed);
  }
}
